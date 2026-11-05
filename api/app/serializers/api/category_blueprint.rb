module Api
  class CategoryBlueprint < Blueprinter::Base
    identifier :id

    fields :slug, :name_uk, :name_en, :position

    field :created_at do |category|
      category.created_at&.utc&.iso8601(3)
    end

    field :updated_at do |category|
      category.updated_at&.utc&.iso8601(3)
    end
  end
end
