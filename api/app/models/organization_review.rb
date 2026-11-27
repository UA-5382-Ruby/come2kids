# frozen_string_literal: true

class OrganizationReview < ApplicationRecord
  belongs_to :organization
  belongs_to :user

  validates :rating, presence: true, numericality: { only_integer: true, in: 1..5 }
  validates :user_id, uniqueness: { scope: :organization_id }

  after_commit :recalculate_organization_rating, on: %i[create update destroy]

  private

  def recalculate_organization_rating
    Ratings::RecalculateService.new(organization).call
  end
end
