class Zalo::SendOnZaloPersonalService < Base::SendOnChannelService
  private

  def channel_class
    Channel::ZaloPersonal
  end

  # The worker's own wording ("no_session No active Zalo session for channel 1") is meant for
  # logs, not for the agent reading the failed bubble, so each permanent failure gets a message
  # that says what happened and what to do about it.
  def perform_reply
    message.attachments.present? ? send_attachments : send_text
  rescue ::Zalo::WorkerClient::NoSessionError
    message.update!(status: :failed, external_error: I18n.t('errors.zalo_personal.no_session'))
  rescue ::Zalo::WorkerClient::FileRejectedError
    message.update!(status: :failed, external_error: I18n.t('errors.zalo_personal.file_rejected'))
  end

  def send_text
    return if message.outgoing_content.blank?

    record_external_id(
      ::Zalo::WorkerClient.send_text(
        channel.id,
        thread_target.merge(
          content: message.outgoing_content,
          quote_source: quote_source,
          idempotency_key: "#{message.id}:text"
        ).compact
      )
    )
  end

  # Zalo has no multi-attachment send, so each attachment becomes its own Zalo message. Ids are
  # recorded as each send succeeds, so a partial failure keeps what was delivered and a retry
  # resumes instead of re-sending.
  def send_attachments
    sent_count = external_message_ids.size
    caption = sent_count.zero? ? message.outgoing_content : nil

    message.attachments.drop(sent_count).each_with_index do |attachment, offset|
      record_external_id(upload(attachment, caption, sent_count + offset))
      caption = nil # only the first attachment carries the caption
    end
  end

  def upload(attachment, caption, index)
    path = write_tempfile(attachment)
    ::Zalo::WorkerClient.send_attachment(
      channel.id,
      thread_target.merge(caption: caption.to_s, idempotency_key: "#{message.id}:#{index}"),
      path
    )
  ensure
    FileUtils.rm_rf(File.dirname(path)) if path
  end

  # Streams the blob to disk under its real filename: the multipart part name is what Zalo sees,
  # and zca-js rejects an upload whose filename has no usable extension.
  def write_tempfile(attachment)
    dir = Rails.root.join('tmp/uploads', "zalo-personal-#{attachment.id}")
    FileUtils.mkdir_p(dir)
    path = File.join(dir, attachment.file.filename.to_s)
    File.open(path, 'wb') { |file| attachment.file.blob.open { |blob| IO.copy_stream(blob, file) } }
    path
  end

  # `user:123` / `group:456` — the prefix says which kind of thread to send to, so no lookup.
  def thread_target
    kind, thread_id = contact_inbox.source_id.split(':', 2)
    { kind: kind, thread_id: thread_id }
  end

  # zca-js needs the whole quoted-message envelope, not just its id. It was stored on the
  # message when the quote's original arrived from Zalo.
  def quote_source
    replied_to = message.content_attributes['in_reply_to']
    return if replied_to.blank?

    inbox.messages.find_by(id: replied_to)&.content_attributes&.dig('zalo_quote_source')
  end

  # Each attachment is its own Zalo message, and record_external_id writes source_id after the
  # first one succeeds. A partially-sent message therefore legitimately carries a source_id while
  # still having attachments to deliver, so the base class would otherwise skip the retry.
  # external_message_ids is only ever populated by our own sends, so an inbound echo
  # (source_id set, no recorded ids) still short-circuits correctly and cannot loop.
  def outgoing_message_originated_from_channel?
    return false if partially_sent?

    super
  end

  def partially_sent?
    external_message_ids.present? && external_message_ids.size < message.attachments.size
  end

  def external_message_ids
    message.content_attributes['external_message_ids'] || []
  end

  def record_external_id(zalo_message_id)
    return if zalo_message_id.blank?

    ids = external_message_ids + [zalo_message_id]
    message.update!(
      source_id: ids.first,
      content_attributes: message.content_attributes.merge('external_message_ids' => ids)
    )
    # Zalo echoes our own sends back through selfListen within seconds; this lets
    # Zalo::IncomingMessageService recognise them without scanning the messages table.
    ::Redis::Alfred.setex(
      format(::Redis::Alfred::ZALO_PERSONAL_SENT_MESSAGE, inbox_id: inbox.id, zalo_message_id: zalo_message_id),
      true
    )
  end
end
