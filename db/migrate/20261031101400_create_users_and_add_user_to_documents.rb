class CreateUsersAndAddUserToDocuments < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :name, null: false, default: "Workspace"
      t.string :token, null: false
      t.timestamps
    end

    add_index :users, :token, unique: true

    add_reference :documents, :user, foreign_key: true, index: true

    # Remove the global unique constraint on file_path so multiple users can have the same file name/path
    remove_index :documents, :file_path
    add_index :documents, [:user_id, :file_path], unique: true
    add_index :documents, :file_path
  end
end
