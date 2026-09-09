class RenameCaptainTablesToTekomi < ActiveRecord::Migration[7.1]
  def change
    rename_table :captain_assistants, :tekomi_assistants
    rename_table :captain_assistant_responses, :tekomi_assistant_responses
    rename_table :captain_documents, :tekomi_documents
    rename_table :captain_faq_suggestions, :tekomi_faq_suggestions
    rename_table :captain_faq_observations, :tekomi_faq_observations
    rename_table :captain_custom_tools, :tekomi_custom_tools
    rename_table :captain_inboxes, :tekomi_inboxes
    rename_table :captain_message_reports, :tekomi_message_reports
    rename_table :captain_scenarios, :tekomi_scenarios

    rename_column :tekomi_inboxes, :captain_assistant_id, :tekomi_assistant_id
    rename_column :conversation_outcomes, :first_captain_reply_at, :first_tekomi_reply_at
    rename_column :conversation_outcomes, :last_captain_reply_at, :last_tekomi_reply_at
    rename_column :conversation_outcomes, :captain_reply_count, :tekomi_reply_count
  end
end
