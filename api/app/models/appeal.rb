# frozen_string_literal: true

# An appeal of a blocked user or of a blocked organization (FR-APP-1..7).
class Appeal < ApplicationRecord
  TARGET_TYPES = %w[User Organization].freeze
  STATUSES = %w[open accepted rejected].freeze
  MESSAGE_MAX_LENGTH = 2000
  # FR-APP-4: after a rejection a new appeal for the same block is accepted only after this delay.
  RESUBMIT_COOLDOWN = 24.hours

  belongs_to :target, polymorphic: true
  belongs_to :submitted_by, class_name: 'User'
  belongs_to :reviewed_by, class_name: 'User', optional: true

  validates :target_type, inclusion: { in: TARGET_TYPES }
  validates :status, inclusion: { in: STATUSES }
  validates :message, presence: true, length: { maximum: MESSAGE_MAX_LENGTH }
  validates :decision_reason, presence: true, if: :rejected?

  scope :currently_open, -> { where(status: 'open') }
  scope :for_target, ->(target) { where(target_type: target.class.name, target_id: target.id) }

  STATUSES.each do |value|
    define_method(:"#{value}?") { status == value }
  end

  # The user who receives the decision: the blocked user, or the owner who appealed for the organization.
  def appellant
    submitted_by
  end

  class << self
    # FR-APP-4: the time when a new appeal against the current block becomes possible, or nil when an
    # appeal can be submitted now. Only rejections of the current block count (reviewed after blocked_at).
    def next_allowed_at(target)
      return if target.blocked_at.nil?

      last_rejection = for_target(target).where(status: 'rejected', reviewed_at: target.blocked_at..)
                                         .maximum(:reviewed_at)
      allowed_at = last_rejection && (last_rejection + RESUBMIT_COOLDOWN)
      allowed_at if allowed_at&.future?
    end

    # When a moderator unblocks a target directly, its open appeal has nothing left to decide: it is closed
    # as accepted and the decision is written to the moderation log (FR-APP-7). The caller already holds the
    # target lock, so the lock order (target, then appeal) matches Appeals::Decide.
    def close_open_for!(target, moderator:, reason: nil)
      for_target(target).currently_open.lock.each do |appeal|
        appeal.update!(status: 'accepted', reviewed_by: moderator, reviewed_at: Time.current, decision_reason: reason)
        ModerationLog.record!(entity: appeal, moderator: moderator, decision: :appeal_accepted, reason: reason)
      end
    end
  end
end
