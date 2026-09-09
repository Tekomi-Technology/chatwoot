FactoryBot.define do
  factory :tekomi_inbox, class: 'TekomiInbox' do
    association :tekomi_assistant, factory: :tekomi_assistant
    association :inbox
  end
end
