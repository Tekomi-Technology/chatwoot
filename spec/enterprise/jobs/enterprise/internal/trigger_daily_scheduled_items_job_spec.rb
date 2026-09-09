require 'rails_helper'

RSpec.describe Internal::TriggerDailyScheduledItemsJob do
  before do
    allow(Tekomi::Documents::ScheduleSyncsJob).to receive(:perform_later)
  end

  it 'enqueues enterprise Tekomi document auto-sync every day' do
    travel_to Time.zone.parse('2026-05-26 00:00:00 UTC') do
      described_class.perform_now
    end

    expect(Tekomi::Documents::ScheduleSyncsJob).to have_received(:perform_later).with('enterprise')
  end

  it 'enqueues business Tekomi document auto-sync weekly' do
    travel_to Time.zone.parse('2026-05-24 00:00:00 UTC') do
      described_class.perform_now
    end

    expect(Tekomi::Documents::ScheduleSyncsJob).to have_received(:perform_later).with('business')
  end

  it 'enqueues startup Tekomi document auto-sync monthly' do
    travel_to Time.zone.parse('2026-06-01 00:00:00 UTC') do
      described_class.perform_now
    end

    expect(Tekomi::Documents::ScheduleSyncsJob).to have_received(:perform_later).with('startups')
  end

  it 'does not enqueue business or startup Tekomi document auto-sync before their plan window' do
    travel_to Time.zone.parse('2026-05-25 00:00:00 UTC') do
      described_class.perform_now
    end

    expect(Tekomi::Documents::ScheduleSyncsJob).to have_received(:perform_later).with('enterprise')
    expect(Tekomi::Documents::ScheduleSyncsJob).not_to have_received(:perform_later).with('business')
    expect(Tekomi::Documents::ScheduleSyncsJob).not_to have_received(:perform_later).with('startups')
  end
end
