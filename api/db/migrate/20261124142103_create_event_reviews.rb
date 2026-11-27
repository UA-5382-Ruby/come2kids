# frozen_string_literal: true

class CreateEventReviews < ActiveRecord::Migration[8.1]
  def change
    create_table :event_reviews do |t|
      t.references :event, null: false, foreign_key: { on_delete: :cascade }
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.integer :rating, null: false
      t.text :text

      t.timestamps
    end

    add_index :event_reviews, %i[event_id user_id], unique: true
    add_check_constraint :event_reviews, 'rating >= 1 AND rating <= 5', name: 'chk_event_reviews_rating'
  end
end
