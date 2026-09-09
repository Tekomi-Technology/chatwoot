# frozen_string_literal: true

module TekomiFeaturable
  extend ActiveSupport::Concern

  included do
    before_validation :normalize_tekomi_models
    validate :validate_tekomi_models

    # Dynamically define accessor methods for each tekomi feature
    Llm::Models.feature_keys.each do |feature_key|
      # Define enabled? methods (e.g., tekomi_editor_enabled?)
      define_method("tekomi_#{feature_key}_enabled?") do
        tekomi_features_with_defaults[feature_key]
      end

      # Define model accessor methods (e.g., tekomi_editor_model)
      define_method("tekomi_#{feature_key}_model") do
        tekomi_models_with_defaults[feature_key]
      end
    end
  end

  def tekomi_preferences
    {
      models: tekomi_models_with_defaults,
      features: tekomi_features_with_defaults
    }.with_indifferent_access
  end

  private

  def tekomi_models_with_defaults
    Llm::Models.feature_keys.index_with do |feature_key|
      Llm::FeatureRouter.resolve(feature: feature_key, account: self)[:model]
    end
  end

  def tekomi_features_with_defaults
    stored_features = tekomi_features || {}
    Llm::Models.feature_keys.index_with do |feature_key|
      stored_features[feature_key] == true
    end
  end

  def validate_tekomi_models
    return if tekomi_models.blank?

    tekomi_models.each do |feature_key, model_name|
      unless Llm::Models.feature?(feature_key)
        errors.add(:tekomi_models, "'#{feature_key}' is not a known feature")
        next
      end

      next if Llm::Models.valid_model_for?(feature_key, model_name)

      allowed_models = Llm::Models.models_for(feature_key)
      errors.add(:tekomi_models, "'#{model_name}' is not a valid model for #{feature_key}. Allowed: #{allowed_models.join(', ')}")
    end
  end

  def normalize_tekomi_models
    return unless tekomi_models.is_a?(Hash)

    normalized_models = tekomi_models.each_with_object({}) do |(feature_key, model_name), result|
      next if model_name.blank?

      result[feature_key.to_s] = model_name.to_s
    end

    self.tekomi_models = normalized_models.presence
  end
end
