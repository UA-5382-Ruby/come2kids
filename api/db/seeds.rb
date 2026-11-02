puts "Cleaning database..."
EventTranslation.destroy_all
OrganizationTranslation.destroy_all
Event.destroy_all
OrganizationManager.destroy_all
Organization.destroy_all
Category.destroy_all
EmailToken.destroy_all
RefreshToken.destroy_all
User.where.not(platform_role: "moderator").destroy_all

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
  o.owner = owner
  o.contact_email = "contact@demo.com"
  o.status = "approved"
  o.approved_at = Time.current
  o.approved_by = moderator
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
sports_category = Category.find_by(slug: "sports")

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
    title_uk: "Дитячий футбольний турнір",
    title_en: "Kids Football Tournament",
    description_uk: "Щорічний турнір для команд 8-12 років",
    description_en: "Annual tournament for teams aged 8-12",
    category: sports_category,
    start_at: 1.month.from_now,
    end_at: 1.month.from_now + 1.day,
    location_type: "offline",
    city: "Львів",
    address: "Стадіон Арена Львів"
  },
  {
    title_uk: "Онлайн курс малювання",
    title_en: "Online Drawing Course",
    description_uk: "Курс акварелі для початківців",
    description_en: "Watercolor course for beginners",
    category: Category.find_by(slug: "arts"),
    start_at: 3.days.from_now,
    end_at: 3.days.from_now + 2.hours,
    location_type: "online",
    online_url: "https://zoom.us/demo"
  }
]

events_data.each do |data|
  event = Event.find_or_create_by!(
    organization: org,
    created_by: owner,
    start_at: data[:start_at]
  ) do |e|
    e.category = data[:category]
    e.status = "published"
    e.published_at = Time.current
    e.end_at = data[:end_at]
    e.location_type = data[:location_type]
    e.city = data[:city] if data[:city]
    e.address = data[:address] if data[:address]
    e.online_url = data[:online_url] if data[:online_url]
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

puts "Creating demo regular user..."
regular_user = User.find_or_create_by!(email: "user@demo.com") do |u|
  u.first_name = "Vasya"
  u.last_name = "Користувач"
  u.password = "User12345"
  u.platform_role = "user"
  u.is_active = true
  u.email_confirmed_at = Time.current
end

puts "Seed data created successfully!"
puts "Moderator: #{moderator.email} (password: Moderator123)"
puts "Owner: #{owner.email} (password: Owner12345)"
puts "User: #{regular_user.email} (password: User12345)"
puts "Organization: #{org.slug} (#{org.organization_translations.count} translations)"
puts "Events: #{Event.count} (#{EventTranslation.count} translations)"
puts "Categories: #{Category.count}"
