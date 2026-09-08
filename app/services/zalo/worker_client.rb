# Talks to the Zalo worker, the Node process that owns the live zca-js sessions.
# It listens on loopback only, so the shared secret guards against other local processes.
class Zalo::WorkerClient
  class Error < StandardError; end
  # No live session for the channel: the Zalo login is gone or has not connected yet.
  class NoSessionError < Error; end
  # Zalo refused the file (unsupported type, too large). Retrying sends it into the same wall.
  class FileRejectedError < Error; end

  TIMEOUT = 30

  class << self
    def start_qr_login
      post('/qr/start')
    end

    def connect(channel)
      post("/sessions/#{channel.id}/connect", credentials: channel.parsed_credentials)
    end

    def disconnect(channel_id)
      request(:delete, "/sessions/#{channel_id}")
    end

    # Display name and avatar for a Zalo user or group, used when a thread is first seen.
    def profile(channel_id, kind, id)
      request(:get, "/sessions/#{channel_id}/profile", query: { kind: kind, id: id })
    end

    def send_text(channel_id, payload)
      post("/sessions/#{channel_id}/send", payload)['msg_id'].to_s
    end

    # Streamed as multipart rather than base64 so a large file does not inflate by a third on
    # the way through. `file` goes last: @fastify/multipart only exposes the fields parsed
    # before the file part.
    def send_attachment(channel_id, fields, file_path)
      File.open(file_path, 'rb') do |file|
        response = HTTParty.post(
          "#{base_url}/sessions/#{channel_id}/send",
          headers: { 'X-Zalo-Worker-Secret' => secret },
          body: fields.merge(file: file),
          timeout: TIMEOUT
        )
        handle(response)['msg_id'].to_s
      end
    end

    private

    def post(path, body = nil)
      headers = body ? { 'Content-Type' => 'application/json' } : {}
      request(:post, path, body: body&.to_json, headers: headers)
    end

    def request(method, path, body: nil, headers: {}, query: nil)
      response = HTTParty.send(
        method,
        "#{base_url}#{path}",
        headers: headers.merge('X-Zalo-Worker-Secret' => secret),
        body: body,
        query: query,
        timeout: TIMEOUT
      )
      handle(response)
    end

    def handle(response)
      return response.parsed_response if response.success?

      body = response.parsed_response
      detail = body.is_a?(Hash) ? "#{body['error']} #{body['message']}".strip : response.body.to_s
      raise NoSessionError, detail if response.code == 409
      raise FileRejectedError, detail if response.code == 422

      raise Error, "zalo worker request failed with status #{response.code}: #{detail}"
    end

    def base_url
      ENV.fetch('ZALO_WORKER_URL', 'http://127.0.0.1:3100')
    end

    # Missing in production means the worker was never configured; failing here surfaces that
    # as a broken deploy instead of a silently unauthenticated call.
    def secret
      ENV.fetch('ZALO_WORKER_SECRET')
    end
  end
end
