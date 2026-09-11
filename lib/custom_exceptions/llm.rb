module CustomExceptions::Llm
  class FeatureNotConfigured < CustomExceptions::Base
    def message
      I18n.t('errors.llm.feature_not_configured', feature: @data[:feature])
    end
  end
end
