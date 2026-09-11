class CallbotWebhook < ApplicationRecord
  belongs_to :account
  belongs_to :inbox

  before_validation :assign_token, on: :create

  validates :name, :token, presence: true
  validates :token, uniqueness: true
  validates :name, uniqueness: { scope: :inbox_id }
  validate :phone_inbox
  validate :account_matches_inbox

  scope :enabled, -> { where(enabled: true) }

  def endpoint_path
    "/webhooks/callytics/#{token}"
  end

  private

  def assign_token
    self.token ||= SecureRandom.urlsafe_base64(32)
  end

  def phone_inbox
    errors.add(:inbox, 'must be a Phone inbox') if inbox && !inbox.phone?
  end

  def account_matches_inbox
    return unless account && inbox && account_id != inbox.account_id

    errors.add(:account, 'must match the inbox account')
  end
end
