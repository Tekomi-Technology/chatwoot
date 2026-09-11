# frozen_string_literal: true

module TekomiFeaturable
  extend ActiveSupport::Concern

  TOGGLE_FEATURE_KEYS = %w[label_suggestion help_center_search audio_transcription].freeze

  def tekomi_preferences
    stored_features = tekomi_features || {}
    { features: TOGGLE_FEATURE_KEYS.index_with { |feature_key| stored_features[feature_key] == true } }.with_indifferent_access
  end
end
