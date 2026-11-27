# frozen_string_literal: true

class AddRatingAggregationToEventsAndOrganizations < ActiveRecord::Migration[8.1]
  def change
    change_table :events, bulk: true do |t|
      t.decimal :average_rating, precision: 3, scale: 2
      t.integer :reviews_count, default: 0, null: false
    end

    change_table :organizations, bulk: true do |t|
      t.decimal :average_rating, precision: 3, scale: 2
      t.integer :reviews_count, default: 0, null: false
    end

    add_check_constraint :events, 'reviews_count >= 0', name: 'chk_events_reviews_count'
    add_check_constraint :organizations, 'reviews_count >= 0', name: 'chk_organizations_reviews_count'
  end
end
