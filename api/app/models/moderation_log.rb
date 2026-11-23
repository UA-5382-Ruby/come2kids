# frozen_string_literal: true

# Append-only audit trail of moderation decisions (FR-MOD-3, FR-MOD-7, FR-APP-7).
class ModerationLog < ApplicationRecord
  ENTITY_TYPES = %w[User Organization Event Appeal].freeze
  DECISIONS = %w[approved rejected blocked unblocked appeal_submitted appeal_accepted appeal_rejected].freeze

  belongs_to :moderator, class_name: 'User', optional: true

  validates :entity_type, inclusion: { in: ENTITY_TYPES }
  validates :entity_id, presence: true
  validates :decision, inclusion: { in: DECISIONS }

  scope :for_entity, ->(entity) { where(entity_type: entity.class.name, entity_id: entity.id) }

  def self.record!(entity:, decision:, moderator: nil, reason: nil)
    create!(entity_type: entity.class.name, entity_id: entity.id, moderator: moderator,
            decision: decision.to_s, reason: reason.presence)
  end

  def readonly?
    persisted?
  end
end
