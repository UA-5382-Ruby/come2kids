# frozen_string_literal: true

module Events
  # Moves an event along the stored status graph and writes one history row.
  # Returns Dry::Monads::Result. Does not check submit completeness.
  class Transition
    include Dry::Monads[:result]

    ALLOWED = {
      nil => %w[draft],
      'draft' => %w[under_review],
      'rejected' => %w[under_review],
      'under_review' => %w[published rejected],
      'published' => %w[cancelled_by_organizer]
    }.freeze

    def self.call(event:, to:, actor:, reason: nil, from: event.status)
      new(event:, to: to.to_s, actor:, reason:, from:).call
    end

    def self.record!(event:, from:, to:, actor:, reason: nil)
      event.event_status_histories.create!(
        from_status: from,
        to_status: to,
        changed_by: actor,
        reason: reason.presence,
        changed_at: Time.current
      )
    end

    def initialize(event:, to:, actor:, reason:, from:)
      @event = event
      @to = to
      @actor = actor
      @reason = reason
      @from = from
    end

    def call
      return deny(:status, 'is not an allowed transition') unless allowed?
      return deny(:status, 'is not allowed for this user') unless actor_allowed?
      return deny(:reason, "can't be blank") if reason_required? && @reason.blank?

      apply
      ActiveRecord::Base.transaction do
        @event.save!
        self.class.record!(event: @event, from: @from, to: @to, actor: @actor, reason: @reason)
      end
      Success(@event)
    rescue ActiveRecord::RecordInvalid => e
      Failure(e.record)
    end

    private

    def allowed?
      Array(ALLOWED[@from]).include?(@to)
    end

    def actor_allowed?
      case @to
      when 'published', 'rejected' then @actor&.moderator?
      when 'under_review', 'cancelled_by_organizer' then member?
      when 'draft' then @actor.present? && @actor == @event.created_by
      else false
      end
    end

    def member?
      @actor.present? && (@actor.owner_of?(@event.organization) || @actor.manager_of?(@event.organization))
    end

    def reason_required?
      @to == 'rejected'
    end

    def apply
      @event.status = @to
      case @to
      when 'under_review' then @event.submitted_at = Time.current
      when 'published' then publish
      when 'rejected' then reject
      when 'cancelled_by_organizer' then @event.cancelled_at = Time.current
      end
    end

    def publish
      @event.published_at = Time.current
      @event.reviewed_by = @actor
      @event.rejection_reason = nil
    end

    def reject
      @event.reviewed_by = @actor
      @event.rejection_reason = @reason
    end

    def deny(attribute, message)
      @event.errors.add(attribute, message)
      Failure(@event)
    end
  end
end
