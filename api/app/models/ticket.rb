# frozen_string_literal: true

class Ticket < ApplicationRecord
  belongs_to :order_item
  belongs_to :user
  belongs_to :event
  belongs_to :checked_in_by, class_name: 'User', optional: true

  has_one :order, through: :order_item
  has_one :ticket_type, through: :order_item

  enum :status, {
    valid: 'valid',
    used: 'used',
    cancelled: 'cancelled'
  }, prefix: true

  before_validation :assign_defaults, on: :create

  validates :code, presence: true, uniqueness: true
  validates :qr_token, presence: true, uniqueness: true
  validates :issued_at, presence: true

  private

  def assign_defaults
    self.code ||= generate_unique_code
    self.qr_token ||= generate_unique_qr_token
    self.issued_at ||= Time.current
  end

  def generate_unique_code
    loop do
      candidate = "TKT-#{SecureRandom.alphanumeric(10).upcase}"
      break candidate unless self.class.exists?(code: candidate)
    end
  end

  def generate_unique_qr_token
    loop do
      candidate = SecureRandom.urlsafe_base64(32)
      break candidate unless self.class.exists?(qr_token: candidate)
    end
  end
end
