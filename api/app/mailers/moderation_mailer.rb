# frozen_string_literal: true

# Moderation notifications (Technical Requirements, 3.9; FR-MOD-2, FR-MOD-7, FR-APP-6).
# Every email is sent in the recipient's preferred language and uses one shared template:
# a heading, a body sentence and the moderator's reason when there is one.
class ModerationMailer < ApplicationMailer
  # decision: "approved" | "rejected"
  def organization_decision(organization, decision, reason = nil)
    deliver_notification(organization.owner, "organization_#{decision}", reason) { { name: organization.name } }
  end

  # decision: "approved" | "rejected"
  def event_decision(event, decision, reason = nil)
    deliver_notification(event.created_by, "event_#{decision}", reason) { { title: event.title || "##{event.id}" } }
  end

  # decision: "approved" | "rejected". Goes to the person who submitted the edit of a published event.
  def revision_decision(revision, decision, reason = nil)
    event = revision.event
    deliver_notification(revision.submitted_by, "revision_#{decision}", reason) { { title: event.title || "##{event.id}" } }
  end

  # action: "blocked" | "unblocked"
  def user_block_changed(user, action, reason = nil)
    deliver_notification(user, "user_#{action}", reason)
  end

  # action: "blocked" | "unblocked". An organization that was blocked before its approval returns to
  # pending_approval, so its unblock email does not promise visible events (the *_pending texts).
  def organization_block_changed(organization, action, reason = nil)
    key = "organization_#{action}#{pending_suffix(organization)}"
    deliver_notification(organization.owner, key, reason) { { name: organization.name } }
  end

  def appeal_decision(appeal)
    key = "appeal_#{appeal.status}_#{appeal.target_type.underscore}"
    key += pending_suffix(appeal.target) if appeal.accepted?
    deliver_notification(appeal.appellant, key, appeal.decision_reason) do
      appeal.target.is_a?(Organization) ? { name: appeal.target.name } : {}
    end
  end

  private

  def pending_suffix(target)
    target.is_a?(Organization) && target.pending_approval? ? '_pending' : ''
  end

  # The block returns interpolation values; it runs inside the recipient's locale, so translated
  # names and titles come out in the recipient's language.
  def deliver_notification(recipient, key, reason)
    I18n.with_locale(recipient.preferred_locale) do
      values = block_given? ? yield : {}
      @recipient = recipient
      @heading = t("moderation_mailer.#{key}.heading", **values)
      @body = t("moderation_mailer.#{key}.body", **values)
      @reason = reason.presence
      mail(to: recipient.email, subject: t("moderation_mailer.#{key}.subject", **values),
           template_name: 'notification')
    end
  end
end
