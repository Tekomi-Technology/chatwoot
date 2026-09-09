FactoryBot.define do
  factory :tekomi_agent_session, class: 'Tekomi::AgentSession' do
    account
    association :assistant, factory: :tekomi_assistant
    session_type { :assistant }
    subject { create(:conversation, account: account) }

    trait :copilot do
      session_type { :copilot }
      user
      subject { create(:tekomi_copilot_thread, account: account, user: user) }
    end
  end
end
