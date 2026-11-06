# frozen_string_literal: true

require "rails_helper"

RSpec.describe User do
  describe "organization roles" do
    let(:user) { create(:user) }
    let(:owned) { create(:organization) }
    let(:managed) { create(:organization) }
    let(:foreign) { create(:organization) }

    before do
      create(:company_member, :owner, user: user, organization: owned)
      create(:company_member, :manager, user: user, organization: managed)
      create(:company_member, :owner, organization: foreign)
    end

    it "resolves the role in each organization" do
      expect(user.role_in(owned)).to eq("owner")
      expect(user.role_in(managed)).to eq("manager")
      expect(user.role_in(foreign)).to be_nil
      expect(user.role_in(nil)).to be_nil
    end

    it "answers owner_of? and manager_of? only for the user's own organizations" do
      expect(user.owner_of?(owned)).to be(true)
      expect(user.manager_of?(owned)).to be(false)
      expect(user.manager_of?(managed)).to be(true)
      expect(user.owner_of?(managed)).to be(false)
      expect(user.owner_of?(foreign)).to be(false)
      expect(user.manager_of?(foreign)).to be(false)
    end

    it "loads the roles with a single query" do
      fresh_user = described_class.find(user.id)
      queries = 0
      counter = ->(*, payload) { queries += 1 unless payload[:name] == "SCHEMA" }

      ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
        fresh_user.role_in(owned)
        fresh_user.owner_of?(managed)
        fresh_user.manager_of?(foreign)
      end

      expect(queries).to eq(1)
    end

    it "reloads the roles after #reload" do
      other = create(:organization)
      expect(user.role_in(other)).to be_nil

      create(:company_member, :manager, user: user, organization: other)

      expect(user.reload.role_in(other)).to eq("manager")
    end
  end
end
