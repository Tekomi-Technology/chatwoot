# == Schema Information
#
# Table name: phone_calls
#
#  id                 :bigint           not null, primary key
#  answered_at        :datetime
#  customer_number    :string           not null
#  direction          :string           not null
#  duration_seconds   :integer
#  ended_at           :datetime
#  extension          :string
#  from_number        :string
#  hangup_cause       :string
#  metadata           :jsonb            not null
#  recording_url      :text
#  started_at         :datetime
#  status             :string           default("ringing"), not null
#  to_number          :string
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  account_id         :integer          not null
#  contact_id         :integer          not null
#  conversation_id    :integer          not null
#  inbox_id           :integer          not null
#  last_event_id      :string
#  linked_id          :string           not null
#  message_id         :integer
#  pbx_id             :string           not null
#  phone_extension_id :bigint
#  user_id            :integer
#
# Indexes
#
#  index_phone_calls_on_account_id_and_contact_id       (account_id,contact_id)
#  index_phone_calls_on_account_id_and_conversation_id  (account_id,conversation_id)
#  index_phone_calls_on_message_id                      (message_id) UNIQUE WHERE (message_id IS NOT NULL)
#  index_phone_calls_on_pbx_id_and_linked_id            (pbx_id,linked_id) UNIQUE
#
class PhoneCall < ApplicationRecord
  DIRECTIONS = %w[inbound outbound].freeze
  TERMINAL_STATUSES = %w[completed missed busy no_answer rejected cancelled failed].freeze

  belongs_to :account
  belongs_to :inbox
  belongs_to :contact
  belongs_to :conversation
  belongs_to :message, optional: true
  belongs_to :user, optional: true
  belongs_to :phone_extension, optional: true
  has_many :pbx_call_events, dependent: :destroy
  has_one_attached :cached_recording

  validates :pbx_id, :linked_id, :customer_number, :status, presence: true
  validates :direction, inclusion: { in: DIRECTIONS }
  validates :linked_id, uniqueness: { scope: :pbx_id }

  def terminal?
    TERMINAL_STATUSES.include?(status)
  end

  def message_data
    {
      phone_call_id: id,
      pbx_call_id: linked_id,
      direction: direction,
      status: status,
      customer_number: customer_number,
      extension: extension,
      from_number: from_number,
      to_number: to_number,
      duration_seconds: duration_seconds,
      hangup_cause: hangup_cause,
      recording_url: recording_url,
      agent_id: user_id,
      agent_name: user&.available_name,
      started_at: started_at&.iso8601,
      answered_at: answered_at&.iso8601,
      ended_at: ended_at&.iso8601
    }.merge(callbot_message_data).compact
  end

  private

  def callbot_message_data
    report = metadata['callbot_report']
    return {} unless report.is_a?(Hash)

    result = report['result'].is_a?(Hash) ? report['result'] : {}
    {
      callbot_summary: result['summary'],
      callbot_outcome: result['outcome'],
      callbot_analysis_status: result['analysisStatus']
    }
  end
end
