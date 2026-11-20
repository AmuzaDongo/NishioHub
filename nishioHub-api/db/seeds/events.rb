# Optional development examples. Run with:
# bin/rails runner db/seeds/events.rb
raise "Sample events are for development only" unless Rails.env.development?
organizer = User.joins(:role).find_by(roles: { name: "mentor" })
raise "Seed or create a mentor before loading sample events" unless organizer
start_day = Time.current.in_time_zone("Africa/Kampala").beginning_of_day
[
  ["Becoming a Software Engineer", "Learn the path, skills and opportunities in software engineering.", "talk", 7, 10, 2, "Online (Zoom)"],
  ["Introduction to Coding for Young Learners", "A hands-on session to learn the basics of coding using Scratch and Python.", "workshop", 14, 9, 3, "Nakasero Primary School"],
  ["STEM Innovation Challenge", "Build a simple solution to a real community problem.", "challenge", 23, 10, 24 * 13, "Online"],
  ["Girls in Tech Mentorship Session", "An interactive session with women in technology to inspire and guide learners.", "mentorship", 28, 14, 2, "Online (Zoom)"]
].each do |title, description, category, days, hour, duration, location|
  Event.find_or_create_by!(title: title, organizer: organizer) do |event|
    event.description = description
    event.category = category
    event.starts_at = (start_day + days.days).change(hour: hour)
    event.ends_at = event.starts_at + duration.hours
    event.location = location
  end
end
puts "Development sample events ready."
