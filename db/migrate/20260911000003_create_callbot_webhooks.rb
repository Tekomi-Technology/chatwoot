class CreateCallbotWebhooks < ActiveRecord::Migration[7.1]
  def change
    create_table :callbot_webhooks do |t|
      t.references :account, null: false, foreign_key: true
      t.references :inbox, null: false, foreign_key: true
      t.string :name, null: false
      t.string :token, null: false
      t.boolean :enabled, null: false, default: true
      t.timestamps
    end

    add_index :callbot_webhooks, :token, unique: true
    add_index :callbot_webhooks, [:inbox_id, :name], unique: true
  end
end
