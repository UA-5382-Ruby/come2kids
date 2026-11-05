require "rails_helper"

RSpec.describe Api::UserBlueprint do
  let(:user) do
    User.new(
      id: 12,
      email: "person@example.com",
      password: "password1",
      first_name: "Ada",
      last_name: "Lovelace",
      phone: "+380501234567",
      preferred_locale: "uk",
      platform_role: "user",
      email_confirmed_at: Time.utc(2026, 11, 3, 10, 0, 0),
      created_at: Time.utc(2026, 11, 1, 8, 30, 0),
      updated_at: Time.utc(2026, 11, 2, 9, 45, 0)
    )
  end

  it "serializes only public fields and formats timestamps in UTC" do
    result = described_class.render_as_hash(user)

    expect(result).to include(
      id: 12,
      email: "person@example.com",
      first_name: "Ada",
      last_name: "Lovelace",
      email_confirmed_at: "2026-11-03T10:00:00.000Z",
      created_at: "2026-11-01T08:30:00.000Z",
      updated_at: "2026-11-02T09:45:00.000Z"
    )
    expect(result).not_to include(:password, :password_digest, :deleted_at)
  end
end
