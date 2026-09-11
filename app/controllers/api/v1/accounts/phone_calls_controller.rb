require 'open3'

class Api::V1::Accounts::PhoneCallsController < Api::V1::Accounts::BaseController
  include ActionController::Live

  class RecordingTranscodeError < StandardError; end

  before_action :phone_call

  # The dashboard calls Chatwoot, never the PBX. Chatwoot authorizes the agent
  # then proxies an authenticated request to the recording provider.
  def recording
    return proxy_pbx_recording if @phone_call.metadata['pbx_recording_url'].present?
    return proxy_callytics_recording if @phone_call.metadata['callytics_recording_resource'].present?

    head :not_found
  end

  private

  def phone_call
    @phone_call = PhoneCall.where(account: Current.account).find(params[:id])
    authorize @phone_call.conversation, :show?
  end

  def proxy_pbx_recording
    source_url = @phone_call.metadata['pbx_recording_url']
    return head :not_found unless recording_secret.present?

    uri = URI.parse(source_url)
    return head :bad_gateway unless uri.is_a?(URI::HTTPS)

    request_to_pbx = Net::HTTP::Get.new(uri)
    request_to_pbx['Range'] = request.headers['Range'] if request.headers['Range'].present?
    timestamp = Time.current.utc.iso8601
    nonce = SecureRandom.hex(16)
    request_to_pbx['X-Chatwoot-Timestamp'] = timestamp
    request_to_pbx['X-Chatwoot-Nonce'] = nonce
    request_to_pbx['X-Chatwoot-Signature'] = recording_signature(timestamp, nonce, request_to_pbx.method, uri.request_uri)

    stream_response(uri, request_to_pbx)
  rescue URI::InvalidURIError
    head :bad_gateway
  end

  # Callytics sends a relative vendor API resource, never a public object URL.
  # Keep its API key on the server and only allow the documented recording path.
  def proxy_callytics_recording
    return head :not_found unless callytics_api_key.present?

    resource = @phone_call.metadata['callytics_recording_resource'].to_s
    return head :not_found unless resource.match?(%r{\A/api/v1/vendor/call-reports/[^/]+/recording\z})

    uri = URI.join(callytics_api_base_url, resource)
    return head :bad_gateway unless uri.is_a?(URI::HTTPS)

    request_to_callytics = Net::HTTP::Get.new(uri)
    request_to_callytics['X-Callytics-API-Key'] = callytics_api_key

    send_callytics_response(uri, request_to_callytics)
  rescue URI::InvalidURIError
    head :bad_gateway
  end

  # Callytics currently returns Ogg/Opus. Safari and iOS support varies, so
  # normalize it to MP3 before returning it to the authenticated dashboard.
  # Buffering also prevents a browser-aborted media probe from breaking the
  # upstream ActionController::Live stream halfway through.
  def send_callytics_response(uri, outbound_request)
    upstream = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 60) do |http|
      http.request(outbound_request)
    end

    body, content_type = compatible_recording(upstream.body, upstream['Content-Type'])
    response.headers['Cache-Control'] = 'private, no-store'
    send_data body,
              type: content_type,
              disposition: 'inline',
              status: upstream.code.to_i
  rescue SocketError, Net::OpenTimeout, Net::ReadTimeout, RecordingTranscodeError
    head :bad_gateway
  end

  def compatible_recording(body, content_type)
    return [body, content_type.presence || 'application/octet-stream'] unless content_type.to_s.start_with?('audio/ogg')

    output, _error, status = Open3.capture3(
      'ffmpeg', '-nostdin', '-hide_banner', '-loglevel', 'error',
      '-i', 'pipe:0', '-vn', '-codec:a', 'libmp3lame', '-f', 'mp3', 'pipe:1',
      stdin_data: body, binmode: true
    )
    raise RecordingTranscodeError unless status.success? && output.present?

    [output, 'audio/mpeg']
  end

  def stream_response(uri, outbound_request)
    Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 60) do |http|
      http.request(outbound_request) do |recording_response|
        self.status = recording_response.code.to_i
        response.headers['Content-Type'] = recording_response['Content-Type'].presence || 'audio/wav'
        response.headers['Accept-Ranges'] = recording_response['Accept-Ranges'] || 'bytes'
        response.headers['Content-Range'] = recording_response['Content-Range'] if recording_response['Content-Range'].present?
        response.headers['Content-Length'] = recording_response['Content-Length'] if recording_response['Content-Length'].present?
        response.headers['Cache-Control'] = 'private, no-store'
        recording_response.read_body { |chunk| response.stream.write(chunk) }
      end
    end
  rescue SocketError, Net::OpenTimeout, Net::ReadTimeout
    head :bad_gateway
  ensure
    response.stream.close
  end

  def recording_secret
    ENV.fetch('PBX_RECORDING_FETCH_SECRET', nil)
  end

  def callytics_api_key
    ENV.fetch('CALLYTICS_API_KEY', nil)
  end

  def callytics_api_base_url
    ENV.fetch('CALLYTICS_API_BASE_URL', 'https://api.app.voxa.vn')
  end

  def recording_signature(timestamp, nonce, method, request_uri)
    payload = [timestamp, nonce, method, request_uri].join('.')
    "sha256=#{OpenSSL::HMAC.hexdigest('SHA256', recording_secret, payload)}"
  end
end
