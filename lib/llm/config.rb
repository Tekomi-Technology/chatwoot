require 'ruby_llm'

module Llm::Config
  VERSION_KEY = 'LLM_PROVIDERS_CONFIG_VERSION'.freeze

  class << self
    def apply!
      version = $alfred.with { |conn| conn.get(VERSION_KEY) }.to_i
      return if @applied_version == version

      providers = LlmProvider.all.index_by(&:provider_type)
      RubyLLM.configure do |config|
        config.model_registry_file = Rails.root.join('config/llm_models.json').to_s
        config.logger = Rails.logger
        LlmProvider::PROVIDER_TYPES.each { |provider_type| assign_provider(config, provider_type, providers[provider_type]) }
      end
      @applied_version = version
    end

    def bump_version!
      $alfred.with { |conn| conn.incr(VERSION_KEY) }
    end

    private

    def assign_provider(config, provider_type, provider)
      %w[api_key api_base].each do |attribute|
        setter = "#{provider_type}_#{attribute}="
        config.public_send(setter, provider&.public_send(attribute).presence) if config.respond_to?(setter)
      end
    end
  end
end
