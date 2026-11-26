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

ActiveRecord::Schema[8.1].define(version: 2026_11_26_151616) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "citext"
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_trgm"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "answers", force: :cascade do |t|
    t.bigint "question_id", null: false
    t.bigint "author_id", null: false
    t.text "text", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["author_id"], name: "index_answers_on_author_id"
    t.index ["question_id", "created_at"], name: "index_answers_on_question_id_and_created_at"
    t.index ["question_id"], name: "index_answers_on_question_id"
    t.check_constraint "char_length(text) >= 1 AND char_length(text) <= 2000", name: "chk_answers_text_length"
  end

  create_table "appeals", force: :cascade do |t|
    t.string "target_type", limit: 20, null: false
    t.bigint "target_id", null: false
    t.bigint "submitted_by_id", null: false
    t.text "message", null: false
    t.string "status", limit: 20, default: "open", null: false
    t.text "decision_reason"
    t.bigint "reviewed_by_id"
    t.datetime "reviewed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["reviewed_by_id"], name: "index_appeals_on_reviewed_by_id"
    t.index ["status"], name: "index_appeals_on_status"
    t.index ["submitted_by_id"], name: "index_appeals_on_submitted_by_id"
    t.index ["target_type", "target_id", "created_at"], name: "index_appeals_on_target"
    t.index ["target_type", "target_id"], name: "idx_appeals_one_open_per_target", unique: true, where: "((status)::text = 'open'::text)"
    t.check_constraint "char_length(message) >= 1 AND char_length(message) <= 2000", name: "chk_appeals_message_length"
    t.check_constraint "status::text = ANY (ARRAY['open'::character varying, 'accepted'::character varying, 'rejected'::character varying]::text[])", name: "chk_appeals_status"
    t.check_constraint "target_type::text = ANY (ARRAY['User'::character varying, 'Organization'::character varying]::text[])", name: "chk_appeals_target_type"
  end

  create_table "categories", force: :cascade do |t|
    t.string "slug", limit: 60, null: false
    t.string "name_uk", limit: 100, null: false
    t.string "name_en", limit: 100, null: false
    t.integer "position"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_categories_on_slug", unique: true
  end

  create_table "company_members", primary_key: ["organization_id", "user_id"], force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "user_id", null: false
    t.bigint "added_by_id"
    t.datetime "added_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "role_id", null: false
    t.index ["added_by_id"], name: "index_company_members_on_added_by_id"
    t.index ["organization_id"], name: "idx_company_members_one_owner_per_org", unique: true, where: "(role_id = 1)"
    t.index ["role_id"], name: "index_company_members_on_role_id"
    t.index ["user_id"], name: "idx_company_members_one_org_per_user", unique: true, where: "(role_id = 1)"
    t.index ["user_id"], name: "index_company_members_on_user_id"
  end

  create_table "email_outboxes", force: :cascade do |t|
    t.string "to_email", null: false
    t.string "template", null: false
    t.string "dedup_key", null: false
    t.jsonb "payload", default: {}, null: false
    t.string "status", default: "pending", null: false
    t.integer "attempts", default: 0, null: false
    t.text "last_error"
    t.datetime "sent_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["dedup_key"], name: "index_email_outboxes_on_dedup_key", unique: true
    t.index ["status", "created_at"], name: "index_email_outboxes_on_status_and_created_at"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying, 'sent'::character varying, 'failed'::character varying]::text[])", name: "chk_email_outboxes_status"
  end

  create_table "event_media", force: :cascade do |t|
    t.bigint "event_id", null: false
    t.string "kind", limit: 10, null: false
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id", "kind", "position"], name: "index_event_media_on_event_kind_position"
    t.index ["event_id"], name: "idx_event_media_one_banner", unique: true, where: "((kind)::text = 'banner'::text)"
    t.index ["event_id"], name: "index_event_media_on_event_id"
    t.check_constraint "\"position\" >= 0", name: "chk_event_media_position"
    t.check_constraint "kind::text = ANY (ARRAY['banner'::character varying, 'gallery'::character varying]::text[])", name: "chk_event_media_kind"
  end

  create_table "event_reviews", force: :cascade do |t|
    t.bigint "event_id", null: false
    t.bigint "user_id", null: false
    t.integer "rating", null: false
    t.text "text"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id", "user_id"], name: "index_event_reviews_on_event_id_and_user_id", unique: true
    t.index ["event_id"], name: "index_event_reviews_on_event_id"
    t.index ["user_id"], name: "index_event_reviews_on_user_id"
    t.check_constraint "rating >= 1 AND rating <= 5", name: "chk_event_reviews_rating"
  end

  create_table "event_revisions", force: :cascade do |t|
    t.bigint "event_id", null: false
    t.bigint "submitted_by_id", null: false
    t.jsonb "payload", default: {}, null: false
    t.string "status", limit: 20, default: "under_review", null: false
    t.bigint "reviewed_by_id"
    t.datetime "reviewed_at"
    t.text "rejection_reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "idx_event_revisions_one_pending", unique: true, where: "((status)::text = 'under_review'::text)"
    t.index ["event_id"], name: "index_event_revisions_on_event_id"
    t.index ["reviewed_by_id"], name: "index_event_revisions_on_reviewed_by_id"
    t.index ["submitted_by_id"], name: "index_event_revisions_on_submitted_by_id"
    t.check_constraint "status::text = ANY (ARRAY['under_review'::character varying, 'approved'::character varying, 'rejected'::character varying, 'withdrawn'::character varying]::text[])", name: "chk_event_revisions_status"
  end

  create_table "event_status_histories", force: :cascade do |t|
    t.bigint "event_id", null: false
    t.string "from_status", limit: 30
    t.string "to_status", limit: 30, null: false
    t.bigint "changed_by_id"
    t.text "reason"
    t.string "error_code", limit: 50
    t.datetime "changed_at", null: false
    t.index ["changed_by_id"], name: "index_event_status_histories_on_changed_by_id"
    t.index ["event_id", "changed_at"], name: "index_event_status_histories_on_event_id_and_changed_at"
    t.index ["event_id"], name: "index_event_status_histories_on_event_id"
    t.check_constraint "from_status IS NULL OR (from_status::text = ANY (ARRAY['draft'::character varying, 'under_review'::character varying, 'published'::character varying, 'rejected'::character varying, 'cancelled'::character varying, 'cancelled_by_organizer'::character varying]::text[]))", name: "chk_event_status_histories_from_status"
    t.check_constraint "to_status::text = ANY (ARRAY['draft'::character varying, 'under_review'::character varying, 'published'::character varying, 'rejected'::character varying, 'cancelled'::character varying, 'cancelled_by_organizer'::character varying]::text[])", name: "chk_event_status_histories_to_status"
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
    t.index ["title"], name: "index_event_translations_on_title_trgm", opclass: :gin_trgm_ops, using: :gin
    t.check_constraint "locale::text = ANY (ARRAY['uk'::character varying::text, 'en'::character varying::text])", name: "chk_event_translations_locale"
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
    t.string "status", limit: 30, default: "draft", null: false
    t.text "rejection_reason"
    t.datetime "submitted_at"
    t.datetime "published_at"
    t.bigint "reviewed_by_id"
    t.datetime "cancelled_at"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "average_rating", precision: 3, scale: 2
    t.integer "reviews_count", default: 0, null: false
    t.index ["category_id"], name: "index_events_on_category_id"
    t.index ["city"], name: "index_events_on_city"
    t.index ["created_by_id"], name: "index_events_on_created_by_id"
    t.index ["organization_id"], name: "index_events_on_organization_id"
    t.index ["reviewed_by_id"], name: "index_events_on_reviewed_by_id"
    t.index ["start_at"], name: "index_events_on_start_at"
    t.index ["status"], name: "index_events_on_status"
    t.check_constraint "end_at > start_at", name: "chk_events_end_after_start"
    t.check_constraint "location_type IS NULL OR (location_type::text = ANY (ARRAY['offline'::character varying::text, 'online'::character varying::text]))", name: "chk_events_location_type"
    t.check_constraint "reviews_count >= 0", name: "chk_events_reviews_count"
    t.check_constraint "status::text = ANY (ARRAY['draft'::character varying, 'under_review'::character varying, 'published'::character varying, 'rejected'::character varying, 'cancelled'::character varying, 'cancelled_by_organizer'::character varying]::text[])", name: "chk_events_status"
  end

  create_table "moderation_logs", force: :cascade do |t|
    t.string "entity_type", limit: 30, null: false
    t.bigint "entity_id", null: false
    t.bigint "moderator_id"
    t.string "decision", limit: 30, null: false
    t.text "reason"
    t.datetime "created_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.index ["created_at"], name: "index_moderation_logs_on_created_at"
    t.index ["entity_type", "entity_id", "created_at"], name: "index_moderation_logs_on_entity"
    t.index ["moderator_id"], name: "index_moderation_logs_on_moderator_id"
    t.check_constraint "decision::text = ANY (ARRAY['approved'::character varying, 'rejected'::character varying, 'blocked'::character varying, 'unblocked'::character varying, 'appeal_submitted'::character varying, 'appeal_accepted'::character varying, 'appeal_rejected'::character varying]::text[])", name: "chk_moderation_logs_decision"
    t.check_constraint "entity_type::text = ANY (ARRAY['User'::character varying, 'Organization'::character varying, 'Event'::character varying, 'Appeal'::character varying]::text[])", name: "chk_moderation_logs_entity_type"
  end

  create_table "order_items", force: :cascade do |t|
    t.bigint "order_id", null: false
    t.bigint "ticket_type_id", null: false
    t.integer "quantity", null: false
    t.integer "unit_price", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["order_id"], name: "index_order_items_on_order_id"
    t.index ["ticket_type_id"], name: "index_order_items_on_ticket_type_id"
  end

  create_table "orders", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "event_id", null: false
    t.integer "total_amount", null: false
    t.string "currency", default: "980", null: false
    t.string "status", default: "pending", null: false
    t.string "idempotency_key", null: false
    t.datetime "reserved_until"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_orders_on_event_id"
    t.index ["idempotency_key"], name: "index_orders_on_idempotency_key", unique: true
    t.index ["user_id"], name: "index_orders_on_user_id"
  end

  create_table "organization_reviews", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "user_id", null: false
    t.integer "rating", null: false
    t.text "text"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "user_id"], name: "index_organization_reviews_on_organization_id_and_user_id", unique: true
    t.index ["organization_id"], name: "index_organization_reviews_on_organization_id"
    t.index ["user_id"], name: "index_organization_reviews_on_user_id"
    t.check_constraint "rating >= 1 AND rating <= 5", name: "chk_organization_reviews_rating"
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
    t.check_constraint "locale::text = ANY (ARRAY['uk'::character varying::text, 'en'::character varying::text])", name: "chk_org_translations_locale"
  end

  create_table "organizations", force: :cascade do |t|
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
    t.decimal "average_rating", precision: 3, scale: 2
    t.integer "reviews_count", default: 0, null: false
    t.index ["approved_by_id"], name: "index_organizations_on_approved_by_id"
    t.index ["blocked_by_id"], name: "index_organizations_on_blocked_by_id"
    t.index ["slug"], name: "index_organizations_on_slug_active", unique: true, where: "(deleted_at IS NULL)"
    t.index ["status"], name: "index_organizations_on_status"
    t.check_constraint "reviews_count >= 0", name: "chk_organizations_reviews_count"
    t.check_constraint "status::text = ANY (ARRAY['pending_approval'::character varying::text, 'approved'::character varying::text, 'rejected'::character varying::text, 'blocked'::character varying::text])", name: "chk_organizations_status"
  end

  create_table "questions", force: :cascade do |t|
    t.bigint "author_id", null: false
    t.string "target_type", null: false
    t.bigint "target_id"
    t.text "text", null: false
    t.boolean "is_hidden", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["author_id"], name: "index_questions_on_author_id"
    t.index ["target_type", "target_id", "created_at"], name: "index_questions_on_target"
    t.check_constraint "char_length(text) >= 1 AND char_length(text) <= 2000", name: "chk_questions_text_length"
    t.check_constraint "target_type::text = ANY (ARRAY['Event'::character varying, 'Organization'::character varying, 'Platform'::character varying]::text[])", name: "chk_questions_target_type"
  end

  create_table "roles", force: :cascade do |t|
    t.string "key", limit: 30, null: false
    t.string "name_uk", limit: 100, null: false
    t.string "name_en", limit: 100, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_roles_on_key", unique: true
  end

  create_table "ticket_types", force: :cascade do |t|
    t.bigint "event_id", null: false
    t.string "name", limit: 200, null: false
    t.integer "price", default: 0, null: false
    t.string "currency", limit: 3, default: "UAH", null: false
    t.integer "total_quantity", null: false
    t.integer "sold_quantity", default: 0, null: false
    t.datetime "sale_start_at"
    t.datetime "sale_end_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_ticket_types_on_event_id"
    t.check_constraint "price >= 0", name: "chk_ticket_types_price"
    t.check_constraint "sold_quantity >= 0 AND sold_quantity <= total_quantity", name: "chk_ticket_types_sold_within_total"
    t.check_constraint "total_quantity > 0", name: "chk_ticket_types_total_quantity"
  end

  create_table "tickets", force: :cascade do |t|
    t.bigint "order_item_id", null: false
    t.bigint "user_id", null: false
    t.bigint "event_id", null: false
    t.string "code", limit: 50, null: false
    t.string "qr_token", limit: 128, null: false
    t.string "status", limit: 20, default: "valid", null: false
    t.datetime "issued_at", null: false
    t.datetime "used_at"
    t.bigint "checked_in_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["checked_in_by_id"], name: "index_tickets_on_checked_in_by_id"
    t.index ["code"], name: "index_tickets_on_code", unique: true
    t.index ["event_id"], name: "index_tickets_on_event_id"
    t.index ["order_item_id"], name: "index_tickets_on_order_item_id"
    t.index ["qr_token"], name: "index_tickets_on_qr_token", unique: true
    t.index ["status"], name: "index_tickets_on_status"
    t.index ["user_id"], name: "index_tickets_on_user_id"
    t.check_constraint "status::text = ANY (ARRAY['valid'::character varying, 'used'::character varying, 'cancelled'::character varying]::text[])", name: "chk_tickets_status"
  end

  create_table "users", force: :cascade do |t|
    t.citext "email", null: false
    t.string "password_digest", null: false
    t.string "first_name", limit: 100, null: false
    t.string "last_name", limit: 100, null: false
    t.string "phone", limit: 32
    t.date "birth_date"
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
    t.check_constraint "platform_role::text = ANY (ARRAY['user'::character varying::text, 'moderator'::character varying::text])", name: "chk_users_platform_role"
    t.check_constraint "preferred_locale::text = ANY (ARRAY['uk'::character varying::text, 'en'::character varying::text])", name: "chk_users_preferred_locale"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "answers", "questions", on_delete: :cascade
  add_foreign_key "answers", "users", column: "author_id", on_delete: :cascade
  add_foreign_key "appeals", "users", column: "reviewed_by_id", on_delete: :nullify
  add_foreign_key "appeals", "users", column: "submitted_by_id", on_delete: :cascade
  add_foreign_key "company_members", "organizations", on_delete: :cascade
  add_foreign_key "company_members", "roles", on_delete: :restrict
  add_foreign_key "company_members", "users", column: "added_by_id", on_delete: :nullify
  add_foreign_key "company_members", "users", on_delete: :cascade
  add_foreign_key "event_media", "events", on_delete: :cascade
  add_foreign_key "event_reviews", "events", on_delete: :cascade
  add_foreign_key "event_reviews", "users", on_delete: :cascade
  add_foreign_key "event_revisions", "events", on_delete: :cascade
  add_foreign_key "event_revisions", "users", column: "reviewed_by_id", on_delete: :nullify
  add_foreign_key "event_revisions", "users", column: "submitted_by_id", on_delete: :restrict
  add_foreign_key "event_status_histories", "events", on_delete: :cascade
  add_foreign_key "event_status_histories", "users", column: "changed_by_id", on_delete: :nullify
  add_foreign_key "event_translations", "events", on_delete: :cascade
  add_foreign_key "events", "categories", on_delete: :restrict
  add_foreign_key "events", "organizations", on_delete: :restrict
  add_foreign_key "events", "users", column: "created_by_id", on_delete: :restrict
  add_foreign_key "events", "users", column: "reviewed_by_id", on_delete: :nullify
  add_foreign_key "moderation_logs", "users", column: "moderator_id", on_delete: :nullify
  add_foreign_key "order_items", "orders"
  add_foreign_key "orders", "events"
  add_foreign_key "orders", "users"
  add_foreign_key "organization_reviews", "organizations", on_delete: :cascade
  add_foreign_key "organization_reviews", "users", on_delete: :cascade
  add_foreign_key "organization_translations", "organizations", on_delete: :cascade
  add_foreign_key "organizations", "users", column: "approved_by_id", on_delete: :nullify
  add_foreign_key "organizations", "users", column: "blocked_by_id", on_delete: :nullify
  add_foreign_key "questions", "users", column: "author_id", on_delete: :cascade
  add_foreign_key "ticket_types", "events", on_delete: :cascade
  add_foreign_key "tickets", "events"
  add_foreign_key "tickets", "order_items"
  add_foreign_key "tickets", "users"
  add_foreign_key "tickets", "users", column: "checked_in_by_id", on_delete: :nullify
  add_foreign_key "users", "users", column: "blocked_by_id", on_delete: :nullify
end
