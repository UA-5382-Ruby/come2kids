# frozen_string_literal: true

require "rails_helper"

RSpec.describe JwtService do
  include ActiveSupport::Testing::TimeHelpers

  let(:user) { create(:user) }
  let(:token) { described_class.encode(user) }

  def sign(payload, key: described_class::SECRET_KEY, algorithm: described_class::ALGORITHM)
    JWT.encode(payload, key, algorithm)
  end

  describe ".decode" do
    it "returns the user id as sub" do
      expect(described_class.decode(token)["sub"]).to eq(user.id.to_s)
    end

    it "includes the issuer" do
      expect(described_class.decode(token)["iss"]).to eq(described_class::ISSUER)
    end

    it "raises ExpiredToken once the access ttl has passed" do
      token

      travel described_class::ACCESS_TTL + 1.second do
        expect { described_class.decode(token) }.to raise_error(JwtService::ExpiredToken)
      end
    end

    it "raises InvalidToken for a tampered signature" do
      expect { described_class.decode("#{token}x") }.to raise_error(JwtService::InvalidToken)
    end

    it "raises InvalidToken for the none algorithm" do
      none_token = sign({ sub: user.id.to_s, iss: described_class::ISSUER, exp: 1.hour.from_now.to_i },
        key: nil, algorithm: "none")

      expect { described_class.decode(none_token) }.to raise_error(JwtService::InvalidToken)
    end

    it "raises InvalidToken for another issuer" do
      foreign_token = sign({ sub: user.id.to_s, iss: "evil", exp: 1.hour.from_now.to_i })

      expect { described_class.decode(foreign_token) }.to raise_error(JwtService::InvalidToken)
    end

    it "raises InvalidToken when sub is missing" do
      anonymous_token = sign({ iss: described_class::ISSUER, exp: 1.hour.from_now.to_i })

      expect { described_class.decode(anonymous_token) }.to raise_error(JwtService::InvalidToken)
    end
  end
end
