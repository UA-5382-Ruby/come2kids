# frozen_string_literal: true

class RemoveAvatarUrlFromUsers < ActiveRecord::Migration[8.1]
  def change
    remove_column :users, :avatar_url, :string
  end
end
