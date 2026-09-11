class MoveTekomiLlmConfigToLlmProviders < ActiveRecord::Migration[7.2]
  LEGACY_CONFIG_KEYS = %w[TEKOMI_OPEN_AI_API_KEY TEKOMI_OPEN_AI_MODEL TEKOMI_OPEN_AI_ENDPOINT TEKOMI_EMBEDDING_MODEL].freeze
  INSTALLATION_MODEL_FEATURES = %w[copilot assistant conversation_completion].freeze
  FEATURE_MODELS = {
    'reply_suggestion' => 'gpt-4.1-mini',
    'summary' => 'gpt-4.1-mini',
    'rewrite' => 'gpt-4.1-mini',
    'follow_up' => 'gpt-4.1-mini',
    'overview_summary' => 'gpt-4.1-mini',
    'csat_analysis' => 'gpt-4.1-mini',
    'copilot' => 'gpt-4.1',
    'assistant' => 'gpt-5.2',
    'false_promise_detection' => 'gpt-5.2',
    'instruction_migration' => 'gpt-5.2',
    'label_suggestion' => 'gpt-4.1-mini',
    'conversation_completion' => 'gpt-4.1',
    'document_faq_generation' => 'gpt-4.1-mini',
    'pdf_faq_generation' => 'gpt-4.1-mini',
    'conversation_faq_generation' => 'gpt-5.2',
    'conversation_faq_matching' => 'gpt-4.1-mini',
    'help_center_article_generation' => 'gpt-5.2',
    'help_center_query_translation' => 'gpt-4.1-nano',
    'help_center_curation' => 'gpt-4.1',
    'article_search_terms' => 'gpt-4o',
    'onboarding_content_generation' => 'gpt-4.1',
    'embedding' => 'text-embedding-3-small',
    'audio_transcription' => 'gpt-4o-mini-transcribe'
  }.freeze

  class MigrationLlmProvider < ApplicationRecord
    self.table_name = 'llm_providers'
    encrypts :api_key
  end

  class MigrationLlmFeatureModel < ApplicationRecord
    self.table_name = 'llm_feature_models'
  end

  def up
    api_key = legacy_value('TEKOMI_OPEN_AI_API_KEY')
    if api_key.present?
      raise 'ACTIVE_RECORD_ENCRYPTION_* must be configured before migrating the Tekomi AI API key' unless Chatwoot.encryption_configured?

      create_feature_models(create_provider(api_key))
    end

    InstallationConfig.where(name: LEGACY_CONFIG_KEYS).destroy_all
    execute("UPDATE accounts SET settings = settings - 'tekomi_models' WHERE settings ? 'tekomi_models'")
    execute("DELETE FROM integrations_hooks WHERE app_id = 'openai'")
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def legacy_value(name)
    InstallationConfig.find_by(name: name)&.value.presence
  end

  def create_provider(api_key)
    endpoint = legacy_value('TEKOMI_OPEN_AI_ENDPOINT')
    host = endpoint && URI.parse(endpoint).host
    return MigrationLlmProvider.create!(name: 'OpenRouter', provider_type: 'openrouter', api_key: api_key) if host == 'openrouter.ai'
    return MigrationLlmProvider.create!(name: 'OpenAI', provider_type: 'openai', api_key: api_key) if host.blank? || host == 'api.openai.com'

    api_base = endpoint.chomp('/')
    api_base = "#{api_base}/v1" unless api_base.end_with?('/v1')
    MigrationLlmProvider.create!(name: 'OpenAI compatible', provider_type: 'openai', api_key: api_key, api_base: api_base)
  end

  def create_feature_models(provider)
    installation_model = legacy_value('TEKOMI_OPEN_AI_MODEL')
    embedding_model = legacy_value('TEKOMI_EMBEDDING_MODEL')

    FEATURE_MODELS.each do |feature_key, default_model|
      next if feature_key == 'audio_transcription' && provider.provider_type != 'openai'

      model = legacy_model(feature_key, default_model, installation_model, embedding_model)
      model = "openai/#{model}" if provider.provider_type == 'openrouter' && model.exclude?('/')
      MigrationLlmFeatureModel.create!(feature_key: feature_key, llm_provider_id: provider.id, model: model)
    end
  end

  def legacy_model(feature_key, default_model, installation_model, embedding_model)
    return embedding_model || default_model if feature_key == 'embedding'
    return installation_model || default_model if INSTALLATION_MODEL_FEATURES.include?(feature_key)

    default_model
  end
end
