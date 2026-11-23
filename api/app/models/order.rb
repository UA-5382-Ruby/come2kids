# frozen_string_literal: true

class Order < ApplicationRecord
  belongs_to :user
  belongs_to :event

  has_many :order_items, dependent: :destroy
  has_many :tickets, through: :order_items

  enum :status, { pending: 'pending', paid: 'paid', cancelled: 'cancelled', expired: 'expired' }

  scope :expired_reservations, ->(now = Time.current) { pending.where(reserved_until: ..now) }

  validates :total_amount, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :idempotency_key, presence: true, uniqueness: true
end
