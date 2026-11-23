# frozen_string_literal: true

require "rails_helper"

RSpec.describe EventPolicy do
  subject(:policy) { described_class.new(user, event) }

  let(:organization) { create(:organization) }
  let(:event) { build(:event, :draft, organization: organization) }
  let(:user) { nil }

  describe "#create?" do
    context "when the user owns the approved organization" do
      let(:user) { create(:company_member, :owner, organization: organization).user }

      it "allows the draft" do
        expect(policy.create?).to be(true)
      end
    end

    context "when the user manages the approved organization" do
      let(:user) { create(:company_member, :manager, organization: organization).user }

      it "allows the draft" do
        expect(policy.create?).to be(true)
      end
    end

    context "when the user belongs to another organization" do
      let(:user) { create(:company_member, :owner).user }

      it "denies the draft" do
        expect(policy.create?).to be(false)
      end
    end

    context "when the user has no organization" do
      let(:user) { create(:user) }

      it "denies the draft" do
        expect(policy.create?).to be(false)
      end
    end

    context "when the caller is a guest" do
      it "denies the draft" do
        expect(policy.create?).to be(false)
      end
    end

    context "when the organization is not approved" do
      let(:organization) { create(:organization, status: "pending_approval", approved_at: nil) }
      let(:user) { create(:company_member, :owner, organization: organization).user }

      it "denies the draft" do
        expect(policy.create?).to be(false)
      end
    end

    context 'when the organization is soft-deleted' do
      let(:organization) { create(:organization, deleted_at: Time.current) }
      let(:user) { create(:company_member, :owner, organization: organization).user }

      it 'denies the draft' do
        expect(policy.create?).to be(false)
      end
    end

    context 'when the organization is blocked' do
      let(:organization) do
        create(:organization, status: "blocked", approved_at: nil, blocked_at: Time.current, block_reason: "spam")
      end
      let(:user) { create(:company_member, :owner, organization: organization).user }

      it "denies the draft" do
        expect(policy.create?).to be(false)
      end
    end
  end

  describe "#update?" do
    let(:user) { create(:company_member, :owner, organization: organization).user }

    it "allows a draft and a rejected event" do
      expect(policy.update?).to be(true)

      event.status = "rejected"
      expect(policy.update?).to be(true)
    end

    it "denies review, published, and cancelled events" do
      %w[under_review published cancelled cancelled_by_organizer].each do |status|
        event.status = status

        expect(policy.update?).to be(false)
      end
    end
  end

  describe "#manage_media?" do
    subject(:policy) { described_class.new(user, event) }

    let(:event) { create(:event, :draft, organization: organization) }
    let(:user) { create(:company_member, :owner, organization: organization).user }

    it "allows the owner of an approved organization to change a draft" do
      expect(policy.manage_media?).to be(true)
    end

    it "allows a manager of the same organization" do
      manager = create(:company_member, :manager, organization: organization).user

      expect(described_class.new(manager, event).manage_media?).to be(true)
    end

    it "allows a rejected event" do
      event.update!(status: "rejected")

      expect(policy.manage_media?).to be(true)
    end

    it "denies an event that is under review, published, or cancelled" do
      %w[under_review published cancelled cancelled_by_organizer].each do |status|
        event.update!(status: status)

        expect(policy.manage_media?).to be(false)
      end
    end

    it "denies a member of another organization" do
      outsider = create(:company_member, :owner).user

      expect(described_class.new(outsider, event).manage_media?).to be(false)
    end

    it "denies a user who is not a member" do
      expect(described_class.new(create(:user), event).manage_media?).to be(false)
    end

    it "denies a guest" do
      expect(described_class.new(nil, event).manage_media?).to be(false)
    end

    it "denies an organization that is not approved" do
      organization.update!(status: "pending_approval", approved_at: nil)

      expect(policy.manage_media?).to be(false)
    end

    it "denies a blocked organization" do
      organization.update!(status: "blocked", blocked_at: Time.current, block_reason: "spam")

      expect(policy.manage_media?).to be(false)
    end
  end

  describe "#submit?" do
    let(:user) { create(:company_member, :owner, organization: organization).user }

    it "allows an owner of an approved organization" do
      expect(policy.submit?).to be(true)
    end

    it "denies a user who is not a member" do
      stranger = described_class.new(create(:user), event)

      expect(stranger.submit?).to be(false)
    end
  end

  describe "#revise?" do
    let(:event) { build(:event, organization: organization, status: "published") }
    let(:user) { create(:company_member, :owner, organization: organization).user }

    it "allows an owner to revise a published event" do
      expect(policy.revise?).to be(true)
    end

    it "denies a revision of a draft" do
      event.status = "draft"

      expect(policy.revise?).to be(false)
    end
  end
end
