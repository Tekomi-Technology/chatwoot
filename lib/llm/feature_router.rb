module Llm::FeatureRouter
  class UnknownFeatureError < StandardError; end

  class << self
    def resolve(feature:)
      feature_key = feature.to_s
      raise UnknownFeatureError, "Unknown LLM feature: #{feature_key}" unless Llm::Features.feature?(feature_key)

      feature_model = LlmFeatureModel.includes(:llm_provider).find_by(feature_key: feature_key)
      raise CustomExceptions::Llm::FeatureNotConfigured.new(feature: feature_key) if feature_model.blank?

      Llm::Config.apply!
      { feature: feature_key, provider: feature_model.llm_provider.provider_type.to_sym, model: feature_model.model }
    end
  end
end
