# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_31_101400) do
  create_table "app_settings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "key"
    t.datetime "updated_at", null: false
    t.string "value"
    t.index ["key"], name: "index_app_settings_on_key", unique: true
  end

  create_table "comments", force: :cascade do |t|
    t.text "content"
    t.datetime "created_at", null: false
    t.integer "document_id", null: false
    t.integer "document_version_id", null: false
    t.string "end_block_id"
    t.integer "end_offset"
    t.boolean "is_resolved", default: false, null: false
    t.text "postfix_text"
    t.text "prefix_text"
    t.text "selected_text"
    t.string "start_block_id"
    t.integer "start_offset"
    t.datetime "updated_at", null: false
    t.index ["document_id"], name: "index_comments_on_document_id"
    t.index ["document_version_id"], name: "index_comments_on_document_version_id"
  end

  create_table "document_nodes", id: :string, force: :cascade do |t|
    t.text "content"
    t.datetime "created_at", null: false
    t.integer "document_version_id", null: false
    t.integer "heading_level"
    t.json "meta"
    t.string "node_id"
    t.string "node_type", null: false
    t.string "parent_id"
    t.integer "position", null: false
    t.datetime "updated_at", null: false
    t.index ["document_version_id"], name: "index_document_nodes_on_document_version_id"
    t.index ["parent_id"], name: "index_document_nodes_on_parent_id"
  end

  create_table "document_versions", force: :cascade do |t|
    t.integer "content_id"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.integer "document_id", null: false
    t.datetime "last_modified_at"
    t.integer "size"
    t.datetime "updated_at", null: false
    t.string "version", null: false
    t.index ["content_type", "content_id"], name: "index_document_versions_on_content"
    t.index ["document_id", "version"], name: "index_document_versions_on_document_id_and_version", unique: true
    t.index ["document_id"], name: "index_document_versions_on_document_id"
  end

  create_table "documents", force: :cascade do |t|
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.integer "current_version_id"
    t.string "file_path", null: false
    t.string "file_type", default: "markdown", null: false
    t.datetime "last_opened_at"
    t.string "name"
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.index ["current_version_id"], name: "index_documents_on_current_version_id"
    t.index ["file_path"], name: "index_documents_on_file_path"
    t.index ["user_id", "file_path"], name: "index_documents_on_user_id_and_file_path", unique: true
    t.index ["user_id"], name: "index_documents_on_user_id"
  end

  create_table "html_contents", force: :cascade do |t|
    t.text "annotated_html", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", default: "Workspace", null: false
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.index ["token"], name: "index_users_on_token", unique: true
  end

  add_foreign_key "comments", "document_versions"
  add_foreign_key "comments", "documents"
  add_foreign_key "document_nodes", "document_nodes", column: "parent_id"
  add_foreign_key "document_nodes", "document_versions"
  add_foreign_key "document_versions", "documents"
  add_foreign_key "documents", "document_versions", column: "current_version_id"
  add_foreign_key "documents", "users"
end
