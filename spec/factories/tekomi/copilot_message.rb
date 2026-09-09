FactoryBot.define do
  factory :tekomi_copilot_message, class: 'CopilotMessage' do
    account
    copilot_thread { association :tekomi_copilot_thread }
    message { { content: 'This is a test message' } }
    message_type { 0 }
  end
end
