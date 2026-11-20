# frozen_string_literal: true

FactoryBot.define do
  factory :event_medium, class: 'EventMedia' do
    association :event, :draft
    kind { 'gallery' }
    sequence(:position)

    after(:build) do |media|
      media.file.attach(
        io: StringIO.new(EventImageFixture::PNG_BYTES),
        filename: 'photo.png',
        content_type: 'image/png'
      )
    end

    trait :banner do
      kind { 'banner' }
      position { 0 }
    end
  end
end
