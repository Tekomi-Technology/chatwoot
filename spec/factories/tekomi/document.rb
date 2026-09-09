FactoryBot.define do
  factory :tekomi_document, class: 'Tekomi::Document' do
    name { Faker::File.file_name }
    external_link { Faker::Internet.unique.url }
    content { Faker::Lorem.paragraphs.join("\n\n") }
    association :assistant, factory: :tekomi_assistant
    association :account
  end
end
