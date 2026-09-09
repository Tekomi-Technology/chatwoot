module Tekomi::Conversation::V1ActionClassifier
  private

  def v1_action_classifier_enabled?
    account.feature_enabled?('tekomi_v1_action_classifier')
  end

  def classify_v1_response_action(message_history)
    return unless v1_action_classifier_enabled?
    return if legacy_v1_handoff_token?

    classification = Tekomi::Llm::AssistantActionClassifierService.new(
      assistant: @assistant,
      conversation: @conversation
    ).classify(message_history: message_history, assistant_response: @response['response'])

    apply_v1_action_classification(classification)
  rescue StandardError => e
    ChatwootExceptionTracker.new(e, account: account).capture_exception
    Rails.logger.warn(
      "[TEKOMI][ResponseBuilderJob] V1 action classifier failed for account=#{account.id} " \
      "conversation=#{@conversation.display_id}: #{e.class.name}: #{e.message}"
    )
  end

  def apply_v1_action_classification(classification)
    action = classification['action']
    return log_invalid_v1_action_classification(classification) unless valid_v1_action_classification?(action)

    @response.merge!(
      'action' => action,
      'action_reason' => classification['action_reason'],
      'action_source' => 'classifier',
      'action_classifier_model' => classification['model']
    )

    log_v1_action_classification(action, classification)
  end

  def log_v1_action_classification(action, classification)
    Rails.logger.info(
      "[TEKOMI][ResponseBuilderJob] V1 action classifier account=#{account.id} conversation=#{@conversation.display_id} " \
      "action=#{action} reason=#{classification['action_reason']} model=#{classification['model']}"
    )
  end

  def valid_v1_action_classification?(action)
    Tekomi::AssistantActionSchema::ACTIONS.include?(action)
  end

  def log_invalid_v1_action_classification(classification)
    Rails.logger.warn(
      '[TEKOMI][ResponseBuilderJob] V1 action classifier returned invalid action; falling back to assistant response ' \
      "for account=#{account.id} conversation=#{@conversation.display_id}: #{classification['error'] || classification['raw_response']}"
    )
  end
end
