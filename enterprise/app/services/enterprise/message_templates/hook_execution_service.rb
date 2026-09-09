module Enterprise::MessageTemplates::HookExecutionService
  def trigger_templates
    super
    return unless tekomi_conversation_message?

    # Eligibility is demand-level: every inbound customer message in a
    # Tekomi-connected inbox counts, including conversations a human grabbed
    # first or that arrive while the account is over its usage limit —
    # otherwise the coverage denominator only ever contains conversations
    # Tekomi was already about to answer.
    track_tekomi_eligibility
    return unless conversation.pending?
    return perform_handoff unless inbox.tekomi_active?

    Tekomi::Conversation::ResponseSchedulerService.new(message: message).perform
  end

  def should_send_greeting?
    return false if tekomi_handling_conversation?

    super
  end

  def should_send_out_of_office_message?
    return false if tekomi_handling_conversation?

    super
  end

  def should_send_email_collect?
    return false if tekomi_handling_conversation?

    super
  end

  private

  def track_tekomi_eligibility
    return unless conversation.account.feature_enabled?('tekomi_integration_v2')

    Tekomi::ConversationOutcomeTracker.new(
      conversation: conversation,
      assistant: inbox.tekomi_assistant
    ).record_eligibility(at: message.created_at)
  end

  def tekomi_conversation_message?
    message.tekomi_response_triggering? && tekomi_assistant_configured? && !inbox.external_bot_active?
  end

  def perform_handoff
    Rails.logger.info("Tekomi limit exceeded, performing handoff mid-conversation for conversation: #{conversation.id}")
    conversation.messages.create!(
      message_type: :outgoing,
      account_id: conversation.account.id,
      inbox_id: conversation.inbox.id,
      content: 'Transferring to another agent for further assistance.'
    )
    conversation.bot_handoff!
    Tekomi::ConversationEvents.handed_off(
      conversation: conversation,
      assistant: inbox.tekomi_assistant,
      source: Tekomi::ConversationEvents::Sources::USAGE_LIMIT,
      reason_category: :usage_limit,
      at: Time.current
    )
    send_out_of_office_message_after_handoff
  end

  def send_out_of_office_message_after_handoff
    # Campaign conversations should never receive OOO templates — the campaign itself
    # serves as the initial outreach, and OOO would be confusing in that context.
    return if conversation.campaign.present?

    ::MessageTemplates::Template::OutOfOffice.perform_if_applicable(conversation)
  end

  def tekomi_handling_conversation?
    conversation.pending? && tekomi_assistant_configured?
  end

  def tekomi_assistant_configured?
    inbox.tekomi_assistant.present?
  end
end
