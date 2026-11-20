# frozen_string_literal: true

class Order < ApplicationRecord
  belongs_to :user
  belongs_to :event

  has_many :order_items, dependent: :destroy
  enum :status, { pending: 'pending', paid: 'paid', cancelled: 'cancelled' }

  validates :total_amount, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :idempotency_key, presence: true, uniqueness: true
end
