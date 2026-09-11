class SuperAdmin::LlmFeatureModelsController < SuperAdmin::EnterpriseBaseController
  def show
    @llm_providers = LlmProvider.order(:name)
    @feature_models = LlmFeatureModel.all.index_by(&:feature_key)
  end

  def update
    ActiveRecord::Base.transaction do
      feature_params.each { |feature_key, attributes| save_feature_model(feature_key, attributes) }
    end
    redirect_to super_admin_llm_feature_models_path, notice: I18n.t('super_admin.llm_feature_models.saved')
  rescue ActiveRecord::RecordInvalid => e
    redirect_to super_admin_llm_feature_models_path, alert: "#{e.record.feature_key}: #{e.record.errors.full_messages.join(', ')}"
  end

  private

  def feature_params
    params.require(:features).permit(Llm::Features.keys.index_with { %i[llm_provider_id model] })
  end

  def save_feature_model(feature_key, attributes)
    feature_model = LlmFeatureModel.find_or_initialize_by(feature_key: feature_key)
    return feature_model.destroy! if attributes[:llm_provider_id].blank? && attributes[:model].blank?

    feature_model.update!(llm_provider_id: attributes[:llm_provider_id], model: attributes[:model])
  end
end
