# frozen_string_literal: true

# A user follows an event or an organization (US-12.1, FR-SUB-1).
class Subscription < ApplicationRecord
  TARGET_TYPES = %w[Event Organization].freeze

  belongs_to :user
  belongs_to :target, polymorphic: true

  validates :target_type, inclusion: { in: TARGET_TYPES }
  validates :target_id, uniqueness: { scope: %i[user_id target_type] }

  scope :for_target, ->(target) { where(target_type: target.class.name, target_id: target.id) }

  # The event title or organization name in the current locale.
  def target_name
    target.is_a?(Event) ? target.title : target&.name
  end
end
