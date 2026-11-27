# frozen_string_literal: true

class CreateOrganizationReviews < ActiveRecord::Migration[8.1]
  def change
    create_table :organization_reviews do |t|
      t.references :organization, null: false, foreign_key: { on_delete: :cascade }
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.integer :rating, null: false
      t.text :text

      t.timestamps
    end

    add_index :organization_reviews, %i[organization_id user_id], unique: true
    add_check_constraint :organization_reviews, 'rating >= 1 AND rating <= 5', name: 'chk_organization_reviews_rating'
  end
end
