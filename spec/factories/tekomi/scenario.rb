FactoryBot.define do
  factory :tekomi_scenario, class: 'Tekomi::Scenario' do
    sequence(:title) { |n| "Scenario #{n}" }
    description { 'Test scenario description' }
    instruction { 'Test scenario instruction for the assistant to follow' }
    tools { [] }
    enabled { true }
    association :assistant, factory: :tekomi_assistant
    association :account
  end
end
