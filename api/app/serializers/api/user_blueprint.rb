# frozen_string_literal: true

module Api
  class UserBlueprint < Blueprinter::Base
    identifier :id

    fields :email, :first_name, :last_name, :phone, :birth_date,
           :city, :preferred_locale, :platform_role, :is_active

    field :avatar_url do |user|
      user.avatar.attached? ? user.avatar.url : nil
    end

    field :email_confirmed_at do |user|
      user.email_confirmed_at&.utc&.iso8601(3)
    end

    field :created_at do |user|
      user.created_at&.utc&.iso8601(3)
    end

    field :updated_at do |user|
      user.updated_at&.utc&.iso8601(3)
    end
  end
end
