FactoryBot.define do
  factory :tekomi_copilot_thread, class: 'CopilotThread' do
    account
    user
    title { Faker::Lorem.sentence }
    assistant { create(:tekomi_assistant, account: account) }
  end
end
