module Enterprise::Account::ConversationsResolutionSchedulerJob
  def perform
    super

    resolve_tekomi_conversations
  end

  private

  def resolve_tekomi_conversations
    TekomiInbox.all.find_each(batch_size: 100) do |tekomi_inbox|
      inbox = tekomi_inbox.inbox
      assistant = tekomi_inbox.tekomi_assistant

      next if inbox.email? || inbox.external_bot_active?
      next if assistant.blank? || assistant.inactive_conversation_resolution_disabled?

      Tekomi::InboxPendingConversationsResolutionJob.perform_later(
        inbox
      )
    end
  end
end
