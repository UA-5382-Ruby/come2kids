# frozen_string_literal: true

# app/models/user.rb
class User < ApplicationRecord
  # Явно вказуємо назву таблиці в БД
  self.table_name = "Users"

  alias_attribute :created_at, :createdAt
  alias_attribute :updated_at, :updatedAt

  before_create { self.createdAt ||= Time.current }
  before_save   { self.updatedAt = Time.current }
end
