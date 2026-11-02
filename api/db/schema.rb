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

ActiveRecord::Schema[8.1].define(version: 2026_10_28_194750) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "citext"
  enable_extension "pg_catalog.plpgsql"

  create_table "categories", force: :cascade do |t|
    t.string "slug", limit: 60, null: false
    t.string "name_uk", limit: 100, null: false
    t.string "name_en", limit: 100, null: false
    t.integer "position"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_categories_on_slug", unique: true
  end

  create_table "email_tokens", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "purpose", limit: 30, null: false
    t.string "token_hash", null: false
    t.datetime "expires_at", null: false
    t.datetime "used_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["token_hash"], name: "index_email_tokens_on_token_hash", unique: true
    t.index ["user_id"], name: "index_email_tokens_on_user_id"
    t.check_constraint "purpose::text = ANY (ARRAY['confirmation'::character varying, 'reset'::character varying]::text[])", name: "chk_email_tokens_purpose"
  end

  create_table "event_translations", force: :cascade do |t|
    t.bigint "event_id", null: false
    t.string "locale", limit: 2, null: false
    t.string "title", limit: 200, null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id", "locale"], name: "index_event_translations_on_event_id_and_locale", unique: true
    t.index ["event_id"], name: "index_event_translations_on_event_id"
    t.check_constraint "locale::text = ANY (ARRAY['uk'::character varying, 'en'::character varying]::text[])", name: "chk_event_translations_locale"
  end

  create_table "events", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "category_id"
    t.bigint "created_by_id", null: false
    t.datetime "start_at"
    t.datetime "end_at"
    t.string "time_zone", limit: 64, default: "Europe/Kyiv", null: false
    t.string "location_type", limit: 10
    t.string "address"
    t.string "city", limit: 100
    t.string "online_url"
    t.string "banner_url"
    t.string "status", limit: 20, default: "draft", null: false
    t.text "rejection_reason"
    t.datetime "submitted_at"
    t.datetime "published_at"
    t.bigint "reviewed_by_id"
    t.datetime "cancelled_at"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_events_on_category_id"
    t.index ["city"], name: "index_events_on_city"
    t.index ["created_by_id"], name: "index_events_on_created_by_id"
    t.index ["organization_id"], name: "index_events_on_organization_id"
    t.index ["reviewed_by_id"], name: "index_events_on_reviewed_by_id"
    t.index ["start_at"], name: "index_events_on_start_at"
    t.index ["status"], name: "index_events_on_status"
    t.check_constraint "end_at > start_at", name: "chk_events_end_after_start"
    t.check_constraint "location_type IS NULL OR (location_type::text = ANY (ARRAY['offline'::character varying, 'online'::character varying]::text[]))", name: "chk_events_location_type"
    t.check_constraint "status::text = ANY (ARRAY['draft'::character varying, 'under_review'::character varying, 'published'::character varying, 'rejected'::character varying, 'cancelled'::character varying]::text[])", name: "chk_events_status"
  end

  create_table "organization_managers", primary_key: ["organization_id", "user_id"], force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "user_id", null: false
    t.bigint "added_by_id"
    t.datetime "added_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["added_by_id"], name: "index_organization_managers_on_added_by_id"
    t.index ["user_id"], name: "index_organization_managers_on_user_id"
  end

  create_table "organization_translations", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.string "locale", limit: 2, null: false
    t.string "name", limit: 150, null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "locale"], name: "index_organization_translations_on_organization_id_and_locale", unique: true
    t.index ["organization_id"], name: "index_organization_translations_on_organization_id"
    t.check_constraint "locale::text = ANY (ARRAY['uk'::character varying, 'en'::character varying]::text[])", name: "chk_org_translations_locale"
  end

  create_table "organizations", force: :cascade do |t|
    t.bigint "owner_id", null: false
    t.citext "slug", null: false
    t.string "logo_url"
    t.citext "contact_email", null: false
    t.string "phone", limit: 32
    t.string "website"
    t.string "address"
    t.string "city", limit: 100
    t.string "status", limit: 20, default: "pending_approval", null: false
    t.text "rejection_reason"
    t.datetime "approved_at"
    t.bigint "approved_by_id"
    t.datetime "blocked_at"
    t.bigint "blocked_by_id"
    t.text "block_reason"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["approved_by_id"], name: "index_organizations_on_approved_by_id"
    t.index ["blocked_by_id"], name: "index_organizations_on_blocked_by_id"
    t.index ["owner_id"], name: "index_organizations_on_owner_id", unique: true
    t.index ["slug"], name: "index_organizations_on_slug_active", unique: true, where: "(deleted_at IS NULL)"
    t.index ["status"], name: "index_organizations_on_status"
    t.check_constraint "status::text = ANY (ARRAY['pending_approval'::character varying, 'approved'::character varying, 'rejected'::character varying, 'blocked'::character varying]::text[])", name: "chk_organizations_status"
  end

  create_table "refresh_tokens", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "token_hash", null: false
    t.datetime "expires_at", null: false
    t.datetime "revoked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["token_hash"], name: "index_refresh_tokens_on_token_hash", unique: true
    t.index ["user_id"], name: "index_refresh_tokens_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.citext "email", null: false
    t.string "password_digest", null: false
    t.string "first_name", limit: 100, null: false
    t.string "last_name", limit: 100, null: false
    t.string "phone", limit: 32
    t.date "birth_date"
    t.string "avatar_url"
    t.string "city", limit: 100
    t.string "preferred_locale", limit: 2, default: "uk", null: false
    t.datetime "email_confirmed_at"
    t.virtual "is_email_confirmed", type: :boolean, null: false, as: "(email_confirmed_at IS NOT NULL)", stored: true
    t.boolean "is_active", default: true, null: false
    t.datetime "blocked_at"
    t.bigint "blocked_by_id"
    t.text "block_reason"
    t.string "platform_role", limit: 20, default: "user", null: false
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["blocked_by_id"], name: "index_users_on_blocked_by_id"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.check_constraint "platform_role::text = ANY (ARRAY['user'::character varying, 'moderator'::character varying]::text[])", name: "chk_users_platform_role"
    t.check_constraint "preferred_locale::text = ANY (ARRAY['uk'::character varying, 'en'::character varying]::text[])", name: "chk_users_preferred_locale"
  end

  add_foreign_key "email_tokens", "users", on_delete: :cascade
  add_foreign_key "event_translations", "events", on_delete: :cascade
  add_foreign_key "events", "categories", on_delete: :restrict
  add_foreign_key "events", "organizations", on_delete: :restrict
  add_foreign_key "events", "users", column: "created_by_id", on_delete: :restrict
  add_foreign_key "events", "users", column: "reviewed_by_id", on_delete: :nullify
  add_foreign_key "organization_managers", "organizations", on_delete: :cascade
  add_foreign_key "organization_managers", "users", column: "added_by_id", on_delete: :nullify
  add_foreign_key "organization_managers", "users", on_delete: :cascade
  add_foreign_key "organization_translations", "organizations", on_delete: :cascade
  add_foreign_key "organizations", "users", column: "approved_by_id", on_delete: :nullify
  add_foreign_key "organizations", "users", column: "blocked_by_id", on_delete: :nullify
  add_foreign_key "organizations", "users", column: "owner_id", on_delete: :restrict
  add_foreign_key "refresh_tokens", "users", on_delete: :cascade
  add_foreign_key "users", "users", column: "blocked_by_id", on_delete: :nullify
end
