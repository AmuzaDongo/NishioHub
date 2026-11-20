import {
  createContext,
  useContext,
  ReactNode,
  useState,
  useEffect,
  useCallback,
} from "react";
import { Service, Category, Review, Booking, User, AvailabilitySlot } from "@/types";
import api from "@/lib/axios";
import { useAuth } from "./auth-context";

interface ServicesContextType {
  services: Service[];
  categories: Category[];
  mentors: User[];
  reviews: Review[];
  bookings: Booking[];
  isLoading: boolean;
  error: string | null;
  getServiceById: (id: string) => Service | undefined;
  getServicesInCategory: (categoryId: string) => Service[];
  getServicesByMentor: (mentorId: string) => Service[];
  getReviewsForMentor: (mentorId: string) => Review[];
  getReviewsForService: (serviceId: string) => Review[];
  getBookingsForUser: () => Booking[];
  createBooking: (
    serviceId: string,
    scheduledAt: Date,
    availabilitySlotId?: number
  ) => Promise<boolean>;
  cancelBooking: (bookingId: string) => Promise<boolean>;
  getBookingById: (id: string) => Booking | undefined;
  getMentorById: (id: string) => User | undefined;
  getAvailability: (mentorId: string) => Promise<AvailabilitySlot[]>;
  createService: (
    data: Omit<Service, "id" | "createdAt" | "updatedAt" | "rating" | "reviewCount">
  ) => Promise<string>;
  submitReview: (data: {
    bookingId: string;
    mentorId: string;
    menteeId: string;
    serviceId: string;
    rating: number;
    comment: string;
  }) => Promise<boolean>;
  searchServices: (query: string) => Service[];
  refresh: () => Promise<void>;
}

const ServicesContext = createContext<ServicesContextType | undefined>(undefined);

export function ServicesProvider({ children }: { children: ReactNode }) {
  const [services, setServices] = useState<Service[]>([]);
  const [categories, setCategories] = useState<Category[]>([]);
  const [mentors, setMentors] = useState<User[]>([]);
  const [reviews, setReviews] = useState<Review[]>([]);
  const [bookings, setBookings] = useState<Booking[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const { user } = useAuth();

  const load = useCallback(async () => {
    setIsLoading(true);
    setError(null);

    try {
      const [servicesResponse, categoriesResponse, mentorsResponse, reviewsResponse] =
        await Promise.all([
          api.get("/services"),
          api.get("/categories"),
          api.get("/mentors"),
          api.get("/reviews"),
        ]);

      setServices(servicesResponse.data.services ?? []);
      setCategories(
        (categoriesResponse.data ?? []).map((category: Category) => ({
          ...category,
          id: String(category.id),
        }))
      );
      setMentors(mentorsResponse.data.mentors ?? []);
      setReviews(reviewsResponse.data.reviews ?? []);

      if (user?.access_token) {
        const bookingsResponse = await api.get("/bookings");
        setBookings(bookingsResponse.data.bookings ?? []);
      } else {
        setBookings([]);
      }
    } catch (err) {
      console.error("Failed to load mentor data:", err);
      setError(err instanceof Error ? err.message : "Failed to load mentor data");
    } finally {
      setIsLoading(false);
    }
  }, [user?.access_token]);

  useEffect(() => {
    load();
  }, [load]);

  const getServiceById = (id: string) =>
    services.find((service) => String(service.id) === String(id));

  const getServicesInCategory = (categoryId: string) =>
    services.filter((service) => String(service.categoryId) === String(categoryId));

  const getServicesByMentor = (mentorId: string) =>
    services.filter((service) => String(service.mentorId) === String(mentorId));

  const getReviewsForMentor = (mentorId: string) =>
    reviews.filter((review) => String(review.mentorId) === String(mentorId));

  const getReviewsForService = (serviceId: string) =>
    reviews.filter((review) => String(review.serviceId) === String(serviceId));

  const getBookingsForUser = () => bookings;

  const getBookingById = (id: string) =>
    bookings.find((booking) => String(booking.id) === String(id));

  const getMentorById = (id: string) =>
    mentors.find((mentor) => String(mentor.id) === String(id));

  const getAvailability = async (mentorId: string): Promise<AvailabilitySlot[]> => {
    const response = await api.get(`/mentors/${mentorId}/availability`);
    return response.data.availability ?? [];
  };

  const createBooking = async (
    serviceId: string,
    scheduledAt: Date,
    availabilitySlotId?: number
  ): Promise<boolean> => {
    try {
      const response = await api.post("/bookings", {
        service_id: serviceId,
        scheduled_at: scheduledAt.toISOString(),
        availability_slot_id: availabilitySlotId,
      });
      setBookings((previous) => [response.data, ...previous]);
      return true;
    } catch (err) {
      console.error("Booking failed:", err);
      return false;
    }
  };

  const cancelBooking = async (bookingId: string): Promise<boolean> => {
    try {
      const response = await api.patch(`/bookings/${bookingId}`, { status: "cancelled" });
      setBookings((previous) =>
        previous.map((booking) =>
          String(booking.id) === String(bookingId) ? response.data : booking
        )
      );
      return true;
    } catch (err) {
      console.error("Cancel booking failed:", err);
      return false;
    }
  };

  const createService = async (
    data: Omit<Service, "id" | "createdAt" | "updatedAt" | "rating" | "reviewCount">
  ): Promise<string> => {
    const response = await api.post("/services", {
      title: data.title,
      description: data.description,
      category_id: data.categoryId,
      price: data.price,
      duration: data.duration,
      tags: data.tags,
    });
    setServices((previous) => [response.data, ...previous]);
    return String(response.data.id);
  };

  const submitReview = async (data: {
    bookingId: string;
    mentorId: string;
    menteeId: string;
    serviceId: string;
    rating: number;
    comment: string;
  }): Promise<boolean> => {
    const response = await api.post(`/bookings/${data.bookingId}/review`, {
      rating: data.rating,
      comment: data.comment,
    });
    setReviews((previous) => [response.data, ...previous]);
    setBookings((previous) =>
      previous.map((booking) =>
        String(booking.id) === String(data.bookingId)
          ? { ...booking, hasReview: true }
          : booking
      )
    );
    return true;
  };

  const searchServices = (query: string) => {
    if (!query.trim()) return services;

    const lowerCaseQuery = query.toLowerCase();
    return services.filter(
      (service) =>
        service.title.toLowerCase().includes(lowerCaseQuery) ||
        service.description.toLowerCase().includes(lowerCaseQuery) ||
        service.tags.some((tag) => tag.toLowerCase().includes(lowerCaseQuery))
    );
  };

  return (
    <ServicesContext.Provider
      value={{
        services,
        categories,
        mentors,
        reviews,
        bookings,
        isLoading,
        error,
        getServiceById,
        getServicesInCategory,
        getServicesByMentor,
        getReviewsForMentor,
        getReviewsForService,
        getBookingsForUser,
        createBooking,
        cancelBooking,
        getBookingById,
        getMentorById,
        getAvailability,
        createService,
        submitReview,
        searchServices,
        refresh: load,
      }}
    >
      {children}
    </ServicesContext.Provider>
  );
}

export function useServices() {
  const context = useContext(ServicesContext);
  if (context === undefined) {
    throw new Error("useServices must be used within a ServicesProvider");
  }
  return context;
}
