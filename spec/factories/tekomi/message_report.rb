FactoryBot.define do
  factory :tekomi_message_report, class: 'Tekomi::MessageReport' do
    report_reason { 'incorrect_information' }
    description { 'The generated citation is wrong.' }
    association :message
    association :user
  end
end
