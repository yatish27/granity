class CreateGranityRelationTuples < ActiveRecord::Migration[7.0]
  def change
    create_table :granity_relation_tuples do |t|
      t.string :object_type, null: false
      t.string :object_id, null: false
      t.string :relation, null: false
      t.string :subject_type, null: false
      t.string :subject_id, null: false

      t.timestamps
    end

    add_index :granity_relation_tuples, [:object_type, :object_id, :relation],
      name: "index_granity_tuples_on_object"
    add_index :granity_relation_tuples, [:subject_type, :subject_id],
      name: "index_granity_tuples_on_subject"
    add_index :granity_relation_tuples, [:object_type, :object_id, :relation, :subject_type, :subject_id],
      unique: true, name: "index_granity_tuples_unique"
  end
end
