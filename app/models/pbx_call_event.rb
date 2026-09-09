# == Schema Information
#
# Table name: pbx_call_events
#
#  id            :bigint           not null, primary key
#  event_type    :string           not null
#  payload       :jsonb            not null
#  processed_at  :datetime
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  event_id      :string           not null
#  linked_id     :string           not null
#  pbx_id        :string           not null
#  phone_call_id :bigint
#
# Indexes
#
#  index_pbx_call_events_on_pbx_id_and_event_id   (pbx_id,event_id) UNIQUE
#  index_pbx_call_events_on_pbx_id_and_linked_id  (pbx_id,linked_id)
#  index_pbx_call_events_on_phone_call_id         (phone_call_id)
#
# Foreign Keys
#
#  fk_rails_...  (phone_call_id => phone_calls.id) ON DELETE => cascade
#
class PbxCallEvent < ApplicationRecord
  belongs_to :phone_call, optional: true

  validates :pbx_id, :event_id, :linked_id, :event_type, presence: true
  validates :event_id, uniqueness: { scope: :pbx_id }
end
