require 'rails_helper'

RSpec.describe 'Webhooks::Callytics::CallsController', type: :request do
  let(:secret) { 'test-callytics-webhook-secret' }
  let(:account) { create(:account) }
  let(:inbox) { create(:channel_phone, account: account).inbox }
  let(:webhook) { CallbotWebhook.create!(account: account, inbox: inbox, name: 'Test') }
  let(:timestamp) { Time.current.to_i.to_s }
  let(:payload) do
    {
      eventId: 'call.completed:test:1', eventType: 'call.completed', eventVersion: '2.0',
      call: { id: 'call-1', direction: 'outbound', from: '02899966166', to: '0342387314' }
    }
  end
  let(:body) { payload.to_json }
  let(:signature) { OpenSSL::HMAC.hexdigest('SHA256', secret, "#{timestamp}.#{body}") }
  let(:headers) do
    { 'CONTENT_TYPE' => 'application/json', 'X-Callytics-Signature' => "t=#{timestamp},v1=#{signature}" }
  end

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('CALLYTICS_WEBHOOK_SECRET', nil).and_return(secret)
  end

  it 'accepts a valid raw-body HMAC request' do
    processor = instance_double(Callbot::CallCompletedProcessor, perform: nil)
    allow(Callbot::CallCompletedProcessor).to receive(:new).and_return(processor)

    post "/webhooks/callytics/#{webhook.token}", params: body, headers: headers

    expect(response).to have_http_status(:no_content)
    expect(processor).to have_received(:perform)
  end

  it 'rejects a signature that does not cover the raw body' do
    headers['X-Callytics-Signature'] = "t=#{timestamp},v1=#{'0' * 64}"

    post "/webhooks/callytics/#{webhook.token}", params: body, headers: headers

    expect(response).to have_http_status(:unauthorized)
  end

  it 'does not expose disabled webhook endpoints' do
    webhook.update!(enabled: false)

    post "/webhooks/callytics/#{webhook.token}", params: body, headers: headers

    expect(response).to have_http_status(:not_found)
  end
end
