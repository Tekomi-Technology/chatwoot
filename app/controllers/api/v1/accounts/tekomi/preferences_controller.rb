class Api::V1::Accounts::Tekomi::PreferencesController < Api::V1::Accounts::BaseController
  before_action :authorize_account_update, only: [:update]

  def show
    render json: preferences_payload
  end

  def update
    params_to_update = tekomi_params
    @current_account.tekomi_models = params_to_update[:tekomi_models] if params_to_update.key?(:tekomi_models)
    @current_account.tekomi_features = params_to_update[:tekomi_features] if params_to_update.key?(:tekomi_features)
    @current_account.save!

    render json: preferences_payload
  end

  private

  def preferences_payload
    {
      providers: Llm::Models.providers,
      models: Llm::Models.models,
      features: features_with_account_preferences
    }
  end

  def authorize_account_update
    authorize @current_account, :update?
  end

  def tekomi_params
    permitted = {}
    permitted[:tekomi_models] = merged_tekomi_models if params[:tekomi_models].present?
    permitted[:tekomi_features] = merged_tekomi_features if params[:tekomi_features].present?
    permitted
  end

  def merged_tekomi_models
    existing_models = @current_account.tekomi_models || {}
    existing_models.merge(permitted_tekomi_models).compact_blank.presence
  end

  def merged_tekomi_features
    existing_features = @current_account.tekomi_features || {}
    existing_features.merge(permitted_tekomi_features)
  end

  def permitted_tekomi_models
    params.require(:tekomi_models).permit(*tekomi_feature_keys).to_h.stringify_keys
  end

  def permitted_tekomi_features
    params.require(:tekomi_features).permit(*tekomi_feature_keys).to_h.stringify_keys
  end

  def tekomi_feature_keys
    Llm::Models.feature_keys.map(&:to_sym)
  end

  def features_with_account_preferences
    preferences = Current.account.tekomi_preferences
    account_features = preferences[:features] || {}

    Llm::Models.feature_keys.index_with do |feature_key|
      config = Llm::Models.feature_config(feature_key)
      route = Llm::FeatureRouter.resolve(feature: feature_key, account: Current.account)
      config.merge(
        default: default_model_for(feature_key),
        enabled: account_features[feature_key] == true,
        model: route[:model],
        selected: route[:model],
        provider: route[:provider],
        source: route[:source]
      )
    end
  end

  def default_model_for(feature_key)
    return Llm::FeatureRouter::TEKOMI_V2_ASSISTANT_MODEL if feature_key == 'assistant' && Current.account.feature_enabled?('tekomi_integration_v2')

    Llm::Models.default_model_for(feature_key)
  end
end
