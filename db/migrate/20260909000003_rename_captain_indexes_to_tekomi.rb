class RenameCaptainIndexesToTekomi < ActiveRecord::Migration[7.1]
  def change
    rename_index :tekomi_documents, 'idx_captain_documents_on_assistant_id_and_external_link_md5',
                 'idx_tekomi_documents_on_assistant_id_and_external_link_md5'
    rename_index :tekomi_documents, 'idx_captain_documents_on_account_assistant_sync_stats',
                 'idx_tekomi_documents_on_account_assistant_sync_stats'
    rename_index :tekomi_faq_observations, 'idx_captain_faq_observations_on_conversation_and_suggestion',
                 'idx_tekomi_faq_observations_on_conversation_and_suggestion'
    rename_index :tekomi_faq_suggestions, 'vector_idx_captain_faq_suggestions_embedding',
                 'vector_idx_tekomi_faq_suggestions_embedding'
  end
end
