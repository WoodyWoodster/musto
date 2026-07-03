class AddMetadataToWebhookEvents < ActiveRecord::Migration[8.1]
  def change
    add_column :webhook_events, :metadata, :json, null: false, default: {}
  end
end
