class Tekomi::ReportingEventListener < BaseListener
  def tekomi_conversation_handed_off(event)
    create_tekomi_inference_event(event, 'conversation_tekomi_inference_handoff') if event.data[:source] == 'inference'
  end

  def tekomi_conversation_resolved(event)
    create_tekomi_inference_event(event, 'conversation_tekomi_inference_resolved') if event.data[:source] == 'inference'
  end

  private

  def create_tekomi_inference_event(event, event_name)
    conversation = extract_conversation_and_account(event)[0]
    time_to_event = event.timestamp.to_i - conversation.created_at.to_i

    ReportingEvent.create!(
      name: event_name,
      value: time_to_event,
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id,
      user_id: conversation.assignee_id,
      conversation_id: conversation.id,
      event_start_time: conversation.created_at,
      event_end_time: event.timestamp
    )
  end
end
