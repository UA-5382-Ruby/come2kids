# frozen_string_literal: true

class Question < ApplicationRecord
  TARGET_TYPES = %w[Event Organization Platform].freeze

  belongs_to :author, class_name: 'User'
  belongs_to :target, polymorphic: true, optional: true
  has_many :answers, -> { order(created_at: :asc) }, dependent: :destroy

  validates :target_type, presence: true, inclusion: { in: TARGET_TYPES }
  validates :target, presence: true, unless: :platform?
  validates :target_id, absence: true, if: :platform?
  validates :text, presence: true, length: { maximum: 2000 }

  scope :visible, -> { where(is_hidden: false) }
  scope :platform, -> { where(target_type: 'Platform') }

  def platform?
    target_type == 'Platform'
  end

  def event?
    target_type == 'Event'
  end

  def organization?
    target_type == 'Organization'
  end
end
