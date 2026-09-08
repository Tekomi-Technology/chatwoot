# Runs when the worker reports a finished QR scan: creates the channel and inbox (or replaces
# the credentials of an existing one), asks the worker to open the real session, and records the
# outcome where the dashboard's polling can see it.
class Zalo::QrCompletionService
  pattr_initialize [:params!]

  def perform
    return if pending.blank?

    channel = pending[:channel_id].present? ? reauthenticate : create_channel_with_inbox
    ::Zalo::WorkerClient.connect(channel)
    resolve(status: 'success', inbox_id: channel.inbox.id)
  rescue Mismatch
    resolve(status: 'error', error: 'account_mismatch')
  end

  # Zalo abandoned the login: the code expired unscanned, or the user declined it on their phone.
  def fail!
    return if pending.blank?

    resolve(params[:reason] == 'expired' ? { status: 'expired' } : { status: 'error', error: params[:reason] })
  end

  # The re-scan produced a different Zalo account than the inbox belongs to. Overwriting would
  # point every existing contact and conversation at the wrong person, so refuse.
  class Mismatch < StandardError; end

  private

  def reauthenticate
    channel = ::Channel::ZaloPersonal.find(pending[:channel_id])
    raise Mismatch if channel.zalo_uid != zalo_uid

    # Back to `reconnecting`, the same state a freshly created channel starts in: the credentials
    # are good and the worker is about to open the session. Leaving it `expired` would keep the
    # inbox reporting a dead session — and asking for another QR scan — while one is being opened.
    channel.update!(
      credentials: credentials_json,
      display_name: display_name.presence || channel.display_name,
      status: 'reconnecting',
      status_updated_at: Time.current
    )
    channel
  end

  def create_channel_with_inbox
    account = Account.find(pending[:account_id])

    ActiveRecord::Base.transaction do
      channel = account.zalo_personal_channels.create!(
        zalo_uid: zalo_uid,
        display_name: display_name,
        credentials: credentials_json
      )
      account.inboxes.create!(name: display_name.presence || channel.name, channel: channel)
      channel
    end
  end

  def zalo_uid
    params[:zalo_uid].to_s
  end

  def display_name
    params[:display_name].to_s
  end

  def credentials_json
    params[:credentials].to_json
  end

  def pending
    @pending ||= begin
      raw = ::Redis::Alfred.get(cache_key)
      raw.present? ? JSON.parse(raw).with_indifferent_access : nil
    end
  end

  # Keep the record in place so the dashboard's next poll reads the outcome; it expires on its own.
  def resolve(attributes)
    ::Redis::Alfred.setex(cache_key, pending.merge(attributes).to_json, 5.minutes)
  end

  def cache_key
    format(::Redis::Alfred::ZALO_PERSONAL_QR_SESSION, qr_session_id: params[:qr_session_id])
  end
end
