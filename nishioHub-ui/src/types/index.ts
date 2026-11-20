export interface User {
  id: string;
  name: string;
  email: string;
  avatar: string;
  bio: string;
  role: 'mentor' | 'mentee' | 'admin';
  skills?: string[];
  location?: string;
  hourlyRate?: number;
  rating?: number;
  title?: string;
  isVerified?: boolean;
  yearsOfExperience?: number;
  languages?: string[];
  education?: { degree: string; institution: string; year: string }[];
  experience?: { title: string; company: string; period: string; description: string }[];
  reviewCount?: number;
  acceptingBookings?: boolean;
  full_name?: string;
  profile_picture?: string;
  joinedAt?: string | Date;
}

export interface Category {
  id: string;
  name: string;
  slug: string;
  description?: string;
  iconPath?: string | null;
  topics?: string[];
  image_url?: string | null;
  image_metadata?: {
    alt?: string;
    content_type?: string;
    byte_size?: number;
  } | null;
  position?: number;
  is_active?: boolean;
  parent_id?: number | null;
  service_count?: number;
  created_at?: string;
  updated_at?: string;
}

export interface Service {
  id: string;
  title: string;
  description: string;
  mentorId: string;
  categoryId: string;
  price: number;
  duration: number; // in minutes
  tags: string[];
  imageUrl?: string;
  createdAt: Date;
  updatedAt: Date;
  rating?: number;
  reviewCount?: number;
  image?: string;
  shortDescription?: string;
  category?: string;
  mentor?: User;
}

export interface Review {
  id: string;
  serviceId: string;
  menteeId: string;
  rating: number;
  comment: string;
  createdAt: Date;
  mentorId?: string;
  userId?: string;
  date?: string;
  title?: string;
  content?: string;
  mentee?: { id: string; name: string; full_name?: string; avatar?: string };
}

export interface Booking {
  id: string;
  serviceId: string;
  menteeId: string;
  mentorId: string;
  status: 'pending' | 'confirmed' | 'completed' | 'cancelled';
  scheduledAt: Date;
  duration: number;
  totalPrice: number;
  paymentStatus: 'pending' | 'completed' | 'refunded';
  createdAt: Date;
  updatedAt: Date;
  hasReview?: boolean;
  service?: Service;
  mentor?: User;
  mentee?: { id: string; name: string; full_name?: string; avatar?: string };
}

export interface AvailabilitySlot {
  id: number;
  mentorId: number;
  startsAt: string;
  endsAt: string;
  isBooked: boolean;
}

export interface Message {
  id: string;
  senderId: string;
  receiverId: string;
  content: string;
  read: boolean;
  createdAt: Date;
}

export interface Conversation {
  id: string;
  participants: string[];
  lastMessageAt: Date;
  messages?: Message[];
}
export interface MentorProfileService {
  id: number;
  title: string;
  price: number;
  duration: number;
  is_active: boolean;
}

export interface MentorProfile {
  id: number;
  user_id: number;
  name: string;
  headline: string;
  bio: string | null;
  hourly_rate: number | null;
  currency: string;
  languages: string[];
  years_of_experience: number;
  timezone: string;
  skills: string[];
  services: MentorProfileService[];
  availability: AvailabilitySlot[];
  avatar_url: string | null;
  email: string;
  is_verified: boolean;
  is_published: boolean;
  accepting_bookings: boolean;
  rating: number | null;
  review_count: number;
  joined_at: string;
  created_at: string;
  updated_at: string;
  is_active: boolean;
}

export interface MentorProfileUpdate {
  name?: string;
  headline?: string;
  bio?: string;
  hourly_rate?: number;
  currency?: string;
  languages?: string[];
  years_of_experience?: number;
  timezone?: string;
  skills?: string[];
  accepting_bookings?: boolean;
}
