# frozen_string_literal: true

# Role ids are a fixed schema contract (see Role), but the test database is loaded from
# schema.rb without seeds, so the rows are created on first use and reused afterwards.
FactoryBot.define do
  factory :role do
    owner

    trait :owner do
      id { Role::OWNER_ID }
      key { Role::OWNER }
      name_uk { "Власник" }
      name_en { "Owner" }
    end

    trait :manager do
      id { Role::MANAGER_ID }
      key { Role::MANAGER }
      name_uk { "Менеджер" }
      name_en { "Manager" }
    end

    initialize_with { Role.find_or_initialize_by(id: id) }
  end
end
