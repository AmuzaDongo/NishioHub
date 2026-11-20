roles = %w[super_admin admin moderator mentor mentee founder organization user]
roles.each { |name| Role.find_or_create_by!(name: name) }

categories = [
  {
    name: "Software Development",
    slug: "software-development",
    description: "Learn programming, web development, mobile apps and more",
    icon_path: "/images/Code.jpg",
    position: 1, is_active: true, image_alt: "Software Development",
    topics: ["JavaScript", "React", "Node.js", "Python", "Mobile Development", "DevOps", "System Architecture"]
  },
  {
    name: "Product Management",
    slug: "product-management",
    description: "Master the art of building great products and leading teams",
    icon_path: "/images/ProductManagement.jpg",
    position: 2, is_active: true, image_alt: "Product Management",
    topics: ["Product Strategy", "Roadmapping", "User Research", "Agile", "Product Analytics", "Go-to-Market"]
  },
  {
    name: "UX/UI Design",
    slug: "design",
    description: "Create beautiful, functional designs that users love",
    icon_path: "/images/Design.jpg",
    position: 3, is_active: true, image_alt: "UX/UI Design",
    topics: ["UI Design", "UX Research", "Design Systems", "Figma", "Interaction Design", "Usability Testing"]
  },
  {
    name: "Data Science",
    slug: "data-science",
    description: "Learn data analysis, machine learning and AI",
    icon_path: "/images/DataScience.jpg",
    position: 4, is_active: true, image_alt: "Data Science",
    topics: ["Machine Learning", "Python", "Data Analysis", "AI", "Data Visualization", "Big Data", "Statistics"]
  },
  {
    name: "Career Development",
    slug: "career",
    description: "Get guidance on career transitions, interviews and growth",
    icon_path: "/images/Career.jpg",
    position: 5, is_active: false, image_alt: "Career Development",
    topics: ["Resume Building", "Interview Prep", "Career Transition", "Leadership", "Negotiation", "Personal Branding"]
  }
]

categories.each do |attrs|
  category = Category.find_or_initialize_by(name: attrs[:name])
  category.assign_attributes(attrs)
  category.save!

  seed_image = {
    "Software Development" => "software-development.jpg",
    "UX/UI Design" => "design.jpg"
  }[category.name]

  if seed_image && !category.image.attached?
    path = Rails.root.join("db/seed_assets/categories", seed_image)
    category.image.attach(io: File.open(path), filename: seed_image, content_type: "image/jpeg") if File.exist?(path)
  end
end

skills = [
  "React", "Node.js", "TypeScript", "System Design",
  "Product Strategy", "User Research", "Roadmapping", "Agile",
  "UI/UX Design", "Figma", "User Testing", "Design Systems",
  "Machine Learning", "Python", "Data Analysis", "AI Ethics"
]
skills.each { |name| Skill.find_or_create_by!(name: name) }

puts "Seeded #{Role.count} roles, #{Category.count} categories, #{Skill.count} skills."

def seed_user(email:, full_name:, role_name:, password: "password123", verified: true)
  user = User.find_or_initialize_by(email: email)
  if user.new_record?
    user.full_name = full_name
    user.password = password
    user.role = Role.find_by(name: role_name)
    user.is_verified = verified
    user.save!
  end
  user
end

seed_user(email: "admin@nishiohub.com", full_name: "Platform Admin", role_name: "admin")

mentors = [
  {
    email: "alex@nishiohub.com", full_name: "Alex Morgan", title: "Senior Software Engineer",
    years: 10, rate: 150, timezone: "America/Los_Angeles", phone: "+15550101", gender: "male", birth_date: "1990-01-15",
    address: "1 Market St", city: "San Francisco", country: "US", avatar: "/images/Mentor.jpg",
    skills: ["React", "Node.js", "TypeScript", "System Design"],
    languages: ["English", "Spanish"],
    education: [{ degree: "B.S. Computer Science", institution: "Stanford University", year: "2014" }],
    experience: [{ title: "Senior Software Engineer", company: "Stripe", period: "2019 - Present", description: "Leads frontend platform work and mentors engineers across the org." }],
    bio: "Senior Software Engineer with 10+ years of experience in full-stack development. Passionate about mentoring junior developers and helping them grow in their careers."
  },
  {
    email: "sarah@nishiohub.com", full_name: "Sarah Chen", title: "Product Lead",
    years: 8, rate: 180, timezone: "America/New_York", phone: "+15550102", gender: "female", birth_date: "1992-03-20",
    address: "5th Ave", city: "New York", country: "US", avatar: "/images/SarahChen.jpg",
    skills: ["Product Strategy", "User Research", "Roadmapping", "Agile"],
    languages: ["English", "Mandarin"],
    education: [{ degree: "MBA", institution: "Wharton", year: "2016" }],
    experience: [{ title: "Product Lead", company: "Google", period: "2020 - Present", description: "Owns product strategy for a developer platform used by millions." }],
    bio: "Product Manager at a Fortune 500 company. I help people transition into product roles and develop the skills needed to succeed in product management."
  },
  {
    email: "david@nishiohub.com", full_name: "David Wilson", title: "UX Design Lead",
    years: 7, rate: 120, timezone: "America/Chicago", phone: "+15550103", gender: "male", birth_date: "1991-07-10",
    address: "100 Congress Ave", city: "Austin", country: "US", avatar: "/images/DavidWilson.jpg",
    skills: ["UI/UX Design", "Figma", "User Testing", "Design Systems"],
    languages: ["English"],
    education: [{ degree: "B.F.A. Interaction Design", institution: "RISD", year: "2017" }],
    experience: [{ title: "UX Design Lead", company: "Figma", period: "2021 - Present", description: "Builds design systems and runs usability research for core product teams." }],
    bio: "UX Designer with expertise in creating intuitive and accessible interfaces. I love sharing my knowledge on design systems and user research methodologies."
  },
  {
    email: "maya@nishiohub.com", full_name: "Maya Patel", title: "Staff Data Scientist",
    years: 9, rate: 200, timezone: "America/Los_Angeles", phone: "+15550104", gender: "female", birth_date: "1989-11-05",
    address: "400 Pine St", city: "Seattle", country: "US", avatar: "/images/DataScientist.jpg",
    skills: ["Machine Learning", "Python", "Data Analysis", "AI Ethics"],
    languages: ["English", "Hindi"],
    education: [{ degree: "M.S. Data Science", institution: "UC Berkeley", year: "2015" }],
    experience: [{ title: "Staff Data Scientist", company: "Amazon", period: "2018 - Present", description: "Leads applied ML projects and mentors data scientists." }],
    bio: "Data Scientist specializing in machine learning and AI. I help professionals understand complex ML concepts and apply them to real-world problems."
  }
]

mentors.each do |attrs|
  user = seed_user(email: attrs[:email], full_name: attrs[:full_name], role_name: "mentor")

  profile = user.profile || user.build_profile
  profile.assign_attributes(
    phone_number: attrs[:phone], gender: attrs[:gender], birth_date: attrs[:birth_date],
    address: attrs[:address], city: attrs[:city], country: attrs[:country],
    profile_picture: attrs[:avatar], bio: attrs[:bio]
  )
  profile.save!

  mentor_profile = user.mentor_profile || user.build_mentor_profile
  mentor_profile.assign_attributes(
    title: attrs[:title], years_of_experience: attrs[:years], hourly_rate: attrs[:rate],
    languages: attrs[:languages], education: attrs[:education], experience: attrs[:experience],
    bio: attrs[:bio], currency: "USD", timezone: attrs[:timezone] || "UTC",
    accepting_bookings: true, is_verified: true, is_published: true
  )
  mentor_profile.save!
  mentor_profile.skills = attrs[:skills].map { |name| Skill.find_or_create_by!(name: name) }

  seed_avatar = { "alex@nishiohub.com" => "alex.jpg", "sarah@nishiohub.com" => "sarah.jpg" }[attrs[:email]]
  if seed_avatar && !mentor_profile.avatar.attached?
    path = Rails.root.join("db/seed_assets", seed_avatar)
    mentor_profile.avatar.attach(io: File.open(path), filename: seed_avatar, content_type: "image/jpeg") if File.exist?(path)
  end
end

mentees = [
  { email: "carlos@example.com", full_name: "Carlos Rodriguez", phone: "+15550105", gender: "male", birth_date: "1998-04-15", address: "10 Main St", city: "Miami", country: "US", avatar: "/images/CarlosRodriguez.jpg", bio: "Looking to improve my coding skills and transition into a full-time developer role." },
  { email: "emma@example.com", full_name: "Emma Johnson", phone: "+15550106", gender: "female", birth_date: "1997-05-20", address: "20 Oak St", city: "Chicago", country: "US", avatar: "/images/Marketing.jpg", bio: "Marketing professional interested in learning product management skills." }
]

mentees.each do |attrs|
  user = seed_user(email: attrs[:email], full_name: attrs[:full_name], role_name: "mentee")
  profile = user.profile || user.build_profile
  profile.assign_attributes(
    phone_number: attrs[:phone], gender: attrs[:gender], birth_date: attrs[:birth_date],
    address: attrs[:address], city: attrs[:city], country: attrs[:country],
    profile_picture: attrs[:avatar], bio: attrs[:bio]
  )
  profile.save!
end

puts "Seeded #{User.where(role: Role.find_by(name: 'mentor')).count} mentors and #{User.where(role: Role.find_by(name: 'mentee')).count} mentees."

services = [
  {
    mentor_email: "alex@nishiohub.com", category: "Software Development",
    title: "1:1 React & Frontend Architecture Mentorship",
    description: "Personalized mentoring sessions focused on React best practices, state management, performance optimization, and building scalable frontend architectures. Get code reviews and guidance on your specific projects.",
    price: 120, duration: 60, tags: ["React", "Frontend", "JavaScript", "Architecture"],
    image_url: "/images/ReactMentoring.jpg"
  },
  {
    mentor_email: "sarah@nishiohub.com", category: "Product Management",
    title: "Product Management Career Coaching",
    description: "I'll help you break into product management or advance in your PM career. Sessions include portfolio reviews, interview prep, and strategic advice to help you land your dream product role.",
    price: 150, duration: 45, tags: ["Product Management", "Career", "Interviews"],
    image_url: "/images/ProductManagement.jpg"
  },
  {
    mentor_email: "david@nishiohub.com", category: "UX/UI Design",
    title: "UX Design Portfolio Review & Feedback",
    description: "Get detailed feedback on your UX/UI design portfolio from an experienced designer. I'll help you highlight your strengths, identify improvement areas, and structure your portfolio to impress potential employers.",
    price: 90, duration: 60, tags: ["UX", "Portfolio", "Design", "Feedback"],
    image_url: "/images/UXDesign.jpg"
  },
  {
    mentor_email: "maya@nishiohub.com", category: "Data Science",
    title: "Introduction to Machine Learning with Python",
    description: "One-on-one sessions where I'll guide you through the fundamentals of machine learning using Python. We'll cover key algorithms, data preprocessing, and model evaluation techniques with practical examples.",
    price: 180, duration: 90, tags: ["Machine Learning", "Python", "AI", "Data Science"],
    image_url: "/images/MachineLearning.jpg"
  },
  {
    mentor_email: "alex@nishiohub.com", category: "Software Development",
    title: "Node.js Backend Development Mentorship",
    description: "Learn how to build robust, scalable backend systems with Node.js. I'll help you with architecture decisions, database design, API development, and deployment strategies.",
    price: 140, duration: 60, tags: ["Node.js", "Backend", "API", "Databases"],
    image_url: "/images/NodejsBackend.jpg"
  },
  {
    mentor_email: "maya@nishiohub.com", category: "Data Science",
    title: "Data Visualization and Storytelling",
    description: "Master the art of turning complex data into compelling visual stories. Learn how to use tools like Tableau and D3.js to create impactful dashboards and presentations that drive decisions.",
    price: 160, duration: 60, tags: ["Data Visualization", "Tableau", "Storytelling", "Analytics"],
    image_url: "/images/DataVisualization.jpg"
  }
]

services.each do |attrs|
  mentor = User.find_by(email: attrs[:mentor_email])
  category = Category.find_by(name: attrs[:category])
  service = Service.find_or_initialize_by(mentor: mentor, title: attrs[:title])
  service.assign_attributes(
    category: category, description: attrs[:description], price: attrs[:price],
    duration: attrs[:duration], tags: attrs[:tags], image_url: attrs[:image_url], is_active: true
  )
  service.save!
end

User.where(role: Role.find_by(name: "mentor")).find_each do |mentor|
  next if mentor.availability_slots.exists?

  (1..5).each do |day|
    [9, 11, 14].each do |hour|
      starts_at = Time.zone.now.beginning_of_day + day.days + hour.hours
      mentor.availability_slots.find_or_create_by!(starts_at: starts_at) do |slot|
        slot.ends_at = starts_at + 1.hour
        slot.is_booked = false
      end
    end
  end
end

puts "Seeded #{Service.count} services and #{AvailabilitySlot.count} availability slots."

carlos = User.find_by(email: "carlos@example.com")
emma = User.find_by(email: "emma@example.com")
alex = User.find_by(email: "alex@nishiohub.com")
sarah = User.find_by(email: "sarah@nishiohub.com")
david = User.find_by(email: "david@nishiohub.com")
maya = User.find_by(email: "maya@nishiohub.com")

react_service = Service.find_by(mentor: alex, title: "1:1 React & Frontend Architecture Mentorship")
pm_service = Service.find_by(mentor: sarah, title: "Product Management Career Coaching")
ux_service = Service.find_by(mentor: david, title: "UX Design Portfolio Review & Feedback")
ml_service = Service.find_by(mentor: maya, title: "Introduction to Machine Learning with Python")

def seed_booking(service:, mentee:, mentor:, status:, scheduled_at:, payment_status:)
  booking = Booking.find_or_initialize_by(service: service, mentee: mentee, scheduled_at: scheduled_at)
  if booking.new_record?
    booking.assign_attributes(
      mentor: mentor, status: status, duration: service.duration,
      total_price: service.price, payment_status: payment_status
    )
    booking.save!
  end
  booking
end

completed_one = seed_booking(
  service: react_service, mentee: carlos, mentor: alex, status: "completed",
  scheduled_at: 3.days.ago.change(hour: 14, min: 0, sec: 0), payment_status: "completed"
)
completed_two = seed_booking(
  service: pm_service, mentee: emma, mentor: sarah, status: "completed",
  scheduled_at: 5.days.ago.change(hour: 10, min: 0, sec: 0), payment_status: "completed"
)
seed_booking(
  service: ml_service, mentee: carlos, mentor: maya, status: "confirmed",
  scheduled_at: 2.days.from_now.change(hour: 16, min: 0, sec: 0), payment_status: "completed"
)
seed_booking(
  service: ux_service, mentee: emma, mentor: david, status: "pending",
  scheduled_at: 5.days.from_now.change(hour: 11, min: 0, sec: 0), payment_status: "pending"
)

Review.find_or_create_by!(booking: completed_one) do |review|
  review.service = react_service
  review.mentor = alex
  review.mentee = carlos
  review.rating = 5
  review.comment = "Alex is an incredible mentor! His deep knowledge of React and frontend architecture helped me solve problems I'd been stuck on for weeks. Highly recommend!"
end

Review.find_or_create_by!(booking: completed_two) do |review|
  review.service = pm_service
  review.mentor = sarah
  review.mentee = emma
  review.rating = 4
  review.comment = "Sarah provided valuable insights for my PM interview preparation. Her feedback on my product case study was particularly helpful."
end

puts "Seeded #{Booking.count} bookings and #{Review.count} reviews."
