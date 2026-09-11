class Api::V1::Accounts::Inboxes::CallbotWebhooksController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization?
  before_action :fetch_inbox
  before_action :fetch_webhook, only: [:update, :destroy]

  def index
    render json: @inbox.callbot_webhooks.order(:created_at).map { |webhook| webhook_payload(webhook) }
  end

  def create
    webhook = @inbox.callbot_webhooks.create!(webhook_params.merge(account: Current.account))
    render json: webhook_payload(webhook), status: :created
  end

  def update
    @webhook.update!(webhook_params)
    render json: webhook_payload(@webhook)
  end

  def destroy
    @webhook.destroy!
    head :no_content
  end

  private

  def fetch_inbox
    @inbox = Current.account.inboxes.find(params[:inbox_id])
    head :not_found unless @inbox.phone?
  end

  def fetch_webhook
    @webhook = @inbox.callbot_webhooks.find(params[:id])
  end

  def webhook_params
    params.require(:callbot_webhook).permit(:name, :enabled)
  end

  def webhook_payload(webhook)
    {
      id: webhook.id,
      name: webhook.name,
      enabled: webhook.enabled,
      endpoint_url: "#{ENV.fetch('FRONTEND_URL', '').chomp('/')}#{webhook.endpoint_path}",
      created_at: webhook.created_at
    }
  end
end
