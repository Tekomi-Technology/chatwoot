class Phone::PbxCallEventProcessor
  class InvalidPayload < StandardError; end

  STATUS_RANK = {
    'ringing' => 0,
    'in_progress' => 1,
    'completed' => 2,
    'missed' => 2,
    'busy' => 2,
    'no_answer' => 2,
    'rejected' => 2,
    'cancelled' => 2,
    'failed' => 2
  }.freeze

  attr_reader :payload

  def initialize(payload:)
    @payload = payload.to_h.stringify_keys
  end

  def perform
    validate_payload!
    event_record = insert_event

    event_record.with_lock do
      return if event_record.processed_at?

      phone_call = find_phone_call || create_phone_call
      unless phone_call
        event_record.update!(processed_at: Time.current)
        return
      end

      apply_event(phone_call)
      phone_call.save!
      ensure_message(phone_call)
      event_record.update!(phone_call: phone_call, processed_at: Time.current)
    end
  end

  private

  def validate_payload!
    raise InvalidPayload, 'event_id is required' if payload['event_id'].blank?
    raise InvalidPayload, 'event is required' if payload['event'].blank?
    raise InvalidPayload, 'linked_id or pbx_call_id is required' if linked_id.blank?
  end

  def insert_event
    result = PbxCallEvent.insert_all(
      [{
        pbx_id: pbx_id,
        event_id: payload['event_id'],
        linked_id: linked_id,
        event_type: payload['event'],
        payload: payload,
        created_at: Time.current,
        updated_at: Time.current
      }],
      unique_by: :index_pbx_call_events_on_pbx_id_and_event_id,
      returning: %w[id]
    )
    return PbxCallEvent.find(result.rows.first.first) if result.rows.present?

    PbxCallEvent.find_by!(pbx_id: pbx_id, event_id: payload['event_id'])
  end

  def find_phone_call
    PhoneCall.find_by(pbx_id: pbx_id, linked_id: linked_id)
  end

  def create_phone_call
    context = resolve_context
    return unless context

    contact_inbox = resolve_contact_inbox(context[:inbox], context[:customer_number])
    conversation = resolve_conversation(contact_inbox)
    PhoneCall.create_or_find_by!(pbx_id: pbx_id, linked_id: linked_id) do |phone_call|
      handled_extension = context[:direction] == 'outbound' ? context[:phone_extension] : nil
      phone_call.assign_attributes(
        account: context[:inbox].account,
        inbox: context[:inbox],
        contact: contact_inbox.contact,
        conversation: conversation,
        user: handled_extension&.user,
        phone_extension: handled_extension,
        direction: context[:direction],
        customer_number: context[:customer_number],
        extension: context[:extension],
        status: 'ringing'
      )
    end
  end

  def resolve_context
    extension = resolved_extension
    inbox = resolve_inbox(extension)
    return unless inbox

    phone_extension = extension.present? ? inbox.phone_extensions.enabled.find_by(sip_username: extension) : nil
    direction = resolved_direction(extension)
    customer_number = normalize_customer_number(resolved_customer_number(extension, direction))
    return if direction.blank? || customer_number.blank?

    { inbox: inbox, phone_extension: phone_extension, extension: extension,
      direction: direction, customer_number: customer_number }
  end

  def resolve_inbox(extension)
    explicit_inbox = Inbox.find_by(id: payload['inbox_id'])
    return explicit_inbox if explicit_inbox&.phone?

    channel = Channel::Phone.find_by(sip_domain: payload['sip_domain'].presence || payload['pbx_id'])
    return channel.inbox if channel&.inbox

    if extension.present?
      matches = PhoneExtension.enabled.where(sip_username: extension).includes(:inbox).to_a
      return matches.first.inbox if matches.one?
    end

    channels = Channel::Phone.includes(:inbox).limit(2).to_a
    channels.one? ? channels.first.inbox : nil
  end

  def resolved_extension
    explicit = payload['extension'].to_s.strip
    return explicit if extension_number?(explicit)
    return payload['from_number'].to_s if extension_number?(payload['from_number'])
    return payload['to_number'].to_s if extension_number?(payload['to_number'])

    nil
  end

  def resolved_direction(extension)
    explicit = payload['business_direction'].presence
    return explicit if PhoneCall::DIRECTIONS.include?(explicit)
    return 'outbound' if extension.present? && payload['from_number'].to_s == extension
    return 'inbound' if extension.present? && payload['to_number'].to_s == extension

    nil
  end

  def resolved_customer_number(extension, direction)
    return payload['customer_number'] if payload['customer_number'].present?
    return payload['to_number'] if direction == 'outbound' && payload['to_number'].to_s != extension
    return payload['from_number'] if direction == 'inbound' && payload['from_number'].to_s != extension

    nil
  end

  def normalize_customer_number(number)
    value = number.to_s.strip
    return if value.blank?

    prefixed = value.start_with?('+')
    digits = value.gsub(/\D/, '')
    return if digits.length < 8
    return "+#{digits}" if prefixed
    return "+#{digits.delete_prefix('00')}" if digits.start_with?('00')
    return "+84#{digits.delete_prefix('0')}" if digits.start_with?('0')
    return "+#{digits}" if digits.start_with?('84')

    "+#{digits}"
  end

  def extension_number?(number)
    number.to_s.match?(/\A\d{2,6}\z/)
  end

  def resolve_contact_inbox(inbox, customer_number)
    raw_number = payload['customer_number'].presence || payload['from_number'].presence || payload['to_number']
    contact = Contacts::InboundPhoneResolver.new(inbox.account, customer_number, raw_number).find_contact
    ContactInboxWithContactBuilder.new(
      inbox: inbox,
      contact_attributes: {
        name: contact&.name || customer_number,
        phone_number: contact&.phone_number || customer_number
      },
      source_id: customer_number
    ).perform
  end

  def resolve_conversation(contact_inbox)
    inbox = contact_inbox.inbox
    conversation = if inbox.lock_to_single_conversation?
                     contact_inbox.conversations.last
                   else
                     contact_inbox.conversations.where.not(status: :resolved).last
                   end
    conversation || Conversation.create!(
      account: inbox.account,
      inbox: inbox,
      contact: contact_inbox.contact,
      contact_inbox: contact_inbox
    )
  end

  def apply_event(phone_call)
    incoming_status = event_status(phone_call.direction)
    assign_answering_agent(phone_call) if payload['event'] == 'call.answered'
    phone_call.assign_attributes(
      last_event_id: payload['event_id'],
      extension: payload['extension'].presence || phone_call.extension,
      from_number: payload['from_number'].presence || phone_call.from_number,
      to_number: payload['to_number'].presence || phone_call.to_number,
      started_at: parse_time(payload['started_at']) || phone_call.started_at,
      answered_at: parse_time(payload['answered_at']) || phone_call.answered_at,
      ended_at: parse_time(payload['ended_at']) || phone_call.ended_at,
      duration_seconds: [phone_call.duration_seconds.to_i, payload['duration'].to_i].max,
      hangup_cause: payload['hangup_cause'].presence || phone_call.hangup_cause,
      recording_url: recording_proxy_url(phone_call),
      metadata: phone_call.metadata.merge(
        'last_leg_uuid' => payload['leg_uuid'],
        'pbx_recording_url' => payload['recording_url'].presence || phone_call.metadata['pbx_recording_url'],
        'callytics_recording_resource' => payload['callbot_recording_resource'].presence || phone_call.metadata['callytics_recording_resource'],
        'callbot_report' => payload['callbot_report'].presence || phone_call.metadata['callbot_report']
      ).compact
    )
    phone_call.status = incoming_status if status_can_advance?(phone_call.status, incoming_status)
  end

  def assign_answering_agent(phone_call)
    extension = payload['extension'].presence || resolved_extension
    return if extension.blank?

    phone_extension = phone_call.inbox.phone_extensions.enabled.find_by(sip_username: extension)
    return unless phone_extension

    phone_call.phone_extension = phone_extension
    phone_call.user = phone_extension.user
    phone_call.extension = extension
  end

  def recording_proxy_url(phone_call)
    return phone_call.recording_url unless payload['recording_url'].present? || payload['callbot_recording_resource'].present?

    "/api/v1/accounts/#{phone_call.account_id}/phone_calls/#{phone_call.id}/recording"
  end

  def event_status(direction)
    case payload['event']
    when 'call.ringing' then 'ringing'
    when 'call.answered' then 'in_progress'
    when 'call.completed' then 'completed'
    when 'call.recording_ready' then nil
    when 'call.missed' then missed_status(direction)
    else payload['status'].presence
    end
  end

  def missed_status(direction)
    case payload['hangup_cause']
    when 'USER_BUSY' then 'busy'
    when 'CALL_REJECTED' then 'rejected'
    when 'ORIGINATOR_CANCEL' then 'cancelled'
    else direction == 'inbound' ? 'missed' : 'no_answer'
    end
  end

  def status_can_advance?(current, incoming)
    return false if incoming.blank?
    return false if PhoneCall::TERMINAL_STATUSES.include?(current) && current != incoming

    STATUS_RANK.fetch(incoming, -1) >= STATUS_RANK.fetch(current, -1)
  end

  def ensure_message(phone_call)
    message = phone_call.message || build_message(phone_call)
    message.assign_attributes(
      content: phone_call.direction == 'inbound' ? 'Cuộc gọi đến' : 'Cuộc gọi đi',
      content_attributes: { data: phone_call.message_data }
    )
    message.save!
    phone_call.update_column(:message_id, message.id) if phone_call.message_id != message.id
  end

  def build_message(phone_call)
    phone_call.conversation.messages.build(
      account: phone_call.account,
      inbox: phone_call.inbox,
      message_type: phone_call.direction == 'inbound' ? :incoming : :outgoing,
      content_type: :phone_call,
      sender: phone_call.direction == 'inbound' ? phone_call.contact : phone_call.user,
      source_id: "phone-call:#{phone_call.pbx_id}:#{phone_call.linked_id}",
      status: :sent
    )
  end

  def parse_time(value)
    Time.zone.parse(value.to_s) if value.present?
  rescue ArgumentError
    nil
  end

  def pbx_id
    @pbx_id ||= payload['pbx_id'].presence || payload['sip_domain'].presence || 'default'
  end

  def linked_id
    @linked_id ||= payload['linked_id'].presence || payload['pbx_call_id'].presence || payload['leg_uuid'].presence
  end
end
