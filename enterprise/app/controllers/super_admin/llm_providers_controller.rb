class SuperAdmin::LlmProvidersController < SuperAdmin::EnterpriseBaseController
  before_action :set_llm_provider, only: [:edit, :update, :destroy]

  def index
    @llm_providers = LlmProvider.includes(:llm_feature_models).order(:name)
  end

  def new
    @llm_provider = LlmProvider.new
  end

  def edit; end

  def create
    @llm_provider = LlmProvider.new(llm_provider_params)
    return redirect_to super_admin_llm_providers_path, notice: I18n.t('super_admin.llm_providers.saved') if @llm_provider.save

    render :new, status: :unprocessable_entity
  end

  def update
    return redirect_to super_admin_llm_providers_path, notice: I18n.t('super_admin.llm_providers.saved') if @llm_provider.update(update_params)

    render :edit, status: :unprocessable_entity
  end

  def destroy
    return redirect_to super_admin_llm_providers_path, notice: I18n.t('super_admin.llm_providers.deleted') if @llm_provider.destroy

    redirect_to super_admin_llm_providers_path, alert: @llm_provider.errors.full_messages.join(', ')
  end

  private

  def set_llm_provider
    @llm_provider = LlmProvider.find(params[:id])
  end

  def llm_provider_params
    params.require(:llm_provider).permit(:name, :provider_type, :api_key, :api_base)
  end

  def update_params
    llm_provider_params.tap { |permitted| permitted.delete(:api_key) if permitted[:api_key].blank? }
  end
end
