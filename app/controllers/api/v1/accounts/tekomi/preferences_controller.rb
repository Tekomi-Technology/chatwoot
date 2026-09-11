class Api::V1::Accounts::Tekomi::PreferencesController < Api::V1::Accounts::BaseController
  before_action :authorize_account_update, only: [:update]

  def show
    render json: preferences_payload
  end

  def update
    @current_account.tekomi_features = (@current_account.tekomi_features || {}).merge(permitted_tekomi_features)
    @current_account.save!

    render json: preferences_payload
  end

  private

  def authorize_account_update
    authorize @current_account, :update?
  end

  def permitted_tekomi_features
    params.require(:tekomi_features).permit(*TekomiFeaturable::TOGGLE_FEATURE_KEYS).to_h.stringify_keys
  end

  def preferences_payload
    { features: @current_account.tekomi_preferences[:features].transform_values { |enabled| { enabled: enabled } } }
  end
end
