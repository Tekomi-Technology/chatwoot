FactoryBot.define do
  factory :tekomi_assistant_response, class: 'Tekomi::AssistantResponse' do
    association :assistant, factory: :tekomi_assistant
    account { assistant.account }
    sequence(:question) { |n| "Test question #{n}?" }
    sequence(:answer) { |n| "Test answer #{n}" }
    embedding { Array.new(1536) { rand(-1.0..1.0) } }

    trait :with_document do
      association :document, factory: :tekomi_document
    end
  end
end
