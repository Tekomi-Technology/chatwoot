class LlmProvider < ApplicationRecord
  PROVIDER_TYPES = %w[openai openrouter deepseek anthropic gemini mistral xai ollama].freeze

  encrypts :api_key

  has_many :llm_feature_models, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: true
  validates :provider_type, presence: true, uniqueness: true, inclusion: { in: PROVIDER_TYPES }
  validates :api_key, presence: true, unless: :ollama?
  validates :api_base, presence: true, if: :ollama?
  validate :api_base_supported

  after_commit -> { Llm::Config.bump_version! }

  def ollama?
    provider_type == 'ollama'
  end

  def masked_api_key
    "••••#{api_key.last(4)}" if api_key.present?
  end

  private

  def api_base_supported
    return if api_base.blank? || RubyLLM.config.respond_to?("#{provider_type}_api_base=")

    errors.add(:api_base, :invalid)
  end
end
