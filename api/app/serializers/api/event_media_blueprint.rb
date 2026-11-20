# frozen_string_literal: true

module Api
  class EventMediaBlueprint < Blueprinter::Base
    identifier :id

    fields :kind, :position

    field :url do |media|
      next unless media.file.attached?

      Rails.application.routes.url_helpers.rails_blob_path(media.file, only_path: true)
    end

    field :content_type do |media|
      media.file.blob&.content_type
    end

    field :byte_size do |media|
      media.file.blob&.byte_size
    end
  end
end
