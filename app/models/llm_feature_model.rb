class LlmFeatureModel < ApplicationRecord
  belongs_to :llm_provider

  before_validation { self.model = model.to_s.strip.presence }

  validates :feature_key, presence: true, uniqueness: true, inclusion: { in: ->(_record) { Llm::Features.keys } }
  validates :model, presence: true
end
