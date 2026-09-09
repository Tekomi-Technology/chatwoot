module Tekomi::Conversation::V2LifecycleEvents
  private

  def v2_generation_errored?
    tekomi_v2_enabled? && @response['error'].present?
  end

  def record_v2_response_completed(message)
    Tekomi::ConversationEvents.response_completed(
      conversation: @conversation,
      assistant: @assistant,
      message: message,
      at: Time.current
    )
  end

  def record_v2_response_failure(reason)
    Tekomi::ConversationEvents.response_failed(conversation: @conversation, assistant: @assistant, reason: reason, at: Time.current)
  end

  def record_v2_failure_handoff(source:)
    Tekomi::ConversationEvents.handed_off(
      conversation: @conversation,
      assistant: @assistant,
      source: source,
      reason_category: :tool_failure,
      at: Time.current
    )
  end
end
