# frozen_string_literal: true

class RequireOrderIdempotencyKey < ActiveRecord::Migration[8.1]
  def change
    change_column_null :orders, :idempotency_key, false
  end
end
