FactoryBot.define do
  factory :tekomi_assistant, class: 'Tekomi::Assistant' do
    sequence(:name) { |n| "Assistant #{n}" }
    description { 'Test description' }
    association :account
  end
end
