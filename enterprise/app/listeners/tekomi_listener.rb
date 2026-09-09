class TekomiListener < BaseListener
  include ::Events::Types

  def message_updated(event)
    message = event.data[:message]
    return unless message.input_csat?

    response = CsatSurveyResponse.find_by(message: message)
    return unless response

    tracker(message.conversation).record_csat(response: response)
  end

  def conversation_resolved(event)
    conversation = extract_conversation_and_account(event)[0]
    tracker(conversation).record_resolution(at: event.timestamp)

    assistant = conversation.inbox.tekomi_assistant

    return unless conversation.inbox.tekomi_active?

    Tekomi::Llm::ContactNotesService.new(assistant, conversation).generate_and_update_notes if assistant.config['feature_memory'].present?
    Tekomi::Llm::ConversationFaqJob.perform_later(conversation, assistant) if assistant.config['feature_faq'].present?
  end

  private

  def tracker(conversation)
    Tekomi::ConversationOutcomeTracker.new(conversation: conversation)
  end
end
