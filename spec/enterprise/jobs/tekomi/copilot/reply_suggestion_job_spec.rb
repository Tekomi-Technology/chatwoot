require 'rails_helper'

RSpec.describe Tekomi::Copilot::ReplySuggestionJob, type: :job do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:assistant) { create(:tekomi_assistant, account: account) }
  let(:copilot_thread) { create(:tekomi_copilot_thread, account: account, user: user, assistant: assistant) }
  let(:service) do
    instance_double(
      Tekomi::Copilot::ReplySuggestionService,
      generate_response: nil,
      persist_failure_response: nil
    )
  end

  let(:job_arguments) do
    {
      assistant: assistant,
      conversation_id: 123,
      user_id: user.id,
      copilot_thread_id: copilot_thread.id
    }
  end

  before do
    allow(Tekomi::Copilot::ReplySuggestionService).to receive(:new).with(job_arguments).and_return(service)
  end

  it 'runs the reply suggestion service' do
    described_class.perform_now(**job_arguments)

    expect(service).to have_received(:generate_response)
  end

  it 'retries generation errors without persisting a failure response' do
    allow(service).to receive(:generate_response).and_raise(
      Tekomi::Copilot::ReplySuggestionService::GenerationError,
      'Provider timeout'
    )

    expect { described_class.perform_now(**job_arguments) }.to have_enqueued_job(described_class)
    expect(service).not_to have_received(:persist_failure_response)
  end

  it 'persists a failure response when retries are exhausted' do
    allow(service).to receive(:generate_response).and_raise(
      Tekomi::Copilot::ReplySuggestionService::GenerationError,
      'Provider timeout'
    )
    job = described_class.new(**job_arguments)
    job.exception_executions = {
      [Tekomi::Copilot::ReplySuggestionService::GenerationError].to_s => 2
    }

    expect { job.perform_now }.not_to have_enqueued_job(described_class)
    expect(service).to have_received(:persist_failure_response).once
  end
end
