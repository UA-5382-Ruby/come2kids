require 'faker'

Faker::Config.locale = 'uk'

puts "Cleaning database..."
EventTranslation.delete_all
OrganizationTranslation.delete_all
Event.delete_all
CompanyMember.delete_all
Organization.delete_all
Category.delete_all
User.where.not(platform_role: "moderator").delete_all

puts "Creating roles..."
Role.find_or_create_by!(key: "owner") do |r|
  r.name_uk = "Власник"
  r.name_en = "Owner"
end

Role.find_or_create_by!(key: "manager") do |r|
  r.name_uk = "Менеджер"
  r.name_en = "Manager"
end

puts "Creating categories..."
categories_data = [
  { slug: "education", name_uk: "Освіта", name_en: "Education", position: 1 },
  { slug: "sports", name_uk: "Спорт", name_en: "Sports", position: 2 },
  { slug: "arts", name_uk: "Мистецтво", name_en: "Arts", position: 3 },
  { slug: "technology", name_uk: "Технології", name_en: "Technology", position: 4 },
  { slug: "music", name_uk: "Музика", name_en: "Music", position: 5 }
]

categories_data.each do |data|
  Category.find_or_create_by!(slug: data[:slug]) do |c|
    c.name_uk = data[:name_uk]
    c.name_en = data[:name_en]
    c.position = data[:position]
  end
end

puts "Creating moderator..."
moderator = User.find_or_create_by!(email: "moderator@come2kids.dev") do |u|
  u.first_name = "Модератор"
  u.last_name = "Платформи"
  u.password = ENV.fetch("MODERATOR_PASSWORD", "Moderator123")
  u.platform_role = "moderator"
  u.is_active = true
  u.email_confirmed_at = Time.current
end

puts "Creating demo organization owner..."
owner = User.find_or_create_by!(email: "owner@demo.com") do |u|
  u.first_name = "Олександр"
  u.last_name = "Демо"
  u.password = "Owner12345"
  u.platform_role = "user"
  u.is_active = true
  u.email_confirmed_at = Time.current
end

puts "Creating demo organization..."
org = Organization.find_or_create_by!(slug: "demo-events") do |o|
  o.contact_email = "contact@demo.com"
  o.status = "approved"
  o.approved_at = Time.current
  o.approved_by = moderator
end

CompanyMember.find_or_create_by!(
  organization: org,
  user: owner,
  role_id: Role::OWNER_ID
) do |cm|
  cm.added_by = nil
end

OrganizationTranslation.find_or_create_by!(organization: org, locale: "uk") do |t|
  t.name = "Демо Події"
  t.description = "Тестова організація для демонстрації платформи"
end

OrganizationTranslation.find_or_create_by!(organization: org, locale: "en") do |t|
  t.name = "Demo Events"
  t.description = "Test organization for platform demonstration"
end

puts "Creating demo events..."
education_category = Category.find_by(slug: "education")
arts_category = Category.find_by(slug: "arts")

events_data = [
  {
    title_uk: "Дитячий табір програмування",
    title_en: "Kids Programming Camp",
    description_uk: "Тижневий табір для дітей 10-14 років з основами Python",
    description_en: "Week-long camp for kids aged 10-14 with Python basics",
    category: education_category,
    start_at: 2.weeks.from_now,
    end_at: 2.weeks.from_now + 7.days,
    location_type: "offline",
    city: "Київ",
    address: "вул. Хрещатик, 1"
  },
  {
    title_uk: "Онлайн курс малювання",
    title_en: "Online Drawing Course",
    description_uk: "Курс акварелі для початківців",
    description_en: "Watercolor course for beginners",
    category: arts_category,
    start_at: 3.days.from_now,
    end_at: 3.days.from_now + 2.hours,
    location_type: "online",
    online_url: "https://zoom.us/demo"
  }
]

events_data.each do |data|
  event = Event.find_or_create_by!(
    organization: org,
    start_at: data[:start_at]
  ) do |e|
    e.category = data[:category]
    e.created_by = owner
    e.end_at = data[:end_at]
    e.time_zone = "Europe/Kyiv"
    e.location_type = data[:location_type]
    e.city = data[:city]
    e.address = data[:address]
    e.online_url = data[:online_url]
    e.status = "published"
    e.published_at = Time.current
  end

  EventTranslation.find_or_create_by!(event: event, locale: "uk") do |t|
    t.title = data[:title_uk]
    t.description = data[:description_uk]
  end

  EventTranslation.find_or_create_by!(event: event, locale: "en") do |t|
    t.title = data[:title_en]
    t.description = data[:description_en]
  end
end

puts "Generating sample data with Faker..."
2.times do |i|
  owner_email = "faker_owner_#{i + 1}@demo.com"
  faker_owner = User.find_or_create_by!(email: owner_email) do |u|
    u.first_name = Faker::Name.first_name
    u.last_name = Faker::Name.last_name
    u.password = "Password123"
    u.platform_role = "user"
    u.is_active = true
    u.email_confirmed_at = Time.current
  end

  org_slug = "faker-org-#{i + 1}"
  faker_org = Organization.find_or_create_by!(slug: org_slug) do |o|
    o.contact_email = "contact_#{i + 1}@demo.com"
    o.phone = Faker::PhoneNumber.phone_number
    o.status = "approved"
    o.approved_at = Time.current
    o.approved_by = moderator
  end

  CompanyMember.find_or_create_by!(
    organization: faker_org,
    user: faker_owner,
    role_id: Role::OWNER_ID
  ) do |cm|
    cm.added_by = moderator
  end

  OrganizationTranslation.find_or_create_by!(
    organization: faker_org,
    locale: "uk"
  ) do |t|
    t.name = Faker::Company.name
    t.description = Faker::Company.catch_phrase
  end

  2.times do |j|
    event_start = Faker::Time.forward(days: 30 + j * 10)
    event_end = event_start + rand(2..4).hours
    location_type = %w[offline online].sample

    event = Event.find_or_create_by!(
      organization: faker_org,
      start_at: event_start
    ) do |e|
      e.category = Category.all.sample
      e.created_by = faker_owner
      e.end_at = event_end
      e.time_zone = "Europe/Kyiv"
      e.location_type = location_type
      if location_type == "offline"
        e.city = Faker::Address.city
        e.address = Faker::Address.street_address
      else
        e.online_url = Faker::Internet.url
      end
      e.status = "published"
      e.published_at = Time.current
    end

    EventTranslation.find_or_create_by!(event: event, locale: "uk") do |t|
      t.title = Faker::Lorem.sentence(word_count: 4)
      t.description = Faker::Lorem.paragraph(sentence_count: 3)
    end
  end
end

puts "Creating regular user..."
regular_user = User.find_or_create_by!(email: "user@demo.com") do |u|
  u.first_name = "Василь"
  u.last_name = "Користувач"
  u.password = "User12345"
  u.platform_role = "user"
  u.is_active = true
  u.email_confirmed_at = Time.current
end

puts "Seed data created successfully:"
puts "Moderator: #{moderator.email}"
puts "Demo Owner: #{owner.email}"
puts "Demo User: #{regular_user.email}"
puts "Organizations: #{Organization.count} (1 demo + 2 faker)"
puts "Events: #{Event.count} (2 demo + 4 faker)"
puts "Categories: #{Category.count}"
