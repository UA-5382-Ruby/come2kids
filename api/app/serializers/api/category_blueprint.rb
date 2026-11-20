# frozen_string_literal: true

module Api
  class CategoryBlueprint < Blueprinter::Base
    identifier :id

    field :slug

    field :name do |category|
      category.public_send(:"name_#{I18n.locale}")
    end

    view :full do
      fields :name_uk, :name_en, :position

      field :created_at do |category|
        category.created_at&.utc&.iso8601(3)
      end

      field :updated_at do |category|
        category.updated_at&.utc&.iso8601(3)
      end
    end
  end
end
