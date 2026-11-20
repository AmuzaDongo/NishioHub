import { User, Category, Service, Review, Booking, Conversation, Message } from "@/types";

// Mock Users
export const users: User[] = [
  {
    id: "user1",
    name: "Alex Morgan",
    email: "alex@nishioHub.com",
    avatar: "/images/Mentor.jpg",
    bio: "Senior Software Engineer with 10+ years of experience in full-stack development. Passionate about mentoring junior developers and helping them grow in their careers.",
    role: "mentor",
    skills: ["React", "Node.js", "TypeScript", "System Design"],
    location: "San Francisco, CA",
    hourlyRate: 150,
    joinedAt: new Date("2023-01-15"),
    rating: 4.9
  },
  {
    id: "admin1",
    name: "Admin User",
    email: "admin@nishioHub.com",
    avatar: "/images/admin-avatar.jpg",
    bio: "Platform administrator with full system access",
    role: "admin",
    joinedAt: new Date("2023-01-01")
  },
  {
    id: "user2",
    name: "Sarah Chen",
    email: "sarah@nishioHub.com",
    avatar: "/images/SarahChen.jpg",
    bio: "Product Manager at a Fortune 500 company. I help people transition into product roles and develop the skills needed to succeed in product management.",
    role: "mentor",
    skills: ["Product Strategy", "User Research", "Roadmapping", "Agile"],
    location: "New York, NY",
    hourlyRate: 180,
    joinedAt: new Date("2023-02-20"),
    rating: 4.8
  },
  {
    id: "user3",
    name: "David Wilson",
    email: "david@nishioHub.com",
    avatar: "/images/DavidWilson.jpg",
    bio: "UX Designer with expertise in creating intuitive and accessible interfaces. I love sharing my knowledge on design systems and user research methodologies.",
    role: "mentor",
    skills: ["UI/UX Design", "Figma", "User Testing", "Design Systems"],
    location: "Austin, TX",
    hourlyRate: 120,
    joinedAt: new Date("2023-03-10"),
    rating: 5.0
  },
  {
    id: "user4",
    name: "Maya Patel",
    email: "maya@nishioHub.com",
    avatar: "/images/DataScientist.jpg",
    bio: "Data Scientist specializing in machine learning and AI. I help professionals understand complex ML concepts and apply them to real-world problems.",
    role: "mentor",
    skills: ["Machine Learning", "Python", "Data Analysis", "AI Ethics"],
    location: "Seattle, WA",
    hourlyRate: 200,
    joinedAt: new Date("2023-01-05"),
    rating: 4.7
  },
  {
    id: "user5",
    name: "Carlos Rodriguez",
    email: "carlos@example.com",
    avatar: "/images/CarlosRodriguez.jpg",
    bio: "Looking to improve my coding skills and transition into a full-time developer role.",
    role: "mentee",
    joinedAt: new Date("2023-04-15")
  },
  {
    id: "user6",
    name: "Emma Johnson",
    email: "emma@example.com",
    avatar: "/images/Marketing.jpg",
    bio: "Marketing professional interested in learning product management skills.",
    role: "mentee",
    joinedAt: new Date("2023-05-20")
  }
];

// Mock Categories
export const categories: Category[] = [
  {
    id: "cat1",
    name: "Software Development",
    slug: "software-development",
    description: "Learn programming, web development, mobile apps and more",
    iconPath: "/images/Code.jpg",
    topics: ["JavaScript", "React", "Node.js", "Python", "Mobile Development", "DevOps", "System Architecture"]
  },
  {
    id: "cat2",
    name: "Product Management",
    slug: "product-management",
    description: "Master the art of building great products and leading teams",
    iconPath: "/images/ProductManagement.jpg",
    topics: ["Product Strategy", "Roadmapping", "User Research", "Agile", "Product Analytics", "Go-to-Market"]
  },
  {
    id: "cat3",
    name: "UX/UI Design",
    slug: "design",
    description: "Create beautiful, functional designs that users love",
    iconPath: "/images/Design.jpg",
    topics: ["UI Design", "UX Research", "Design Systems", "Figma", "Interaction Design", "Usability Testing"]
  },
  {
    id: "cat4",
    name: "Data Science",
    slug: "data-science",
    description: "Learn data analysis, machine learning and AI",
    iconPath: "/images/DataScience.jpg",
    topics: ["Machine Learning", "Python", "Data Analysis", "AI", "Data Visualization", "Big Data", "Statistics"]
  },
  {
    id: "cat5",
    name: "Career Development",
    slug: "career",
    description: "Get guidance on career transitions, interviews and growth",
    iconPath: "/images/Career.jpg",
    topics: ["Resume Building", "Interview Prep", "Career Transition", "Leadership", "Negotiation", "Personal Branding"]
  }
];

// Mock Services
export const services: Service[] = [
  {
    id: "serv1",
    title: "1:1 React & Frontend Architecture Mentorship",
    description: "Personalized mentoring sessions focused on React best practices, state management, performance optimization, and building scalable frontend architectures. Get code reviews and guidance on your specific projects.",
    mentorId: "user1",
    categoryId: "cat1",
    price: 120,
    duration: 60,
    tags: ["React", "Frontend", "JavaScript", "Architecture"],
    imageUrl: "/images/ReactMentoring.jpg",
    createdAt: new Date("2023-03-01"),
    updatedAt: new Date("2023-03-01"),
    rating: 4.9,
    reviewCount: 24
  },
  {
    id: "serv2",
    title: "Product Management Career Coaching",
    description: "I'll help you break into product management or advance in your PM career. Sessions include portfolio reviews, interview prep, and strategic advice to help you land your dream product role.",
    mentorId: "user2",
    categoryId: "cat2",
    price: 150,
    duration: 45,
    tags: ["Product Management", "Career", "Interviews"],
    imageUrl: "/images/ProductManagement.jpg",
    createdAt: new Date("2023-03-05"),
    updatedAt: new Date("2023-03-05"),
    rating: 4.8,
    reviewCount: 18
  },
  {
    id: "serv3",
    title: "UX Design Portfolio Review & Feedback",
    description: "Get detailed feedback on your UX/UI design portfolio from an experienced designer. I'll help you highlight your strengths, identify improvement areas, and structure your portfolio to impress potential employers.",
    mentorId: "user3",
    categoryId: "cat3",
    price: 90,
    duration: 60,
    tags: ["UX", "Portfolio", "Design", "Feedback"],
    imageUrl: "/images/UXDesign.jpg",
    createdAt: new Date("2023-03-10"),
    updatedAt: new Date("2023-03-10"),
    rating: 5.0,
    reviewCount: 12
  },
  {
    id: "serv4",
    title: "Introduction to Machine Learning with Python",
    description: "One-on-one sessions where I'll guide you through the fundamentals of machine learning using Python. We'll cover key algorithms, data preprocessing, and model evaluation techniques with practical examples.",
    mentorId: "user4",
    categoryId: "cat4",
    price: 180,
    duration: 90,
    tags: ["Machine Learning", "Python", "AI", "Data Science"],
    imageUrl: "/images/MachineLearning.jpg",
    createdAt: new Date("2023-03-15"),
    updatedAt: new Date("2023-03-15"),
    rating: 4.7,
    reviewCount: 15
  },
  {
    id: "serv5",
    title: "Node.js Backend Development Mentorship",
    description: "Learn how to build robust, scalable backend systems with Node.js. I'll help you with architecture decisions, database design, API development, and deployment strategies.",
    mentorId: "user1",
    categoryId: "cat1",
    price: 140,
    duration: 60,
    tags: ["Node.js", "Backend", "API", "Databases"],
    imageUrl: "/images/NodejsBackend.jpg",
    createdAt: new Date("2023-03-20"),
    updatedAt: new Date("2023-03-20"),
    rating: 4.8,
    reviewCount: 9
  },
  {
    id: "serv6",
    title: "Data Visualization and Storytelling",
    description: "Master the art of turning complex data into compelling visual stories. Learn how to use tools like Tableau and D3.js to create impactful dashboards and presentations that drive decisions.",
    mentorId: "user4",
    categoryId: "cat4",
    price: 160,
    duration: 60,
    tags: ["Data Visualization", "Tableau", "Storytelling", "Analytics"],
    imageUrl: "/images/DataVisualization.jpg",
    createdAt: new Date("2023-03-25"),
    updatedAt: new Date("2023-03-25"),
    rating: 4.9,
    reviewCount: 7
  }
];

// Mock Reviews
export const reviews: Review[] = [
  {
    id: "rev1",
    serviceId: "serv1",
    menteeId: "user5",
    rating: 5,
    comment: "Alex is an incredible mentor! His deep knowledge of React and frontend architecture helped me solve problems I'd been stuck on for weeks. Highly recommend!",
    createdAt: new Date("2023-04-05")
  },
  {
    id: "rev2",
    serviceId: "serv1",
    menteeId: "user6",
    rating: 5,
    comment: "Amazing session with Alex. He explained complex concepts in a way that was easy to understand and gave me practical tips I could immediately apply to my project.",
    createdAt: new Date("2023-04-10")
  },
  {
    id: "rev3",
    serviceId: "serv2",
    menteeId: "user5",
    rating: 4,
    comment: "Sarah provided valuable insights for my PM interview preparation. Her feedback on my product case study was particularly helpful.",
    createdAt: new Date("2023-04-15")
  },
  {
    id: "rev4",
    serviceId: "serv3",
    menteeId: "user6",
    rating: 5,
    comment: "David transformed my design portfolio. His suggestions were spot-on and I've already received more interview requests since implementing his feedback.",
    createdAt: new Date("2023-04-20")
  }
];

// Mock Bookings
export const bookings: Booking[] = [
  {
    id: "book1",
    serviceId: "serv1",
    menteeId: "user5",
    mentorId: "user1",
    status: "completed",
    scheduledAt: new Date("2023-04-05T14:00:00"),
    duration: 60,
    totalPrice: 120,
    paymentStatus: "completed",
    createdAt: new Date("2023-04-01"),
    updatedAt: new Date("2023-04-05")
  },
  {
    id: "book2",
    serviceId: "serv2",
    menteeId: "user6",
    mentorId: "user2",
    status: "confirmed",
    scheduledAt: new Date("2023-05-10T10:00:00"),
    duration: 45,
    totalPrice: 150,
    paymentStatus: "completed",
    createdAt: new Date("2023-05-01"),
    updatedAt: new Date("2023-05-01")
  },
  {
    id: "book3",
    serviceId: "serv4",
    menteeId: "user5",
    mentorId: "user4",
    status: "pending",
    scheduledAt: new Date("2023-05-15T16:00:00"),
    duration: 90,
    totalPrice: 180,
    paymentStatus: "pending",
    createdAt: new Date("2023-05-05"),
    updatedAt: new Date("2023-05-05")
  }
];

// Mock Messages
export const messages: Message[] = [
  {
    id: "msg1",
    senderId: "user5",
    receiverId: "user1",
    content: "Hi Alex, I'm looking forward to our session tomorrow. I've prepared some questions about React hooks.",
    read: true,
    createdAt: new Date("2023-04-04T09:30:00")
  },
  {
    id: "msg2",
    senderId: "user1",
    receiverId: "user5",
    content: "Great! Feel free to share any specific code examples you'd like to discuss. See you tomorrow!",
    read: true,
    createdAt: new Date("2023-04-04T10:15:00")
  },
  {
    id: "msg3",
    senderId: "user6",
    receiverId: "user2",
    content: "Hello Sarah, I'm interested in your Product Management coaching. Do you have any availability next week?",
    read: true,
    createdAt: new Date("2023-04-28T14:20:00")
  },
  {
    id: "msg4",
    senderId: "user2",
    receiverId: "user6",
    content: "Hi Emma, I have slots available on Tuesday and Thursday afternoons. Would either of those work for you?",
    read: false,
    createdAt: new Date("2023-04-28T16:45:00")
  }
];

// Mock Conversations
export const conversations: Conversation[] = [
  {
    id: "conv1",
    participants: ["user5", "user1"],
    lastMessageAt: new Date("2023-04-04T10:15:00"),
    messages: [messages[0], messages[1]]
  },
  {
    id: "conv2",
    participants: ["user6", "user2"],
    lastMessageAt: new Date("2023-04-28T16:45:00"),
    messages: [messages[2], messages[3]]
  }
];