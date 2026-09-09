module AccountTekomiAutoResolve
  extend ActiveSupport::Concern

  VALID_TEKOMI_AUTO_RESOLVE_MODES = %w[evaluated legacy disabled].freeze

  included do
    VALID_TEKOMI_AUTO_RESOLVE_MODES.each do |mode|
      define_method("tekomi_auto_resolve_#{mode}?") do
        tekomi_auto_resolve_mode == mode
      end
    end
  end

  def tekomi_auto_resolve_mode
    mode = settings&.[]('tekomi_auto_resolve_mode')
    return mode if VALID_TEKOMI_AUTO_RESOLVE_MODES.include?(mode)
    return 'disabled' if settings&.[]('tekomi_disable_auto_resolve') == true

    feature_enabled?('tekomi_tasks') ? 'evaluated' : 'legacy'
  end
end
