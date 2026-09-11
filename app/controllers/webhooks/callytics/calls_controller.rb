class Webhooks::Callytics::CallsController < ActionController::API
  MAX_TIMESTAMP_DRIFT = 5.minutes

  def process_payload
    return head :service_unavailable if webhook_secret.blank?
    return head :not_found unless webhook
    return head :unauthorized unless valid_signature?

    payload = JSON.parse(request.raw_post)
    Callbot::CallCompletedProcessor.new(payload: payload, webhook: webhook).perform
    Rails.logger.info({ event: 'callytics_call_completed.received', webhook_id: webhook.id,
                        event_id: payload['eventId'], call_id: payload.dig('call', 'id') }.to_json)
    head :no_content
  rescue JSON::ParserError
    head :bad_request
  rescue Callbot::CallCompletedProcessor::InvalidPayload => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def webhook
    @webhook ||= CallbotWebhook.enabled.find_by(token: params[:token])
  end

  def webhook_secret
    ENV.fetch('CALLYTICS_WEBHOOK_SECRET', nil)
  end

  def valid_signature?
    signature = parse_signature(request.headers['X-Callytics-Signature'])
    return false unless signature && timestamp_fresh?(signature[:timestamp])

    signed_payload = signature[:timestamp].b + '.'.b + request.raw_post.b
    expected = OpenSSL::HMAC.hexdigest('SHA256', webhook_secret, signed_payload)
    received = signature[:signature]
    received.bytesize == expected.bytesize && ActiveSupport::SecurityUtils.secure_compare(received, expected)
  end

  def parse_signature(header)
    values = header.to_s.split(',').to_h do |part|
      key, value = part.strip.split('=', 2)
      [key, value]
    end
    timestamp = values['t']
    signature = values['v1']
    return unless timestamp&.match?(/\A\d+\z/) && signature&.match?(/\A[a-f0-9]{64}\z/)

    { timestamp: timestamp, signature: signature }
  end

  def timestamp_fresh?(timestamp)
    (Time.current.to_i - timestamp.to_i).abs <= MAX_TIMESTAMP_DRIFT
  end
end
