require 'rails_helper'

describe TekomiListener do
  let(:listener) { described_class.instance }
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:user) { create(:user, account: account) }
  let(:assistant) { create(:tekomi_assistant, account: account, config: { feature_memory: true, feature_faq: true }) }

  describe '#conversation_resolved' do
    let(:conversation) { create(:conversation, account: account, inbox: inbox, assignee: user) }

    let(:event_name) { :conversation_resolved }
    let(:event) { Events::Base.new(event_name, Time.zone.now.change(usec: 0), conversation: conversation) }

    before do
      create(:tekomi_inbox, tekomi_assistant: assistant, inbox: inbox)
    end

    context 'when feature_memory is enabled' do
      before do
        assistant.config['feature_memory'] = true
        assistant.config['feature_faq'] = false
        assistant.save!
      end

      it 'generates and updates notes' do
        expect(Tekomi::Llm::ContactNotesService)
          .to receive(:new)
          .with(assistant, conversation)
          .and_return(instance_double(Tekomi::Llm::ContactNotesService, generate_and_update_notes: nil))
        expect(Tekomi::Llm::ConversationFaqJob).not_to receive(:perform_later)

        listener.conversation_resolved(event)
      end
    end

    context 'when feature_faq is enabled' do
      before do
        assistant.config['feature_faq'] = true
        assistant.config['feature_memory'] = false
        assistant.save!
      end

      it 'enqueues FAQ suggestion generation' do
        expect(Tekomi::Llm::ConversationFaqJob).to receive(:perform_later).with(conversation, assistant)
        expect(Tekomi::Llm::ContactNotesService).not_to receive(:new)

        listener.conversation_resolved(event)
      end
    end

    it 'records the resolution on an existing V2 outcome' do
      assistant.update!(config: {})
      outcome = create(
        :conversation_outcome,
        account: account,
        assistant: assistant,
        conversation: conversation,
        inbox: inbox,
        started_at: 10.minutes.ago
      )
      tekomi_reply = create(
        :message,
        account: account,
        inbox: inbox,
        conversation: conversation,
        sender: assistant,
        message_type: :outgoing,
        created_at: 5.minutes.ago.change(usec: 0)
      )

      listener.conversation_resolved(event)

      expect(outcome.reload).to have_attributes(
        tekomi_reply_count: 1,
        first_tekomi_reply_at: tekomi_reply.created_at,
        resolved_at: event.timestamp
      )
    end
  end

  describe '#message_updated' do
    let(:conversation) { create(:conversation, account: account, inbox: inbox) }
    let!(:outcome) do
      create(
        :conversation_outcome,
        account: account,
        assistant: assistant,
        conversation: conversation,
        inbox: inbox
      )
    end

    it 'records a submitted CSAT response' do
      message = create(
        :message,
        account: account,
        inbox: inbox,
        conversation: conversation,
        content_type: :input_csat,
        message_type: :outgoing
      )
      response = create(
        :csat_survey_response,
        account: account,
        conversation: conversation,
        contact: conversation.contact,
        message: message,
        rating: 5
      )
      event = Events::Base.new(:message_updated, Time.current, message: message)

      listener.message_updated(event)

      expect(outcome.reload).to have_attributes(
        csat_rating: 5,
        csat_received_at: response.created_at
      )
    end
  end
end
