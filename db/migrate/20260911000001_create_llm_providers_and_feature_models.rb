class CreateLlmProvidersAndFeatureModels < ActiveRecord::Migration[7.2]
  def change
    create_table :llm_providers do |t|
      t.string :name, null: false
      t.string :provider_type, null: false
      t.text :api_key
      t.string :api_base

      t.timestamps
    end

    add_index :llm_providers, :name, unique: true
    add_index :llm_providers, :provider_type, unique: true

    create_table :llm_feature_models do |t|
      t.string :feature_key, null: false
      t.references :llm_provider, null: false, foreign_key: { on_delete: :restrict }
      t.string :model, null: false

      t.timestamps
    end

    add_index :llm_feature_models, :feature_key, unique: true
  end
end
