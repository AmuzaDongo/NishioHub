ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

# Keep password behavior tests fast without changing application hashing settings.
BCrypt::Engine.cost = BCrypt::Engine::MIN_COST

module ActiveSupport
  class TestCase
    parallelize(workers: 1)

    def create_role(name)
      Role.find_or_create_by!(name: name)
    end

    def create_user(role: nil, email: "user@example.com", password: "secret123", full_name: "Test User")
      user = User.new(full_name: full_name, email: email, role: role, phone_number: "+256#{SecureRandom.random_number(1_000_000_000).to_s.rjust(9, '0')}")
      user.password = password
      user.save!
      user
    end

    def auth_headers(user)
      token = JsonWebToken.encode({ sub: user.email, user_id: user.id, auth_version: user.auth_version }, exp: 1.hour.from_now)
      { "Authorization" => "Bearer #{token}" }
    end

    def create_mentor(email: "mentor@example.com", full_name: "Mentor User", title: "Senior Mentor", rate: 100, skills: ["React"], accepting: true)
      role = create_role("mentor")
      user = create_user(role: role, email: email, full_name: full_name)
      profile = user.build_profile(
        phone_number: "+1555#{SecureRandom.random_number(1_000_000).to_s.rjust(6, '0')}",
        gender: "other", birth_date: Date.new(1990, 1, 1), address: "1 Main St",
        city: "Austin", country: "US", profile_picture: "/images/Mentor.jpg", bio: "Mentor bio"
      )
      profile.save!
      mentor_profile = user.build_mentor_profile(
        title: title, years_of_experience: 5, hourly_rate: rate,
        languages: ["English"], education: [], experience: [],
        accepting_bookings: accepting, is_verified: true
      )
      mentor_profile.save!
      mentor_profile.skills = names_to_skills(skills)
      user
    end

    def create_mentee(email: "mentee@example.com", full_name: "Mentee User")
      create_user(role: create_role("mentee"), email: email, full_name: full_name)
    end

    def create_service(mentor:, category: nil, title: "Mentoring Session", price: 100, duration: 60, tags: ["React"])
      category ||= Category.find_or_create_by!(name: "Software Development") do |record|
        record.slug = "software-development"
      end
      Service.create!(
        mentor: mentor, category: category, title: title,
        description: "A detailed mentoring session description for testing.",
        price: price, duration: duration, tags: tags,
        image_url: "/images/ReactMentoring.jpg", is_active: true
      )
    end

    def create_booking(service:, mentee:, mentor:, status: "pending", scheduled_at: 2.days.from_now, payment_status: "pending")
      Booking.create!(
        service: service, mentee: mentee, mentor: mentor, status: status,
        scheduled_at: scheduled_at, duration: service.duration,
        total_price: service.price, payment_status: payment_status
      )
    end

    def names_to_skills(names)
      Array(names).map { |name| Skill.find_or_create_by!(name: name) }
    end
  end
end
