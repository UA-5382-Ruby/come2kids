# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApplicationPolicy do
  let(:organization) { create(:organization) }
  let(:owner) { create(:company_member, :owner, organization: organization).user }
  let(:manager) { create(:company_member, :manager, organization: organization).user }

  describe "deny by default" do
    let(:actions) { %i[index? show? create? new? update? edit? destroy?] }

    {
      "a guest" => -> { nil },
      "a user" => -> { create(:user) },
      "a moderator" => -> { create(:user, :moderator) },
      "the organization owner" => -> { owner }
    }.each do |who, user_for|
      it "denies every action to #{who}" do
        policy = described_class.new(instance_exec(&user_for), organization)

        expect(actions.map { |action| policy.public_send(action) }).to all(be(false))
      end
    end

    it "resolves an empty scope" do
      organization

      expect(described_class::Scope.new(owner, Organization).resolve).to be_empty
    end
  end

  describe "role helpers" do
    # Exposes the private helpers that subclasses use.
    let(:policy_class) do
      Class.new(described_class) do
        public :guest?, :moderator?, :owner_of?, :manager_of?, :organization_member?
      end
    end
    let(:other_organization) { create(:organization) }

    def policy_for(user, record = organization)
      policy_class.new(user, record)
    end

    it "recognises a guest" do
      expect(policy_for(nil)).to be_guest
      expect(policy_for(nil)).not_to be_organization_member
      expect(policy_for(create(:user))).not_to be_guest
    end

    it "recognises a moderator" do
      expect(policy_for(create(:user, :moderator))).to be_moderator
      expect(policy_for(create(:user))).not_to be_moderator
      expect(policy_for(nil)).not_to be_moderator
    end

    it "resolves the owner and manager of the record's organization" do
      expect(policy_for(owner)).to be_owner_of
      expect(policy_for(owner)).not_to be_manager_of
      expect(policy_for(manager)).to be_manager_of
      expect(policy_for(manager)).not_to be_owner_of
      expect([ policy_for(owner), policy_for(manager) ]).to all(be_organization_member)
    end

    it "does not grant roles in another organization" do
      expect(policy_for(owner, other_organization)).not_to be_organization_member
      expect(policy_for(manager, other_organization)).not_to be_organization_member
    end

    it "takes the organization from a record that belongs to one" do
      event = Event.new(organization: organization)
      foreign_event = Event.new(organization: other_organization)

      expect(policy_for(manager, event)).to be_manager_of
      expect(policy_for(manager, foreign_event)).not_to be_organization_member
    end

    it "grants no organization role for a record without an organization" do
      expect(policy_for(owner, Event)).not_to be_organization_member
      expect(policy_for(owner, create(:user))).not_to be_organization_member
    end
  end
end
