module AccountSettingsSchema
  extend ActiveSupport::Concern

  TEKOMI_MODEL_PROPERTIES = Llm::Models.model_feature_keys.index_with { { 'type': %w[string null] } }.freeze
  TEKOMI_FEATURE_PROPERTIES = Llm::Models.feature_keys.index_with { { 'type': %w[boolean null] } }.freeze

  SETTINGS_PARAMS_SCHEMA = {
    'type': 'object',
    'properties':
      {
        'auto_resolve_after': { 'type': %w[integer null], 'minimum': 10, 'maximum': 1_439_856 },
        'auto_resolve_message': { 'type': %w[string null] },
        'auto_resolve_ignore_waiting': { 'type': %w[boolean null] },
        'audio_transcriptions': { 'type': %w[boolean null] },
        'auto_resolve_label': { 'type': %w[string null] },
        'keep_pending_on_bot_failure': { 'type': %w[boolean null] },
        'tekomi_auto_resolve_mode': { 'type': %w[string null], 'enum': ['evaluated', 'legacy', 'disabled', nil] },
        'tekomi_false_promise_harness_enabled': { 'type': %w[boolean null] },
        'conversation_required_attributes': {
          'type': %w[array null],
          'items': { 'type': 'string' }
        },
        'tekomi_models': {
          'type': %w[object null],
          'properties': TEKOMI_MODEL_PROPERTIES,
          'additionalProperties': false
        },
        'tekomi_features': {
          'type': %w[object null],
          'properties': TEKOMI_FEATURE_PROPERTIES,
          'additionalProperties': false
        }
      },
    'required': [],
    'additionalProperties': true
  }.to_json.freeze
end
