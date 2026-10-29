class Category < ApplicationRecord
  has_many :events, dependent: :restrict_with_error

  validates :slug, presence: true, uniqueness: true
  validates :name_uk, :name_en, presence: true

  scope :ordered, -> { order(position: :asc) }
end
