require "rails_helper"

RSpec.describe RefreshToken do
  let(:user) { create(:user) }
  let(:issued) { described_class.issue_for(user) }
  let(:token) { issued.first }
  let(:raw_token) { issued.last }

  describe ".issue_for" do
    it "stores a digest instead of the raw token" do
      expect(token.token_digest).not_to eq(raw_token)
    end

    it "expires after the configured TTL" do
      expect(token.expires_at).to be_within(1.minute).of(described_class::TTL.from_now)
    end
  end

  describe ".find_by_raw" do
    it "finds the token by its raw value" do
      expect(described_class.find_by_raw(raw_token)).to eq(token)
    end

    it "returns nil for a blank value" do
      expect(described_class.find_by_raw(nil)).to be_nil
    end
  end

  describe "#rotate!" do
    it "revokes the old token and links its successor" do
      new_token, = token.rotate!

      expect(token.reload).to have_attributes(revoked?: true, replaced_by: new_token)
    end

    it "returns a raw token for the successor" do
      new_token, new_raw = token.rotate!

      expect(described_class.find_by_raw(new_raw)).to eq(new_token)
    end

    it "returns nil when the token is already revoked" do
      token.revoke!

      expect(token.rotate!).to be_nil
    end
  end

  describe ".active" do
    it "excludes revoked and expired tokens" do
      revoked, = described_class.issue_for(user)
      revoked.revoke!
      expired, = described_class.issue_for(user)
      expired.update!(expires_at: 1.minute.ago)

      expect(described_class.active.where(user: user)).to contain_exactly(token)
    end
  end

  describe ".revoke_all_for" do
    it "revokes every active token of the user" do
      token
      described_class.issue_for(user)

      expect { described_class.revoke_all_for(user) }
        .to change { described_class.active.where(user: user).count }.from(2).to(0)
    end
  end
end
