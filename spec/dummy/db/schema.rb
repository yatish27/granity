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

ActiveRecord::Schema[8.0].define(version: 2025_03_17_000000) do
  create_table "granity_relation_tuples", force: :cascade do |t|
    t.string "object_type", null: false
    t.string "object_id", null: false
    t.string "relation", null: false
    t.string "subject_type", null: false
    t.string "subject_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["object_type", "object_id", "relation", "subject_type", "subject_id"], name: "index_granity_tuples_unique", unique: true
    t.index ["object_type", "object_id", "relation"], name: "index_granity_tuples_on_object"
    t.index ["subject_type", "subject_id"], name: "index_granity_tuples_on_subject"
  end
end
