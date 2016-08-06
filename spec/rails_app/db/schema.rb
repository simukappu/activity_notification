# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20160715050433) do

  create_table "admins", force: :cascade do |t|
    t.integer  "user_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "admins", ["user_id"], name: "index_admins_on_user_id"

  create_table "articles", force: :cascade do |t|
    t.integer  "user_id"
    t.string   "title"
    t.string   "body"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "articles", ["user_id"], name: "index_articles_on_user_id"

  create_table "comments", force: :cascade do |t|
    t.integer  "user_id"
    t.integer  "article_id"
    t.string   "body"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "comments", ["article_id"], name: "index_comments_on_article_id"
  add_index "comments", ["user_id"], name: "index_comments_on_user_id"

  create_table "notifications", force: :cascade do |t|
    t.integer  "target_id",       null: false
    t.string   "target_type",     null: false
    t.integer  "notifiable_id",   null: false
    t.string   "notifiable_type", null: false
    t.string   "key",             null: false
    t.integer  "group_id"
    t.string   "group_type"
    t.integer  "group_owner_id"
    t.integer  "notifier_id"
    t.string   "notifier_type"
    t.text     "parameters"
    t.datetime "opened_at"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "notifications", ["group_owner_id"], name: "index_notifications_on_group_owner_id"
  add_index "notifications", ["group_type", "group_id"], name: "index_notifications_on_group_type_and_group_id"
  add_index "notifications", ["notifiable_type", "notifiable_id"], name: "index_notifications_on_notifiable_type_and_notifiable_id"
  add_index "notifications", ["notifier_type", "notifier_id"], name: "index_notifications_on_notifier_type_and_notifier_id"
  add_index "notifications", ["target_type", "target_id"], name: "index_notifications_on_target_type_and_target_id"

  create_table "users", force: :cascade do |t|
    t.string   "email",                default: "", null: false
    t.string   "encrypted_password",   default: "", null: false
    t.string   "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string   "name"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "users", ["email"], name: "index_users_on_email"

end
