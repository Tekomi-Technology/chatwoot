require 'rails_helper'

RSpec.describe Callbot::CallCompletedProcessor do
  let(:account) { create(:account) }
  let(:channel) { create(:channel_phone, account: account, sip_domain: 'td1.tekomi.vn') }
  let(:inbox) { channel.inbox }
  let(:webhook) { CallbotWebhook.create!(account: account, inbox: inbox, name: 'Collections') }
  let!(:contact) { create(:contact, account: account, phone_number: '+84342387314') }

  def payload(overrides = {})
    {
      eventId: 'call.completed:collections:1',
      eventType: 'call.completed',
      eventVersion: '2.0',
      idempotencyKey: 'call.completed:collections:1',
      campaignId: 345,
      metadata: { vendorCallId: 'vendor-1' },
      call: {
        id: 'call-1',
        direction: 'outbound',
        from: '02899966166',
        to: '0342387314',
        startedAt: '2026-09-11T11:00:00Z',
        answeredAt: '2026-09-11T11:00:04Z',
        endedAt: '2026-09-11T11:01:00Z',
        durationSeconds: 60,
        contactStatus: 'answered',
        endReason: 'normal_clearing'
      },
      result: { outcome: 'answered', summary: 'Đã thông báo xong.', analysisStatus: 'ready' },
      conversation: { turns: [{ speaker: 'bot', text: 'Xin chào' }] }
    }.deep_merge(overrides)
  end

  it 'normalizes 0 and +84 variants, reuses the contact and places outbound calls on the right' do
    described_class.new(payload: payload, webhook: webhook).perform

    phone_call = PhoneCall.last
    expect(phone_call).to have_attributes(contact: contact, direction: 'outbound', customer_number: '+84342387314', status: 'completed')
    expect(phone_call.message).to be_outgoing
    expect(phone_call.message.content_attributes.dig('data', 'callbot_summary')).to eq('Đã thông báo xong.')
    expect(phone_call.metadata.dig('callbot_report', 'campaign_id')).to eq(345)
  end

  it 'places inbound calls on the left and recognizes +84 numbers against local-format contacts' do
    contact.update!(phone_number: '0342387314')
    described_class.new(payload: payload(
      eventId: 'call.completed:collections:2',
      call: { id: 'call-2', direction: 'inbound', from: '+84342387314', to: '02899966166' }
    ), webhook: webhook).perform

    phone_call = PhoneCall.last
    expect(phone_call).to have_attributes(contact: contact, direction: 'inbound')
    expect(phone_call.message).to be_incoming
  end

  it 'deduplicates one delivery and applies a later revision to the same call bubble' do
    described_class.new(payload: payload, webhook: webhook).perform
    described_class.new(payload: payload, webhook: webhook).perform
    described_class.new(payload: payload(
      eventId: 'call.completed:collections:1:r2',
      result: { outcome: 'answered', summary: 'Báo cáo đầy đủ hơn.', analysisStatus: 'ready' }
    ), webhook: webhook).perform

    expect(PhoneCall.count).to eq(1)
    expect(Message.phone_calls.count).to eq(1)
    expect(PbxCallEvent.count).to eq(2)
    expect(PhoneCall.last.message.content_attributes.dig('data', 'callbot_summary')).to eq('Báo cáo đầy đủ hơn.')
  end
end
