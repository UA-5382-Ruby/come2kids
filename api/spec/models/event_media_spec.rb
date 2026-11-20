# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EventMedia do
  let(:event) { create(:event, :draft) }

  def attach(media, content_type: 'image/png', body: EventImageFixture::PNG_BYTES, filename: 'photo.png')
    media.file.attach(io: StringIO.new(body), filename: filename, content_type: content_type)
  end

  it 'accepts a png gallery image' do
    media = event.event_media.build(kind: 'gallery', position: 1)
    attach(media)

    expect(media).to be_valid
  end

  it 'rejects a missing file' do
    media = event.event_media.build(kind: 'gallery', position: 1)

    expect(media).not_to be_valid
    expect(media.errors[:file]).to be_present
  end

  it 'rejects a file that is not a jpeg, png, or webp' do
    media = event.event_media.build(kind: 'gallery', position: 1)
    attach(media, content_type: 'text/plain', body: 'hello', filename: 'notes.txt')

    expect(media).not_to be_valid
    expect(media.errors[:file]).to include('must be JPEG, PNG, or WEBP')
  end

  it 'rejects a file over the size limit' do
    media = event.event_media.build(kind: 'gallery', position: 1)
    attach(media, body: 'a' * (described_class::MAX_BYTE_SIZE + 1))

    expect(media).not_to be_valid
    expect(media.errors[:file]).to include(described_class.file_too_large_message)
  end

  it 'rejects a gallery image past the limit' do
    described_class::MAX_GALLERY_IMAGES.times do |index|
      create(:event_medium, event: event, position: index)
    end
    extra = event.event_media.build(kind: 'gallery', position: described_class::MAX_GALLERY_IMAGES)
    attach(extra)

    expect(extra).not_to be_valid
    expect(extra.errors[:file]).to include(described_class.gallery_limit_message)
  end

  it 'rejects a second banner' do
    create(:event_medium, :banner, event: event)
    second = event.event_media.build(kind: 'banner', position: 0)
    attach(second)

    expect(second).not_to be_valid
    expect(second.errors[:kind]).to include('already has a banner')
  end
end
