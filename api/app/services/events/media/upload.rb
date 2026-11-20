# frozen_string_literal: true

module Events
  module Media
    # Stores one banner or gallery image. Returns Dry::Monads::Result.
    class Upload
      include Dry::Monads[:result]

      def self.call(event:, upload:, kind:)
        new(event:, upload:, kind: kind.to_s).call
      end

      def initialize(event:, upload:, kind:)
        @event = event
        @upload = upload
        @kind = kind
        @media = event.event_media.build(kind: kind, position: next_position)
      end

      def call
        reject_upload
        return Failure(@media) if @media.errors.any?

        store
        Success(@media)
      rescue ActiveRecord::RecordInvalid => e
        Failure(e.record)
      rescue ActiveRecord::RecordNotUnique
        @media.errors.add(:kind, 'already has a banner')
        Failure(@media)
      end

      private

      def reject_upload
        @media.errors.add(:kind, :inclusion) unless EventMedia::KINDS.include?(@kind)
        reject_file
        reject_gallery_overflow
      end

      def reject_file
        if @upload.blank?
          @media.errors.add(:file, 'must be attached')
          return
        end

        @media.errors.add(:file, EventMedia.file_too_large_message) if @upload.size > EventMedia::MAX_BYTE_SIZE
        return if EventMedia::CONTENT_TYPES.include?(@upload.content_type)

        @media.errors.add(:file, 'must be JPEG, PNG, or WEBP')
      end

      def reject_gallery_overflow
        return unless @kind == 'gallery'
        return if @event.event_media.gallery.count < EventMedia::MAX_GALLERY_IMAGES

        @media.errors.add(:file, EventMedia.gallery_limit_message)
      end

      def store
        EventMedia.transaction do
          @event.event_media.banner.find_each(&:destroy!) if @kind == 'banner'
          @upload.tempfile.rewind
          @media.file.attach(io: @upload.tempfile, filename: filename, content_type: @upload.content_type)
          @media.save!
        end
      end

      def next_position
        return 0 if @kind == 'banner'

        (@event.event_media.gallery.maximum(:position) || -1) + 1
      end

      def filename
        @upload.original_filename.presence || 'upload'
      end
    end
  end
end
