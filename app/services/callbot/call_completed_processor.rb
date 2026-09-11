class Callbot::CallCompletedProcessor
  class InvalidPayload < StandardError; end

  attr_reader :payload, :webhook

  def initialize(payload:, webhook:)
    @payload = payload.to_h.stringify_keys
    @webhook = webhook
  end

  def perform
    validate_payload!
    Phone::PbxCallEventProcessor.new(payload: phone_event).perform
  end

  private

  def validate_payload!
    raise InvalidPayload, 'eventType must be call.completed' unless payload['eventType'] == 'call.completed'
    raise InvalidPayload, 'eventVersion must be 2.0' unless payload['eventVersion'] == '2.0'
    raise InvalidPayload, 'eventId is required' if payload['eventId'].blank?
    raise InvalidPayload, 'call.id is required' if call['id'].blank?
    raise InvalidPayload, 'call.direction must be inbound or outbound' unless PhoneCall::DIRECTIONS.include?(call['direction'])
    raise InvalidPayload, 'customer phone number is required' if customer_number.blank?
  end

  def phone_event
    {
      event_id: payload['eventId'],
      event: 'call.completed',
      pbx_id: "callytics:#{webhook.id}",
      linked_id: call['id'],
      pbx_call_id: call['id'],
      inbox_id: webhook.inbox_id,
      business_direction: call['direction'],
      customer_number: customer_number,
      from_number: call['from'],
      to_number: call['to'],
      status: call['contactStatus'],
      started_at: call['startedAt'],
      answered_at: call['answeredAt'],
      ended_at: call['endedAt'],
      duration: call['durationSeconds'],
      hangup_cause: call['endReason'],
      callbot_report: report
    }
  end

  def call
    @call ||= payload['call'].is_a?(Hash) ? payload['call'].stringify_keys : {}
  end

  def customer_number
    @customer_number ||= normalize_phone(call['direction'] == 'outbound' ? call['to'] : call['from'])
  end

  # Store a canonical E.164-looking number while Contacts::InboundPhoneResolver
  # compares a VN-centric key. Thus 0342..., +84342... and 84 342... map to one contact.
  def normalize_phone(number)
    digits = number.to_s.gsub(/\D/, '').delete_prefix('00')
    return if digits.length < 8
    return "+#{digits}" if digits.start_with?('84')
    return "+84#{digits.delete_prefix('0')}" if digits.start_with?('0')

    "+#{digits}"
  end

  def report
    {
      'event_id' => payload['eventId'],
      'event_version' => payload['eventVersion'],
      'idempotency_key' => payload['idempotencyKey'],
      'campaign_id' => payload['campaignId'],
      'metadata' => payload['metadata'].is_a?(Hash) ? payload['metadata'] : {},
      'result' => payload['result'].is_a?(Hash) ? payload['result'] : {},
      'conversation' => payload['conversation'].is_a?(Hash) ? payload['conversation'] : {},
      'recording' => payload['recording'].is_a?(Hash) ? payload['recording'] : {}
    }
  end
end
