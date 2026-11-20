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

ActiveRecord::Schema[8.1].define(version: 2026_11_19_030000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "account_settings", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "appearance", default: "light", null: false
    t.boolean "show_online_status", default: true, null: false
    t.boolean "allow_contact_requests", default: true, null: false
    t.string "learning_format", default: "mixed", null: false
    t.integer "weekly_learning_minutes", default: 120, null: false
    t.string "session_preference", default: "online", null: false
    t.string "mentorship_focus", limit: 200, default: "", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_account_settings_on_user_id", unique: true
  end

  create_table "achievement_awards", force: :cascade do |t|
    t.bigint "achievement_definition_id", null: false
    t.bigint "user_id", null: false
    t.bigint "platform_program_id"
    t.bigint "issuer_id"
    t.string "issuer_name", null: false
    t.string "identifier", null: false
    t.string "title", null: false
    t.text "description"
    t.string "kind", null: false
    t.string "icon", null: false
    t.string "color", null: false
    t.datetime "awarded_at", null: false
    t.datetime "revoked_at"
    t.text "revocation_reason"
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "criteria_snapshot"
    t.string "cohort_label"
    t.decimal "final_score", precision: 5, scale: 2
    t.index ["achievement_definition_id", "user_id"], name: "one_active_achievement_per_learner", unique: true, where: "(revoked_at IS NULL)"
    t.index ["achievement_definition_id"], name: "index_achievement_awards_on_achievement_definition_id"
    t.index ["awarded_at"], name: "index_achievement_awards_on_awarded_at"
    t.index ["identifier"], name: "index_achievement_awards_on_identifier", unique: true
    t.index ["issuer_id"], name: "index_achievement_awards_on_issuer_id"
    t.index ["platform_program_id"], name: "index_achievement_awards_on_platform_program_id"
    t.index ["user_id"], name: "index_achievement_awards_on_user_id"
  end

  create_table "achievement_criteria", force: :cascade do |t|
    t.bigint "achievement_award_id", null: false
    t.string "title", null: false
    t.string "category", default: "other", null: false
    t.integer "completed_units", default: 0, null: false
    t.integer "target_units", default: 1, null: false
    t.datetime "completed_at"
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["achievement_award_id"], name: "index_achievement_criteria_on_achievement_award_id"
  end

  create_table "achievement_definitions", force: :cascade do |t|
    t.string "title", null: false
    t.text "description"
    t.text "criteria"
    t.string "kind", null: false
    t.string "icon", default: "trophy", null: false
    t.string "color", default: "purple", null: false
    t.boolean "is_active", default: true, null: false
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "achievement_goal_links", force: :cascade do |t|
    t.string "achievement_key", limit: 150, null: false
    t.bigint "mentee_goal_id", null: false
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["achievement_key", "mentee_goal_id"], name: "unique_achievement_goal_link", unique: true
    t.index ["mentee_goal_id"], name: "index_achievement_goal_links_on_mentee_goal_id"
  end

  create_table "achievement_notes", force: :cascade do |t|
    t.string "achievement_key", limit: 150, null: false
    t.bigint "author_id"
    t.string "author_name", null: false
    t.text "body", null: false
    t.boolean "is_active", default: true, null: false
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["achievement_key", "created_at"], name: "index_achievement_notes_on_achievement_key_and_created_at"
    t.index ["author_id"], name: "index_achievement_notes_on_author_id"
  end

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

  create_table "administration_audits", force: :cascade do |t|
    t.bigint "actor_id"
    t.string "actor_name", null: false
    t.string "action", null: false
    t.string "target_type", null: false
    t.bigint "target_id"
    t.jsonb "changeset", default: {}, null: false
    t.datetime "created_at", null: false
    t.index ["actor_id"], name: "index_administration_audits_on_actor_id"
  end

  create_table "availability_slots", id: :serial, force: :cascade do |t|
    t.integer "mentor_id", null: false
    t.datetime "starts_at", null: false
    t.datetime "ends_at", null: false
    t.boolean "is_booked", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["mentor_id", "starts_at"], name: "index_availability_slots_on_mentor_id_and_starts_at", unique: true
  end

  create_table "booking_participants", force: :cascade do |t|
    t.bigint "booking_id", null: false
    t.bigint "user_id", null: false
    t.boolean "attended"
    t.datetime "recorded_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["booking_id", "user_id"], name: "index_booking_participants_on_booking_id_and_user_id", unique: true
    t.index ["booking_id"], name: "index_booking_participants_on_booking_id"
    t.index ["user_id"], name: "index_booking_participants_on_user_id"
  end

  create_table "bookings", id: :serial, force: :cascade do |t|
    t.integer "service_id", null: false
    t.integer "mentee_id", null: false
    t.integer "mentor_id", null: false
    t.string "status", limit: 20, default: "pending", null: false
    t.datetime "scheduled_at", null: false
    t.integer "duration", null: false
    t.decimal "total_price", precision: 10, scale: 2, null: false
    t.string "payment_status", limit: 20, default: "pending", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "platform_program_id"
    t.bigint "session_category_id"
    t.string "session_title", limit: 100
    t.text "session_description"
    t.string "format", default: "online", null: false
    t.string "location", limit: 500
    t.string "meeting_url", limit: 2048
    t.jsonb "objectives", default: [], null: false
    t.jsonb "session_tags", default: [], null: false
    t.datetime "registration_opens_at"
    t.datetime "registration_closes_at"
    t.datetime "feedback_opens_at"
    t.datetime "feedback_closes_at"
    t.index ["mentee_id"], name: "index_bookings_on_mentee_id"
    t.index ["mentor_id"], name: "index_bookings_on_mentor_id"
    t.index ["platform_program_id"], name: "index_bookings_on_platform_program_id"
    t.index ["scheduled_at"], name: "index_bookings_on_scheduled_at"
    t.index ["service_id"], name: "index_bookings_on_service_id"
    t.index ["session_category_id"], name: "index_bookings_on_session_category_id"
    t.index ["status"], name: "index_bookings_on_status"
  end

  create_table "categories", id: :serial, force: :cascade do |t|
    t.string "name", limit: 100, null: false
    t.boolean "is_active", default: true
    t.datetime "created_at", default: -> { "CURRENT_TIMESTAMP" }
    t.datetime "updated_at"
    t.string "slug", limit: 100, null: false
    t.text "description"
    t.string "icon_path", limit: 255
    t.jsonb "topics", default: []
    t.integer "position", default: 0, null: false
    t.integer "parent_id"
    t.string "image_alt", limit: 150
    t.index ["is_active"], name: "index_categories_on_is_active"
    t.index ["name"], name: "index_categories_on_name", unique: true
    t.index ["parent_id"], name: "index_categories_on_parent_id"
    t.index ["position"], name: "index_categories_on_position"
    t.index ["slug"], name: "index_categories_on_slug", unique: true
  end

  create_table "chat_messages", force: :cascade do |t|
    t.bigint "conversation_id", null: false
    t.integer "sender_id", null: false
    t.text "content"
    t.string "client_nonce", limit: 100
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["conversation_id", "sender_id", "client_nonce"], name: "index_chat_messages_on_client_nonce", unique: true
    t.index ["conversation_id"], name: "index_chat_messages_on_conversation_id"
    t.index ["sender_id"], name: "index_chat_messages_on_sender_id"
  end

  create_table "conversation_memberships", force: :cascade do |t|
    t.bigint "conversation_id", null: false
    t.integer "user_id", null: false
    t.bigint "last_read_message_id", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "starred", default: false, null: false
    t.boolean "archived", default: false, null: false
    t.boolean "muted", default: false, null: false
    t.datetime "deleted_at"
    t.bigint "deleted_through_message_id", default: 0, null: false
    t.integer "lock_version", default: 0, null: false
    t.index ["conversation_id", "user_id"], name: "index_memberships_on_conversation_and_user", unique: true
    t.index ["conversation_id"], name: "index_conversation_memberships_on_conversation_id"
    t.index ["user_id"], name: "index_conversation_memberships_on_user_id"
  end

  create_table "conversations", force: :cascade do |t|
    t.integer "creator_id", null: false
    t.string "kind", default: "direct", null: false
    t.string "title", limit: 150
    t.string "direct_key"
    t.datetime "last_message_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "platform_program_id"
    t.string "cohort_label", limit: 150
    t.index ["creator_id"], name: "index_conversations_on_creator_id"
    t.index ["direct_key"], name: "index_conversations_on_direct_key", unique: true
    t.index ["platform_program_id"], name: "index_conversations_on_platform_program_id"
  end

  create_table "event_agenda_items", force: :cascade do |t|
    t.bigint "event_id", null: false
    t.string "title", null: false
    t.text "description"
    t.datetime "starts_at", null: false
    t.datetime "ends_at", null: false
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_event_agenda_items_on_event_id"
  end

  create_table "event_feedbacks", force: :cascade do |t|
    t.bigint "event_id", null: false
    t.bigint "user_id", null: false
    t.integer "rating", null: false
    t.text "comment"
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id", "user_id"], name: "index_event_feedbacks_on_event_id_and_user_id", unique: true
    t.index ["event_id"], name: "index_event_feedbacks_on_event_id"
    t.index ["user_id"], name: "index_event_feedbacks_on_user_id"
  end

  create_table "event_materials", force: :cascade do |t|
    t.bigint "event_id", null: false
    t.string "title", null: false
    t.text "description"
    t.string "url"
    t.boolean "is_active", default: true, null: false
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_event_materials_on_event_id"
  end

  create_table "event_registrations", force: :cascade do |t|
    t.bigint "event_id", null: false
    t.integer "user_id", null: false
    t.string "status", default: "registered", null: false
    t.datetime "attended_at"
    t.integer "reminder_minutes", default: 15, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "lock_version", default: 0, null: false
    t.string "attendance_status", default: "unrecorded", null: false
    t.index ["event_id", "user_id"], name: "index_event_registrations_on_event_id_and_user_id", unique: true
    t.index ["event_id"], name: "index_event_registrations_on_event_id"
    t.index ["user_id"], name: "index_event_registrations_on_user_id"
  end

  create_table "event_speakers", force: :cascade do |t|
    t.bigint "event_id", null: false
    t.string "name", null: false
    t.string "title"
    t.text "bio"
    t.string "avatar_url"
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "role", default: "Speaker", null: false
    t.index ["event_id"], name: "index_event_speakers_on_event_id"
  end

  create_table "event_suggestions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "title", limit: 160, null: false
    t.text "description", null: false
    t.string "category", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_event_suggestions_on_user_id"
  end

  create_table "events", force: :cascade do |t|
    t.integer "organizer_id", null: false
    t.string "title", limit: 160, null: false
    t.text "description", null: false
    t.string "category", null: false
    t.datetime "starts_at", null: false
    t.datetime "ends_at", null: false
    t.string "location", limit: 200, null: false
    t.string "meeting_url", limit: 2048
    t.integer "capacity"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "platform_program_id"
    t.string "event_type", default: "other", null: false
    t.string "status", default: "published", null: false
    t.string "format", default: "on_site", null: false
    t.integer "lock_version", default: 0, null: false
    t.datetime "deleted_at"
    t.jsonb "target_audiences", default: [], null: false
    t.boolean "public_featured", default: false, null: false
    t.string "public_recording_url", limit: 2048
    t.jsonb "public_details", default: {}, null: false
    t.index ["deleted_at"], name: "index_events_on_deleted_at"
    t.index ["organizer_id"], name: "index_events_on_organizer_id"
    t.index ["platform_program_id"], name: "index_events_on_platform_program_id"
    t.index ["starts_at"], name: "index_events_on_starts_at"
    t.index ["status", "starts_at"], name: "index_events_on_status_and_starts_at"
  end

  create_table "goal_attachments", force: :cascade do |t|
    t.bigint "mentee_goal_id"
    t.bigint "mentor_goal_id"
    t.bigint "program_goal_id"
    t.bigint "author_id"
    t.string "author_name", null: false
    t.integer "lock_version", default: 0, null: false
    t.boolean "is_active", default: true, null: false
    t.string "title", null: false
    t.string "url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["author_id"], name: "index_goal_attachments_on_author_id"
    t.index ["mentee_goal_id"], name: "index_goal_attachments_on_mentee_goal_id"
    t.index ["mentor_goal_id"], name: "index_goal_attachments_on_mentor_goal_id"
    t.index ["program_goal_id"], name: "index_goal_attachments_on_program_goal_id"
    t.check_constraint "num_nonnulls(mentee_goal_id, mentor_goal_id, program_goal_id) = 1", name: "goal_attachments_one_goal"
  end

  create_table "goal_milestones", force: :cascade do |t|
    t.bigint "mentee_goal_id"
    t.string "title", limit: 200, null: false
    t.date "target_date"
    t.boolean "completed", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "mentor_goal_id"
    t.bigint "program_goal_id"
    t.integer "lock_version", default: 0, null: false
    t.index ["mentee_goal_id"], name: "index_goal_milestones_on_mentee_goal_id"
    t.index ["mentor_goal_id"], name: "index_goal_milestones_on_mentor_goal_id"
    t.index ["program_goal_id"], name: "index_goal_milestones_on_program_goal_id"
    t.check_constraint "num_nonnulls(mentee_goal_id, mentor_goal_id, program_goal_id) = 1", name: "goal_milestones_one_goal"
  end

  create_table "goal_progress_events", force: :cascade do |t|
    t.bigint "mentee_goal_id"
    t.integer "progress", null: false
    t.string "note", limit: 250, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "mentor_goal_id"
    t.bigint "program_goal_id"
    t.string "actor_name"
    t.index ["mentee_goal_id", "created_at"], name: "index_goal_progress_events_on_mentee_goal_id_and_created_at"
    t.index ["mentee_goal_id"], name: "index_goal_progress_events_on_mentee_goal_id"
    t.index ["mentor_goal_id", "created_at"], name: "index_goal_progress_events_on_mentor_goal_id_and_created_at"
    t.index ["mentor_goal_id"], name: "index_goal_progress_events_on_mentor_goal_id"
    t.index ["program_goal_id", "created_at"], name: "index_goal_progress_events_on_program_goal_id_and_created_at"
    t.index ["program_goal_id"], name: "index_goal_progress_events_on_program_goal_id"
    t.check_constraint "num_nonnulls(mentee_goal_id, mentor_goal_id, program_goal_id) = 1", name: "goal_progress_events_one_goal"
  end

  create_table "goal_updates", force: :cascade do |t|
    t.bigint "mentee_goal_id"
    t.bigint "mentor_goal_id"
    t.bigint "program_goal_id"
    t.bigint "author_id"
    t.string "author_name", null: false
    t.integer "lock_version", default: 0, null: false
    t.boolean "is_active", default: true, null: false
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["author_id"], name: "index_goal_updates_on_author_id"
    t.index ["mentee_goal_id"], name: "index_goal_updates_on_mentee_goal_id"
    t.index ["mentor_goal_id"], name: "index_goal_updates_on_mentor_goal_id"
    t.index ["program_goal_id"], name: "index_goal_updates_on_program_goal_id"
    t.check_constraint "num_nonnulls(mentee_goal_id, mentor_goal_id, program_goal_id) = 1", name: "goal_updates_one_goal"
  end

  create_table "integration_logs", force: :cascade do |t|
    t.string "provider_key", null: false
    t.string "action", null: false
    t.string "outcome", null: false
    t.string "message", null: false
    t.integer "http_status"
    t.bigint "actor_id"
    t.string "actor_name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["actor_id"], name: "index_integration_logs_on_actor_id"
    t.index ["provider_key", "created_at"], name: "index_integration_logs_on_provider_key_and_created_at"
  end

  create_table "learning_certificates", force: :cascade do |t|
    t.bigint "learning_enrollment_id", null: false
    t.string "identifier", null: false
    t.datetime "issued_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["identifier"], name: "index_learning_certificates_on_identifier", unique: true
    t.index ["learning_enrollment_id"], name: "index_learning_certificates_on_learning_enrollment_id", unique: true
  end

  create_table "learning_enrollments", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "course_key", null: false
    t.jsonb "completed_lesson_ids", default: [], null: false
    t.jsonb "activity_dates", default: [], null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "course_key"], name: "index_learning_enrollments_on_user_id_and_course_key", unique: true
    t.index ["user_id"], name: "index_learning_enrollments_on_user_id"
  end

  create_table "learning_lesson_completions", force: :cascade do |t|
    t.bigint "learning_enrollment_id", null: false
    t.string "lesson_key", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["learning_enrollment_id", "lesson_key"], name: "index_lesson_completions_on_enrollment_and_lesson", unique: true
    t.index ["learning_enrollment_id"], name: "index_learning_lesson_completions_on_learning_enrollment_id"
  end

  create_table "mentee_goals", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "title", limit: 200, null: false
    t.boolean "completed", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "description"
    t.integer "progress", default: 0, null: false
    t.date "target_date"
    t.string "icon", default: "target", null: false
    t.bigint "platform_program_id"
    t.string "category", default: "learning", null: false
    t.string "tracking_status", default: "in_progress", null: false
    t.integer "lock_version", default: 0, null: false
    t.datetime "archived_at"
    t.string "priority", default: "medium", null: false
    t.datetime "completed_at"
    t.index ["platform_program_id"], name: "index_mentee_goals_on_platform_program_id"
    t.index ["user_id"], name: "index_mentee_goals_on_user_id"
    t.check_constraint "progress >= 0 AND progress <= 100", name: "mentee_goal_progress_range"
  end

  create_table "mentee_profiles", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "school", limit: 150
    t.string "grade", limit: 50
    t.string "location", limit: 150
    t.text "bio"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "vision"
    t.string "management_status", default: "active", null: false
    t.integer "lock_version", default: 0, null: false
    t.bigint "assigned_mentor_id"
    t.bigint "primary_program_id"
    t.string "education", limit: 200
    t.jsonb "interests", default: [], null: false
    t.index ["assigned_mentor_id"], name: "index_mentee_profiles_on_assigned_mentor_id"
    t.index ["primary_program_id"], name: "index_mentee_profiles_on_primary_program_id"
    t.index ["user_id"], name: "index_mentee_profiles_on_user_id", unique: true
    t.check_constraint "management_status::text = ANY (ARRAY['active'::character varying::text, 'inactive'::character varying::text, 'graduated'::character varying::text, 'suspended'::character varying::text])", name: "mentee_management_status"
  end

  create_table "mentor_applications", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "status", default: "draft", null: false
    t.string "headline", default: "", null: false
    t.text "background", default: "", null: false
    t.text "expertise", default: "", null: false
    t.integer "years_of_experience", default: 0, null: false
    t.text "motivation", default: "", null: false
    t.text "references_text", default: "", null: false
    t.boolean "conduct_accepted", default: false, null: false
    t.boolean "safeguarding_accepted", default: false, null: false
    t.string "policy_version"
    t.datetime "submitted_at"
    t.datetime "consented_at"
    t.bigint "reviewed_by_id"
    t.datetime "reviewed_at"
    t.text "review_note", default: "", null: false
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "form_version", default: 1, null: false
    t.string "full_name", default: "", null: false
    t.string "contact_email", default: "", null: false
    t.string "phone_number", default: "", null: false
    t.string "location", default: "", null: false
    t.string "gender", default: "", null: false
    t.date "date_of_birth"
    t.string "highest_qualification", default: "", null: false
    t.string "organization", default: "", null: false
    t.string "experience_range", default: "", null: false
    t.jsonb "expertise_tags", default: [], null: false
    t.jsonb "target_learners", default: [], null: false
    t.boolean "terms_accepted", default: false, null: false
    t.index ["reviewed_by_id"], name: "index_mentor_applications_on_reviewed_by_id"
    t.index ["status", "submitted_at"], name: "index_mentor_applications_on_status_and_submitted_at"
    t.index ["user_id"], name: "index_mentor_applications_on_user_id", unique: true
  end

  create_table "mentor_goals", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "title", limit: 200, null: false
    t.boolean "completed", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "platform_program_id"
    t.string "category", default: "learning", null: false
    t.string "tracking_status", default: "in_progress", null: false
    t.integer "lock_version", default: 0, null: false
    t.datetime "archived_at"
    t.text "description"
    t.integer "progress", default: 0, null: false
    t.date "target_date"
    t.string "icon", default: "target", null: false
    t.string "priority", default: "medium", null: false
    t.datetime "completed_at"
    t.index ["platform_program_id"], name: "index_mentor_goals_on_platform_program_id"
    t.index ["user_id"], name: "index_mentor_goals_on_user_id"
    t.check_constraint "progress >= 0 AND progress <= 100", name: "mentor_goals_progress_range"
  end

  create_table "mentor_profiles", id: :serial, force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "title", limit: 150
    t.integer "years_of_experience", default: 0, null: false
    t.jsonb "languages", default: [], null: false
    t.jsonb "education", default: [], null: false
    t.jsonb "experience", default: [], null: false
    t.decimal "hourly_rate", precision: 10, scale: 2
    t.boolean "accepting_bookings", default: true, null: false
    t.boolean "is_verified", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "bio"
    t.string "currency", limit: 3, default: "USD", null: false
    t.string "timezone", limit: 64, default: "UTC", null: false
    t.boolean "is_published", default: true, null: false
    t.index ["user_id"], name: "index_mentor_profiles_on_user_id", unique: true
  end

  create_table "mentor_skills", id: :serial, force: :cascade do |t|
    t.integer "mentor_profile_id", null: false
    t.integer "skill_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["mentor_profile_id", "skill_id"], name: "index_mentor_skills_on_mentor_profile_id_and_skill_id", unique: true
    t.index ["skill_id"], name: "index_mentor_skills_on_skill_id"
  end

  create_table "mentorship_resources", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "title", limit: 200, null: false
    t.string "url", limit: 2000, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_mentorship_resources_on_user_id"
  end

  create_table "message_broadcasts", force: :cascade do |t|
    t.bigint "sender_id", null: false
    t.string "client_nonce", limit: 100, null: false
    t.string "title", limit: 150
    t.text "content", null: false
    t.jsonb "recipient_ids", default: [], null: false
    t.jsonb "conversation_ids", default: [], null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["sender_id", "client_nonce"], name: "index_message_broadcasts_on_sender_id_and_client_nonce", unique: true
    t.index ["sender_id"], name: "index_message_broadcasts_on_sender_id"
  end

  create_table "messaging_blocks", force: :cascade do |t|
    t.bigint "blocker_id", null: false
    t.bigint "blocked_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["blocked_id"], name: "index_messaging_blocks_on_blocked_id"
    t.index ["blocker_id", "blocked_id"], name: "index_messaging_blocks_on_blocker_id_and_blocked_id", unique: true
    t.index ["blocker_id"], name: "index_messaging_blocks_on_blocker_id"
  end

  create_table "messaging_preferences", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.boolean "notify_messages", default: true, null: false
    t.boolean "send_read_receipts", default: true, null: false
    t.boolean "enter_to_send", default: true, null: false
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_messaging_preferences_on_user_id", unique: true
  end

  create_table "notification_preferences", force: :cascade do |t|
    t.integer "user_id", null: false
    t.boolean "mentorship", default: true, null: false
    t.boolean "learning", default: true, null: false
    t.boolean "events", default: true, null: false
    t.boolean "goals", default: true, null: false
    t.boolean "platform", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_notification_preferences_on_user_id", unique: true
  end

  create_table "notifications", id: :serial, force: :cascade do |t|
    t.string "title"
    t.string "message"
    t.boolean "read", default: false
    t.integer "user_id"
    t.string "category", default: "system", null: false
    t.string "topic", default: "platform", null: false
    t.string "icon", default: "bell", null: false
    t.string "href", default: "/notifications", null: false
    t.string "source_key"
    t.datetime "created_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.datetime "updated_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.index ["user_id", "read", "created_at"], name: "index_notifications_on_user_id_and_read_and_created_at"
    t.index ["user_id", "source_key"], name: "index_notifications_on_user_id_and_source_key", unique: true
    t.index ["user_id"], name: "index_notifications_on_user_id"
  end

  create_table "platform_integrations", force: :cascade do |t|
    t.string "provider_key", null: false
    t.string "environment", default: "live", null: false
    t.text "encrypted_credentials"
    t.boolean "paused", default: false, null: false
    t.boolean "verified", default: false, null: false
    t.datetime "last_attempt_at"
    t.datetime "last_checked_at"
    t.string "last_message"
    t.integer "last_http_status"
    t.bigint "updated_by_id"
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["provider_key"], name: "index_platform_integrations_on_provider_key", unique: true
    t.index ["updated_by_id"], name: "index_platform_integrations_on_updated_by_id"
  end

  create_table "platform_programs", force: :cascade do |t|
    t.string "title", limit: 150, null: false
    t.text "description", default: "", null: false
    t.string "status", default: "active", null: false
    t.date "starts_on"
    t.date "ends_on"
    t.bigint "created_by_id"
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "category_id"
    t.string "icon", default: "graduation", null: false
    t.integer "capacity"
    t.jsonb "objectives", default: [], null: false
    t.string "target_audience", limit: 500
    t.string "delivery_mode", default: "hybrid", null: false
    t.date "registration_starts_on"
    t.date "registration_ends_on"
    t.date "evaluation_starts_on"
    t.date "evaluation_ends_on"
    t.jsonb "audience_stages", default: [], null: false
    t.jsonb "themes", default: [], null: false
    t.boolean "featured", default: false, null: false
    t.jsonb "public_details", default: {}, null: false
    t.index ["category_id"], name: "index_platform_programs_on_category_id"
    t.index ["created_by_id"], name: "index_platform_programs_on_created_by_id"
    t.check_constraint "capacity IS NULL OR capacity > 0", name: "program_positive_capacity"
  end

  create_table "platform_resource_accesses", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "platform_resource_id", null: false
    t.string "kind", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["platform_resource_id"], name: "index_platform_resource_accesses_on_platform_resource_id"
    t.index ["user_id", "created_at"], name: "index_platform_resource_accesses_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_platform_resource_accesses_on_user_id"
    t.check_constraint "kind::text = ANY (ARRAY['download'::character varying, 'link'::character varying, 'view'::character varying]::text[])", name: "resource_access_kind"
  end

  create_table "platform_resources", force: :cascade do |t|
    t.string "title", limit: 200, null: false
    t.text "description", default: "", null: false
    t.string "url", limit: 2048
    t.boolean "published", default: true, null: false
    t.bigint "platform_program_id"
    t.bigint "created_by_id"
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "resource_type", default: "link", null: false
    t.boolean "archived", default: false, null: false
    t.jsonb "tags", default: [], null: false
    t.string "language", default: "en", null: false
    t.string "target_audience", limit: 500
    t.string "module_name", limit: 200
    t.integer "position"
    t.boolean "required", default: false, null: false
    t.string "awards", limit: 500
    t.integer "duration_seconds"
    t.string "visibility", default: "platform", null: false
    t.datetime "published_at"
    t.datetime "deleted_at"
    t.jsonb "library_details", default: {}, null: false
    t.jsonb "page_details", default: {}, null: false
    t.index ["created_by_id"], name: "index_platform_resources_on_created_by_id"
    t.index ["platform_program_id"], name: "index_platform_resources_on_platform_program_id"
    t.index ["resource_type", "published", "archived"], name: "idx_on_resource_type_published_archived_a37713bc0b"
  end

  create_table "profiles", id: :serial, force: :cascade do |t|
    t.string "phone_number", limit: 20, null: false
    t.string "gender", limit: 10, null: false
    t.date "birth_date", null: false
    t.string "address", limit: 255, null: false
    t.string "city", limit: 100, null: false
    t.string "country", limit: 100, null: false
    t.string "profile_picture", limit: 255
    t.text "bio"
    t.integer "user_id", null: false
    t.datetime "created_at", default: -> { "CURRENT_TIMESTAMP" }
    t.datetime "updated_at"
    t.index ["phone_number"], name: "index_profiles_on_phone_number", unique: true
    t.index ["user_id"], name: "index_profiles_on_user_id", unique: true
  end

  create_table "program_goals", force: :cascade do |t|
    t.bigint "platform_program_id", null: false
    t.string "title", limit: 200, null: false
    t.text "description"
    t.integer "progress", default: 0, null: false
    t.boolean "completed", default: false, null: false
    t.date "target_date"
    t.string "icon", default: "target", null: false
    t.string "category", default: "learning", null: false
    t.string "tracking_status", default: "in_progress", null: false
    t.integer "lock_version", default: 0, null: false
    t.datetime "archived_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "priority", default: "medium", null: false
    t.datetime "completed_at"
    t.index ["platform_program_id"], name: "index_program_goals_on_platform_program_id"
    t.check_constraint "progress >= 0 AND progress <= 100", name: "program_goals_progress_range"
  end

  create_table "program_memberships", force: :cascade do |t|
    t.bigint "platform_program_id", null: false
    t.bigint "user_id", null: false
    t.boolean "is_active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "progress", default: 0, null: false
    t.datetime "completed_at"
    t.integer "lock_version", default: 0, null: false
    t.index ["platform_program_id", "user_id"], name: "index_program_memberships_on_platform_program_id_and_user_id", unique: true
    t.index ["platform_program_id"], name: "index_program_memberships_on_platform_program_id"
    t.index ["user_id"], name: "index_program_memberships_on_user_id"
    t.check_constraint "progress >= 0 AND progress <= 100", name: "program_membership_progress"
  end

  create_table "program_mentor_assignments", force: :cascade do |t|
    t.bigint "platform_program_id", null: false
    t.bigint "user_id", null: false
    t.boolean "is_active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["platform_program_id", "user_id"], name: "index_program_mentors_unique", unique: true
    t.index ["platform_program_id"], name: "index_program_mentor_assignments_on_platform_program_id"
    t.index ["user_id"], name: "index_program_mentor_assignments_on_user_id"
  end

  create_table "public_inquiries", force: :cascade do |t|
    t.string "reference", null: false
    t.string "name", limit: 150, null: false
    t.string "email", limit: 254, null: false
    t.string "subject", limit: 150, null: false
    t.string "category", null: false
    t.text "message", null: false
    t.string "ip_digest", null: false
    t.boolean "reviewed", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "event_details", default: {}, null: false
    t.string "submission_key"
    t.integer "requester_id"
    t.integer "reviewer_id"
    t.bigint "event_id"
    t.string "status", default: "pending", null: false
    t.text "review_note", default: "", null: false
    t.datetime "reviewed_at"
    t.integer "lock_version", default: 0, null: false
    t.jsonb "partnership_details", default: {}, null: false
    t.jsonb "program_details", default: {}, null: false
    t.index ["event_id"], name: "index_public_inquiries_on_event_id", unique: true
    t.index ["ip_digest", "created_at"], name: "index_public_inquiries_on_ip_digest_and_created_at"
    t.index ["reference"], name: "index_public_inquiries_on_reference", unique: true
    t.index ["requester_id"], name: "index_public_inquiries_on_requester_id"
    t.index ["reviewer_id"], name: "index_public_inquiries_on_reviewer_id"
    t.index ["submission_key"], name: "index_public_inquiries_on_submission_key", unique: true
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying::text, 'approved'::character varying::text, 'rejected'::character varying::text, 'changes_requested'::character varying::text])", name: "public_inquiries_status"
  end

  create_table "refresh_tokens", id: :serial, force: :cascade do |t|
    t.text "token", null: false
    t.integer "user_id", null: false
    t.datetime "created_at", default: -> { "CURRENT_TIMESTAMP" }
    t.datetime "expires_at", null: false
    t.boolean "revoked", default: false
    t.index ["token"], name: "index_refresh_tokens_on_token", unique: true
  end

  create_table "report_runs", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "report_schedule_id"
    t.string "name", null: false
    t.string "kind", null: false
    t.jsonb "filters", default: {}, null: false
    t.jsonb "columns", default: [], null: false
    t.string "status", default: "running", null: false
    t.integer "row_count"
    t.string "error", limit: 500
    t.datetime "scheduled_for"
    t.datetime "finished_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["report_schedule_id", "scheduled_for"], name: "unique_scheduled_report_run", unique: true
    t.index ["report_schedule_id"], name: "index_report_runs_on_report_schedule_id"
    t.index ["user_id"], name: "index_report_runs_on_user_id"
  end

  create_table "report_schedules", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "name", limit: 150, null: false
    t.string "kind", null: false
    t.jsonb "columns", default: [], null: false
    t.jsonb "filters", default: {"period"=>"30"}, null: false
    t.integer "lock_version", default: 0, null: false
    t.string "frequency", default: "weekly", null: false
    t.string "timezone", null: false
    t.integer "hour", default: 8, null: false
    t.integer "minute", default: 0, null: false
    t.integer "weekday", default: 1, null: false
    t.integer "month_day", default: 1, null: false
    t.boolean "active", default: true, null: false
    t.datetime "next_run_at", null: false
    t.datetime "last_run_at"
    t.string "last_status"
    t.string "last_error", limit: 500
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active", "next_run_at"], name: "index_report_schedules_on_active_and_next_run_at"
    t.index ["user_id"], name: "index_report_schedules_on_user_id"
  end

  create_table "resource_bookmarks", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "platform_resource_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["platform_resource_id"], name: "index_resource_bookmarks_on_platform_resource_id"
    t.index ["user_id", "platform_resource_id"], name: "index_resource_bookmarks_on_user_id_and_platform_resource_id", unique: true
    t.index ["user_id"], name: "index_resource_bookmarks_on_user_id"
  end

  create_table "resource_comments", force: :cascade do |t|
    t.bigint "platform_resource_id", null: false
    t.bigint "user_id", null: false
    t.string "display_name", null: false
    t.text "body", null: false
    t.string "status", default: "pending", null: false
    t.string "submission_key", null: false
    t.integer "lock_version", default: 0, null: false
    t.datetime "reviewed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["platform_resource_id", "status", "created_at"], name: "index_resource_comment_publication"
    t.index ["platform_resource_id"], name: "index_resource_comments_on_platform_resource_id"
    t.index ["user_id", "platform_resource_id", "submission_key"], name: "index_resource_comment_submissions", unique: true
    t.index ["user_id"], name: "index_resource_comments_on_user_id"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying, 'approved'::character varying, 'rejected'::character varying]::text[])", name: "resource_comment_status"
  end

  create_table "resource_contents", force: :cascade do |t|
    t.bigint "platform_resource_id", null: false
    t.string "title", limit: 200, null: false
    t.text "body"
    t.string "url", limit: 2048
    t.integer "position", default: 1, null: false
    t.integer "start_seconds"
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "public_listing", default: false, null: false
    t.index ["platform_resource_id"], name: "index_resource_contents_on_platform_resource_id"
  end

  create_table "resource_feedbacks", force: :cascade do |t|
    t.bigint "platform_resource_id", null: false
    t.bigint "user_id", null: false
    t.integer "rating", null: false
    t.text "comment", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["platform_resource_id", "user_id"], name: "index_resource_feedbacks_on_platform_resource_id_and_user_id", unique: true
    t.index ["platform_resource_id"], name: "index_resource_feedbacks_on_platform_resource_id"
    t.index ["user_id"], name: "index_resource_feedbacks_on_user_id"
    t.check_constraint "rating >= 1 AND rating <= 5", name: "resource_feedback_rating_range"
  end

  create_table "resource_program_shares", force: :cascade do |t|
    t.bigint "platform_resource_id", null: false
    t.bigint "platform_program_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["platform_program_id"], name: "index_resource_program_shares_on_platform_program_id"
    t.index ["platform_resource_id", "platform_program_id"], name: "resource_program_share_unique", unique: true
    t.index ["platform_resource_id"], name: "index_resource_program_shares_on_platform_resource_id"
  end

  create_table "resource_progresses", force: :cascade do |t|
    t.bigint "platform_resource_id", null: false
    t.bigint "user_id", null: false
    t.integer "percent", default: 0, null: false
    t.datetime "completed_at"
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["platform_resource_id", "user_id"], name: "index_resource_progresses_on_platform_resource_id_and_user_id", unique: true
    t.index ["platform_resource_id"], name: "index_resource_progresses_on_platform_resource_id"
    t.index ["user_id"], name: "index_resource_progresses_on_user_id"
    t.check_constraint "percent >= 0 AND percent <= 100", name: "resource_progress_range"
  end

  create_table "resource_versions", force: :cascade do |t|
    t.bigint "platform_resource_id", null: false
    t.bigint "actor_id"
    t.string "actor_name", null: false
    t.integer "number", null: false
    t.jsonb "snapshot", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["actor_id"], name: "index_resource_versions_on_actor_id"
    t.index ["platform_resource_id", "number"], name: "index_resource_versions_on_platform_resource_id_and_number", unique: true
    t.index ["platform_resource_id"], name: "index_resource_versions_on_platform_resource_id"
  end

  create_table "reviews", id: :serial, force: :cascade do |t|
    t.integer "booking_id", null: false
    t.integer "service_id", null: false
    t.integer "mentor_id", null: false
    t.integer "mentee_id", null: false
    t.integer "rating", null: false
    t.text "comment", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["booking_id"], name: "index_reviews_on_booking_id", unique: true
    t.index ["mentor_id"], name: "index_reviews_on_mentor_id"
    t.index ["service_id"], name: "index_reviews_on_service_id"
  end

  create_table "roles", id: :serial, force: :cascade do |t|
    t.string "name", limit: 50, null: false
    t.string "description", limit: 300, default: "", null: false
    t.jsonb "permissions"
    t.integer "lock_version", default: 0, null: false
    t.index ["name"], name: "index_roles_on_name", unique: true
  end

  create_table "saved_reports", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "name", limit: 150, null: false
    t.string "kind", null: false
    t.jsonb "columns", default: [], null: false
    t.jsonb "filters", default: {"period"=>"30"}, null: false
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_saved_reports_on_user_id"
  end

  create_table "services", id: :serial, force: :cascade do |t|
    t.integer "mentor_id", null: false
    t.integer "category_id", null: false
    t.string "title", limit: 100, null: false
    t.text "description", null: false
    t.decimal "price", precision: 10, scale: 2, null: false
    t.integer "duration", null: false
    t.jsonb "tags", default: [], null: false
    t.string "image_url", limit: 255
    t.boolean "is_active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_services_on_category_id"
    t.index ["is_active"], name: "index_services_on_is_active"
    t.index ["mentor_id"], name: "index_services_on_mentor_id"
    t.index ["price"], name: "index_services_on_price"
  end

  create_table "session_asset_accesses", force: :cascade do |t|
    t.bigint "session_asset_id", null: false
    t.bigint "user_id"
    t.string "kind", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["session_asset_id"], name: "index_session_asset_accesses_on_session_asset_id"
    t.index ["user_id"], name: "index_session_asset_accesses_on_user_id"
  end

  create_table "session_assets", force: :cascade do |t|
    t.bigint "booking_id", null: false
    t.string "kind", null: false
    t.string "title", limit: 200, null: false
    t.text "description"
    t.string "url", limit: 2048
    t.boolean "is_active", default: true, null: false
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["booking_id"], name: "index_session_assets_on_booking_id"
  end

  create_table "session_feedbacks", force: :cascade do |t|
    t.bigint "booking_id", null: false
    t.bigint "user_id", null: false
    t.integer "rating", null: false
    t.text "comment", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["booking_id", "user_id"], name: "index_session_feedbacks_on_booking_id_and_user_id", unique: true
    t.index ["booking_id"], name: "index_session_feedbacks_on_booking_id"
    t.index ["user_id"], name: "index_session_feedbacks_on_user_id"
    t.check_constraint "rating >= 1 AND rating <= 5", name: "session_feedback_rating_range"
  end

  create_table "session_notes", force: :cascade do |t|
    t.bigint "booking_id", null: false
    t.bigint "author_id"
    t.string "author_name", null: false
    t.text "body", null: false
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["author_id"], name: "index_session_notes_on_author_id"
    t.index ["booking_id"], name: "index_session_notes_on_booking_id"
  end

  create_table "skills", id: :serial, force: :cascade do |t|
    t.string "name", limit: 100, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_skills_on_name", unique: true
  end

  create_table "system_setting_audits", force: :cascade do |t|
    t.bigint "actor_id"
    t.string "actor_name", null: false
    t.string "action", null: false
    t.jsonb "changeset", default: {}, null: false
    t.integer "revision", null: false
    t.datetime "created_at", null: false
    t.index ["actor_id"], name: "index_system_setting_audits_on_actor_id"
  end

  create_table "system_setting_snapshots", force: :cascade do |t|
    t.bigint "created_by_id"
    t.string "label", null: false
    t.jsonb "values", null: false
    t.string "checksum", null: false
    t.integer "revision", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_system_setting_snapshots_on_created_by_id"
  end

  create_table "system_settings", force: :cascade do |t|
    t.string "key", default: "platform", null: false
    t.jsonb "values", default: {}, null: false
    t.integer "lock_version", default: 0, null: false
    t.bigint "updated_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_system_settings_on_key", unique: true
    t.index ["updated_by_id"], name: "index_system_settings_on_updated_by_id"
  end

  create_table "user_role_assignments", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "role_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["role_id"], name: "index_user_role_assignments_on_role_id"
    t.index ["user_id", "role_id"], name: "index_user_role_assignments_on_user_id_and_role_id", unique: true
    t.index ["user_id"], name: "index_user_role_assignments_on_user_id"
  end

  create_table "users", id: :serial, force: :cascade do |t|
    t.string "full_name", limit: 100, null: false
    t.string "email", limit: 100, null: false
    t.string "hashed_password", limit: 128, null: false
    t.boolean "is_active", default: true
    t.boolean "is_verified", default: false
    t.integer "role_id"
    t.datetime "created_at", default: -> { "CURRENT_TIMESTAMP" }
    t.datetime "updated_at"
    t.string "phone_number"
    t.datetime "last_active_at"
    t.integer "auth_version", default: 0, null: false
    t.string "affiliation", limit: 150, default: "", null: false
    t.integer "lock_version", default: 0, null: false
    t.text "bio"
    t.string "location", limit: 150
    t.string "website", limit: 2048
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["phone_number"], name: "index_users_on_phone_number", unique: true
  end

  add_foreign_key "account_settings", "users"
  add_foreign_key "achievement_awards", "achievement_definitions"
  add_foreign_key "achievement_awards", "platform_programs"
  add_foreign_key "achievement_awards", "users"
  add_foreign_key "achievement_awards", "users", column: "issuer_id", on_delete: :nullify
  add_foreign_key "achievement_criteria", "achievement_awards"
  add_foreign_key "achievement_goal_links", "mentee_goals"
  add_foreign_key "achievement_notes", "users", column: "author_id", on_delete: :nullify
  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "administration_audits", "users", column: "actor_id", on_delete: :nullify
  add_foreign_key "availability_slots", "users", column: "mentor_id"
  add_foreign_key "booking_participants", "bookings", on_delete: :cascade
  add_foreign_key "booking_participants", "users", on_delete: :cascade
  add_foreign_key "bookings", "categories", column: "session_category_id"
  add_foreign_key "bookings", "platform_programs"
  add_foreign_key "bookings", "services"
  add_foreign_key "bookings", "users", column: "mentee_id"
  add_foreign_key "bookings", "users", column: "mentor_id"
  add_foreign_key "categories", "categories", column: "parent_id", on_delete: :nullify
  add_foreign_key "chat_messages", "conversations"
  add_foreign_key "chat_messages", "users", column: "sender_id"
  add_foreign_key "conversation_memberships", "conversations"
  add_foreign_key "conversation_memberships", "users"
  add_foreign_key "conversations", "platform_programs"
  add_foreign_key "conversations", "users", column: "creator_id"
  add_foreign_key "event_agenda_items", "events"
  add_foreign_key "event_feedbacks", "events"
  add_foreign_key "event_feedbacks", "users"
  add_foreign_key "event_materials", "events"
  add_foreign_key "event_registrations", "events"
  add_foreign_key "event_registrations", "users"
  add_foreign_key "event_speakers", "events"
  add_foreign_key "event_suggestions", "users"
  add_foreign_key "events", "platform_programs", on_delete: :nullify
  add_foreign_key "events", "users", column: "organizer_id"
  add_foreign_key "goal_attachments", "mentee_goals"
  add_foreign_key "goal_attachments", "mentor_goals"
  add_foreign_key "goal_attachments", "program_goals"
  add_foreign_key "goal_attachments", "users", column: "author_id", on_delete: :nullify
  add_foreign_key "goal_milestones", "mentee_goals"
  add_foreign_key "goal_milestones", "mentor_goals"
  add_foreign_key "goal_milestones", "program_goals"
  add_foreign_key "goal_progress_events", "mentee_goals"
  add_foreign_key "goal_progress_events", "mentor_goals"
  add_foreign_key "goal_progress_events", "program_goals"
  add_foreign_key "goal_updates", "mentee_goals"
  add_foreign_key "goal_updates", "mentor_goals"
  add_foreign_key "goal_updates", "program_goals"
  add_foreign_key "goal_updates", "users", column: "author_id", on_delete: :nullify
  add_foreign_key "integration_logs", "users", column: "actor_id", on_delete: :nullify
  add_foreign_key "learning_certificates", "learning_enrollments"
  add_foreign_key "learning_enrollments", "users"
  add_foreign_key "learning_lesson_completions", "learning_enrollments"
  add_foreign_key "mentee_goals", "platform_programs", on_delete: :nullify
  add_foreign_key "mentee_goals", "users"
  add_foreign_key "mentee_profiles", "platform_programs", column: "primary_program_id", on_delete: :nullify
  add_foreign_key "mentee_profiles", "users"
  add_foreign_key "mentee_profiles", "users", column: "assigned_mentor_id", on_delete: :nullify
  add_foreign_key "mentor_applications", "users"
  add_foreign_key "mentor_applications", "users", column: "reviewed_by_id"
  add_foreign_key "mentor_goals", "platform_programs", on_delete: :nullify
  add_foreign_key "mentor_goals", "users"
  add_foreign_key "mentor_profiles", "users"
  add_foreign_key "mentor_skills", "mentor_profiles"
  add_foreign_key "mentor_skills", "skills"
  add_foreign_key "mentorship_resources", "users"
  add_foreign_key "message_broadcasts", "users", column: "sender_id"
  add_foreign_key "messaging_blocks", "users", column: "blocked_id"
  add_foreign_key "messaging_blocks", "users", column: "blocker_id"
  add_foreign_key "messaging_preferences", "users"
  add_foreign_key "notification_preferences", "users"
  add_foreign_key "notifications", "users"
  add_foreign_key "platform_integrations", "users", column: "updated_by_id"
  add_foreign_key "platform_programs", "categories", on_delete: :nullify
  add_foreign_key "platform_programs", "users", column: "created_by_id", on_delete: :nullify
  add_foreign_key "platform_resource_accesses", "platform_resources", on_delete: :cascade
  add_foreign_key "platform_resource_accesses", "users", on_delete: :cascade
  add_foreign_key "platform_resources", "platform_programs"
  add_foreign_key "platform_resources", "users", column: "created_by_id", on_delete: :nullify
  add_foreign_key "profiles", "users"
  add_foreign_key "program_goals", "platform_programs"
  add_foreign_key "program_memberships", "platform_programs"
  add_foreign_key "program_memberships", "users"
  add_foreign_key "program_mentor_assignments", "platform_programs", on_delete: :cascade
  add_foreign_key "program_mentor_assignments", "users", on_delete: :cascade
  add_foreign_key "public_inquiries", "events", on_delete: :nullify
  add_foreign_key "public_inquiries", "users", column: "requester_id", on_delete: :nullify
  add_foreign_key "public_inquiries", "users", column: "reviewer_id", on_delete: :nullify
  add_foreign_key "refresh_tokens", "users", on_delete: :cascade
  add_foreign_key "report_runs", "report_schedules", on_delete: :nullify
  add_foreign_key "report_runs", "users"
  add_foreign_key "report_schedules", "users"
  add_foreign_key "resource_bookmarks", "platform_resources"
  add_foreign_key "resource_bookmarks", "users"
  add_foreign_key "resource_comments", "platform_resources"
  add_foreign_key "resource_comments", "users"
  add_foreign_key "resource_contents", "platform_resources", on_delete: :cascade
  add_foreign_key "resource_feedbacks", "platform_resources", on_delete: :cascade
  add_foreign_key "resource_feedbacks", "users", on_delete: :cascade
  add_foreign_key "resource_program_shares", "platform_programs", on_delete: :cascade
  add_foreign_key "resource_program_shares", "platform_resources", on_delete: :cascade
  add_foreign_key "resource_progresses", "platform_resources", on_delete: :cascade
  add_foreign_key "resource_progresses", "users", on_delete: :cascade
  add_foreign_key "resource_versions", "platform_resources", on_delete: :cascade
  add_foreign_key "resource_versions", "users", column: "actor_id", on_delete: :nullify
  add_foreign_key "reviews", "bookings"
  add_foreign_key "reviews", "services"
  add_foreign_key "reviews", "users", column: "mentee_id"
  add_foreign_key "reviews", "users", column: "mentor_id"
  add_foreign_key "saved_reports", "users"
  add_foreign_key "services", "categories"
  add_foreign_key "services", "users", column: "mentor_id"
  add_foreign_key "session_asset_accesses", "session_assets", on_delete: :cascade
  add_foreign_key "session_asset_accesses", "users", on_delete: :nullify
  add_foreign_key "session_assets", "bookings", on_delete: :cascade
  add_foreign_key "session_feedbacks", "bookings", on_delete: :cascade
  add_foreign_key "session_feedbacks", "users", on_delete: :cascade
  add_foreign_key "session_notes", "bookings", on_delete: :cascade
  add_foreign_key "session_notes", "users", column: "author_id", on_delete: :nullify
  add_foreign_key "system_setting_audits", "users", column: "actor_id", on_delete: :nullify
  add_foreign_key "system_setting_snapshots", "users", column: "created_by_id", on_delete: :nullify
  add_foreign_key "system_settings", "users", column: "updated_by_id", on_delete: :nullify
  add_foreign_key "user_role_assignments", "roles"
  add_foreign_key "user_role_assignments", "users"
  add_foreign_key "users", "roles"
end
