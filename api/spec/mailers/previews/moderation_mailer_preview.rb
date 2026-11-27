# frozen_string_literal: true

class ModerationMailerPreview < ActionMailer::Preview
  def revision_decision
    ModerationMailer.revision_decision(EventRevision.first, 'rejected', 'Неповний опис')
  end
end
