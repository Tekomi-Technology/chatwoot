class RemoveStaleCaptainFeatureDefaults < ActiveRecord::Migration[7.1]
  STALE_NAMES = %w[
    captain_integration
    captain_v1_action_classifier
    captain_integration_v2
    captain_document_auto_sync
    captain_tasks
  ].freeze

  def up
    config = InstallationConfig.find_by(name: 'ACCOUNT_LEVEL_FEATURE_DEFAULTS')
    return if config.blank?

    config.update!(value: config.value.reject { |f| STALE_NAMES.include?(f['name']) })
  end

  def down
    # Stale entries are dropped intentionally; ConfigLoader will re-add the current
    # (tekomi_*) entries on the next boot regardless, so there is nothing to restore.
  end
end
