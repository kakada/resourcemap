class AddPublicToCollection < ActiveRecord::Migration
  def change
    add_column :collections, :public, :boolean
  end
end
