module Llm::Features
  CONFIG = YAML.load_file(Rails.root.join('config/llm.yml')).fetch('features').freeze

  class << self
    def keys = CONFIG.keys
    def feature?(feature_key) = CONFIG.key?(feature_key.to_s)
    def grouped = keys.group_by { |feature_key| CONFIG.dig(feature_key, 'group') }
  end
end
