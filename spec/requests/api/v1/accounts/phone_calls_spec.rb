require 'rails_helper'

RSpec.describe 'Phone Calls API', type: :request do
  let(:account) { create(:account) }
  let(:channel) { create(:channel_phone, account: account) }
  let(:inbox) { channel.inbox }
  let(:contact) { create(:contact, account: account, phone_number: '+84342387314') }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:phone_call) do
    PhoneCall.create!(
      account: account,
      inbox: inbox,
      contact: contact,
      conversation: conversation,
      pbx_id: 'callytics:1',
      linked_id: 'call-1',
      direction: 'outbound',
      status: 'completed',
      customer_number: '+84342387314',
      from_number: '02899966166',
      to_number: '0342387314',
      duration_seconds: 60,
      hangup_cause: 'normal_clearing',
      started_at: Time.zone.parse('2026-09-11 11:00:00'),
      metadata: metadata
    )
  end
  let(:metadata) do
    {
      'callbot_report' => {
        'campaign_id' => 345,
        'metadata' => { 'vendorCallId' => 'vendor-1' },
        'result' => {
          'outcome' => 'answered',
          'summary' => 'Đã thông báo xong.',
          'analysisStatus' => 'ready',
          'customerIntent' => 'Xác nhận thông tin',
          'customerDisposition' => 'engaged',
          'callback' => { 'status' => 'not_requested' },
          'business' => { 'resolution' => 'notification_delivered', 'failureReason' => nil },
          'captured' => { 'fields' => { 'reference' => 'ABC' }, 'confirmedActions' => [] },
          'actions' => []
        },
        'conversation' => {
          'turns' => [
            { 'speaker' => 'bot', 'text' => 'Xin chào |CHAT</ctl>', 'occurredAt' => nil },
            { 'speaker' => 'user', 'text' => 'Tôi đã hiểu', 'occurredAt' => '2026-09-11T11:00:10Z' }
          ]
        }
      }
    }
  end

  before do
    create(:inbox_member, inbox: inbox, user: agent)
  end

  describe 'GET /api/v1/accounts/:account_id/phone_calls/:id' do
    it 'returns callbot details and a cleaned transcript', :aggregate_failures do
      get api_v1_account_phone_call_url(account_id: account.id, id: phone_call.id),
          headers: agent.create_new_auth_token,
          as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include(
        'call_id' => 'call-1',
        'campaign_id' => 345,
        'direction' => 'outbound',
        'summary' => 'Đã thông báo xong.',
        'customer_intent' => 'Xác nhận thông tin',
        'captured_fields' => { 'reference' => 'ABC' }
      )
      expect(response.parsed_body['transcript']).to eq([
                                                         { 'speaker' => 'bot', 'text' => 'Xin chào' },
                                                         {
                                                           'speaker' => 'user',
                                                           'text' => 'Tôi đã hiểu',
                                                           'occurred_at' => '2026-09-11T11:00:10Z'
                                                         }
                                                       ])
    end

    it 'does not expose a details payload for a non-callbot phone call' do
      phone_call.update!(metadata: {})

      get api_v1_account_phone_call_url(account_id: account.id, id: phone_call.id),
          headers: agent.create_new_auth_token,
          as: :json

      expect(response).to have_http_status(:not_found)
    end

    it 'does not accept a recording playback token as dashboard authentication' do
      token = Rails.application.message_verifier('phone_call_recording').generate(
        { phone_call_id: phone_call.id, account_id: account.id },
        expires_in: 1.hour
      )

      get api_v1_account_phone_call_url(account_id: account.id, id: phone_call.id, token: token), as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
