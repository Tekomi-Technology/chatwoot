# frozen_string_literal: true

# Base service for LLM operations using RubyLLM.
# New features should inherit from this class.
class Llm::BaseAiService
  DEFAULT_TEMPERATURE = 1.0

  attr_reader :model, :provider, :temperature

  def initialize(feature:)
    route = Llm::FeatureRouter.resolve(feature: feature)
    @model = route[:model]
    @provider = route[:provider]
    @temperature = DEFAULT_TEMPERATURE
  end

  def chat(model: @model, provider: @provider, temperature: @temperature)
    RubyLLM.chat(model: model, provider: provider, assume_model_exists: true).with_temperature(temperature)
  end

  private

  # Strips markdown code fences (```json ... ``` or ``` ... ```) that some
  # LLM providers/gateways wrap around JSON responses despite response_format hints.
  def sanitize_json_response(response)
    return response if response.nil?

    response.strip.sub(/\A```(?:\w*)\s*\n?/, '').sub(/\n?\s*```\s*\z/, '').strip
  end
end
