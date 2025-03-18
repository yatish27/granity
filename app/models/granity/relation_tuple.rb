module Granity
  class RelationTuple < ActiveRecord::Base
    self.table_name = "granity_relation_tuples"

    validates :object_type, :object_id, :relation, :subject_type, :subject_id, presence: true

    # Useful scopes for querying
    scope :for_object, ->(type, id) { where(object_type: type, object_id: id) }
    scope :for_subject, ->(type, id) { where(subject_type: type, subject_id: id) }
    scope :with_relation, ->(relation) { where(relation: relation) }
  end
end
