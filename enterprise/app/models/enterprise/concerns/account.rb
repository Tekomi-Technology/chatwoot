module Enterprise::Concerns::Account
  extend ActiveSupport::Concern

  included do
    store_accessor :settings, :conversation_required_attributes

    has_many :sla_policies, dependent: :destroy_async
    has_many :applied_slas, dependent: :destroy_async
    has_many :custom_roles, dependent: :destroy_async
    has_many :agent_capacity_policies, dependent: :destroy_async

    has_many :tekomi_assistants, dependent: :destroy_async, class_name: 'Tekomi::Assistant'
    has_many :tekomi_assistant_responses, dependent: :destroy_async, class_name: 'Tekomi::AssistantResponse'
    has_many :tekomi_faq_observations, dependent: :destroy_async, class_name: 'Tekomi::FaqObservation'
    has_many :tekomi_faq_suggestions, dependent: :destroy_async, class_name: 'Tekomi::FaqSuggestion'
    has_many :tekomi_documents, dependent: :destroy_async, class_name: 'Tekomi::Document'
    has_many :tekomi_custom_tools, dependent: :destroy_async, class_name: 'Tekomi::CustomTool'
    has_many :tekomi_agent_sessions, dependent: :destroy_async, class_name: 'Tekomi::AgentSession'
    has_many :conversation_outcomes, dependent: :destroy_async

    has_many :copilot_threads, dependent: :destroy_async
    has_many :companies, dependent: :destroy_async
    has_many :calls, dependent: :destroy_async

    has_one :saml_settings, dependent: :destroy_async, class_name: 'AccountSamlSettings'
  end
end
