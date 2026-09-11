class BackfillCallyticsRecordings < ActiveRecord::Migration[7.1]
  RESOURCE_PATTERN = '^/api/v1/vendor/call-reports/[^/]+/recording$'.freeze

  def up
    # Callbacks received before recording proxy support already retain the
    # vendor resource inside callbot_report. Expose only documented resources.
    execute <<~SQL.squish
      UPDATE phone_calls
      SET metadata = jsonb_set(
            metadata,
            '{callytics_recording_resource}',
            metadata #> '{callbot_report,recording,access,resource}',
            true
          ),
          recording_url = '/api/v1/accounts/' || account_id || '/phone_calls/' || id || '/recording'
      WHERE pbx_id LIKE 'callytics:%'
        AND recording_url IS NULL
        AND metadata #>> '{callbot_report,recording,available}' = 'true'
        AND metadata #>> '{callbot_report,recording,access,method}' = 'vendor_api'
        AND metadata #>> '{callbot_report,recording,access,resource}' ~ '#{RESOURCE_PATTERN}'
    SQL

    execute <<~SQL.squish
      UPDATE messages AS message
      SET content_attributes = jsonb_set(
            COALESCE(message.content_attributes, '{}'::jsonb),
            '{data,recording_url}',
            to_jsonb(phone_call.recording_url),
            true
          )
      FROM phone_calls AS phone_call
      WHERE message.id = phone_call.message_id
        AND phone_call.pbx_id LIKE 'callytics:%'
        AND phone_call.recording_url IS NOT NULL
        AND phone_call.metadata ? 'callytics_recording_resource'
    SQL
  end

  def down
    # Preserve the recording metadata and URL if this migration is rolled back.
  end
end
