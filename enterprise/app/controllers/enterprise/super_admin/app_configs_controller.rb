module Enterprise::SuperAdmin::AppConfigsController
  private

  def allowed_configs
    case @config
    when 'custom_branding'
      @allowed_configs = custom_branding_options
    when 'internal'
      @allowed_configs = internal_config_options
    when 'tekomi'
      @allowed_configs = tekomi_config_options
    when 'saml'
      @allowed_configs = saml_config_options
    else
      super
    end
  end

  def custom_branding_options
    %w[
      LOGO_THUMBNAIL
      LOGO
      LOGO_DARK
      BRAND_NAME
      INSTALLATION_NAME
      BRAND_URL
      WIDGET_BRAND_URL
      TERMS_URL
      PRIVACY_URL
      DISPLAY_MANIFEST
    ]
  end

  def internal_config_options
    %w[CLEARBIT_API_KEY CONTEXT_DEV_API_KEY DASHBOARD_SCRIPTS
       INACTIVE_WHATSAPP_NUMBERS SKIP_INCOMING_BCC_PROCESSING TEKOMI_CLOUD_PLAN_LIMITS
       CHATWOOT_INSTANCE_ADMIN_EMAIL OG_IMAGE_CDN_URL OG_IMAGE_CLIENT_REF CLOUDFLARE_API_KEY
       CLOUDFLARE_ZONE_ID BLOCKED_EMAIL_DOMAINS OTEL_PROVIDER LANGFUSE_PUBLIC_KEY LANGFUSE_SECRET_KEY LANGFUSE_BASE_URL]
  end

  def tekomi_config_options
    %w[
      TEKOMI_OPEN_AI_API_KEY
      TEKOMI_OPEN_AI_MODEL
      TEKOMI_OPEN_AI_ENDPOINT
      TEKOMI_EMBEDDING_MODEL
      TEKOMI_FIRECRAWL_API_KEY
    ]
  end

  def saml_config_options
    %w[ENABLE_SAML_SSO_LOGIN]
  end
end
