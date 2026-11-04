# frozen_string_literal: true

# Append-only activity / failure log stored in MongoDB (collection: activity_logs).
# Schema matches the technical requirements (Section 6.5).
class ActivityLog
  include Mongoid::Document
  include Mongoid::Timestamps::Created

  store_in collection: "activity_logs"

  field :timestamp, type: Time
  field :user_id, type: Integer
  field :role, type: String
  field :action, type: String
  field :entity_type, type: String
  field :entity_id, type: String
  field :result, type: String
  field :ip, type: String
  field :user_agent, type: String
  field :request_id, type: String
  field :metadata, type: Hash, default: {}

  index({ user_id: 1, timestamp: -1 })
  index({ action: 1, timestamp: -1 })
  index({ entity_type: 1, entity_id: 1 })

  validates :action, :result, :timestamp, presence: true
end
