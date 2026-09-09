module Enterprise::Concerns::Inbox
  extend ActiveSupport::Concern

  included do
    has_one :tekomi_inbox, dependent: :destroy, class_name: 'TekomiInbox'
    has_one :tekomi_assistant,
            through: :tekomi_inbox,
            class_name: 'Tekomi::Assistant'
    has_many :inbox_capacity_limits, dependent: :destroy
    has_many :calls, dependent: :destroy_async
    has_many :conversation_outcomes, dependent: :destroy_async

    before_create :ensure_create_permitted
  end

  def ensure_create_permitted
    raise CustomExceptions::Inbox::LimitExceeded.new({}) if account.inboxes.count >= account.usage_limits[:inboxes]
  end
end
