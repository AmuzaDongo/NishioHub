import { PageLoader } from '@/components/loaders/PageLoader';
import { useState } from "react";
import { useNavigate, Navigate, useParams } from "react-router-dom";
import { z } from "zod";
import { zodResolver } from "@hookform/resolvers/zod";
import { useForm } from "react-hook-form";
import { Button } from "@/components/ui/button";
import {
  Form,
  FormControl,
  FormDescription,
  FormField,
  FormItem,
  FormLabel,
  FormMessage,
} from "@/components/ui/form";
import { Textarea } from "@/components/ui/textarea";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { MainLayout } from "@/components/layout/main-layout";
import { useAuth } from "@/lib/auth-context";
import { useServices } from "@/lib/services-context";
import { Star } from "lucide-react";

const reviewSchema = z.object({
  rating: z.number().min(1, {
    message: "Please select a rating from 1 to 5 stars.",
  }).max(5),
  comment: z.string().min(10, {
    message: "Please provide a comment with at least 10 characters.",
  }).max(500, {
    message: "Comment cannot exceed 500 characters.",
  }),
});

export default function LeaveReviewPage() {
  const { bookingId } = useParams<{ bookingId: string }>();
  const { user } = useAuth();
  const { getBookingById, submitReview, getMentorById, getServiceById, isLoading: dataLoading } = useServices();
  const navigate = useNavigate();
  const [success, setSuccess] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [hoveredStar, setHoveredStar] = useState<number | null>(null);
  
  // Get booking information
  const booking = bookingId ? getBookingById(bookingId) : null;
  const mentor = booking?.mentorId ? getMentorById(booking.mentorId) : null;
  const service = booking?.serviceId ? getServiceById(booking.serviceId) : null;
  
  const form = useForm<z.infer<typeof reviewSchema>>({
    resolver: zodResolver(reviewSchema),
    defaultValues: {
      rating: 0,
      comment: "",
    },
  });
  
  // If not logged in or no booking found, redirect
  if (!user) {
    return <Navigate to="/login" />;
  } else if (dataLoading) {
    return (
      <MainLayout>
        <div className="container py-12 text-center">
          <PageLoader label="Loading booking..."/>
        </div>
      </MainLayout>
    );
  } else if (!booking || !mentor || !service) {
    return <Navigate to="/bookings" />;
  } else if (String(booking.menteeId) !== String(user.id)) {
    return <Navigate to="/bookings" />;
  } else if (booking.status !== "completed") {
    return <Navigate to="/bookings" />;
  } else if (booking.hasReview) {
    return <Navigate to="/bookings" />;
  }
  
  const onSubmit = async (values: z.infer<typeof reviewSchema>) => {
    setSuccess(false);
    setError(null);
    setIsLoading(true);
    
    try {
      await submitReview({
        bookingId,
        mentorId: mentor.id,
        menteeId: user.id,
        serviceId: service.id,
        rating: values.rating,
        comment: values.comment,
      });
      
      setSuccess(true);
      
      // Navigate back to bookings after delay
      setTimeout(() => {
        navigate("/bookings");
      }, 2000);
    } catch (error) {
      setError("Failed to submit review. Please try again.");
      console.error(error);
    } finally {
      setIsLoading(false);
    }
  };
  
  return (
    <MainLayout>
      <div className="container py-8 max-w-2xl">
        <div className="mb-8">
          <h1 className="text-2xl font-bold mb-1">Leave a Review</h1>
          <p className="text-muted-foreground">
            Share your experience with {mentor.name} for the {service.title} service.
          </p>
        </div>
        
        {success && (
          <Alert className="mb-6 bg-green-50 text-green-700 border-green-200">
            <AlertTitle>Success!</AlertTitle>
            <AlertDescription>Your review has been submitted successfully. Thank you for your feedback!</AlertDescription>
          </Alert>
        )}
        
        {error && (
          <Alert variant="destructive" className="mb-6">
            <AlertTitle>Error</AlertTitle>
            <AlertDescription>{error}</AlertDescription>
          </Alert>
        )}
        
        <div className="bg-white rounded-lg border p-6">
          <Form {...form}>
            <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-6">
              <FormField
                control={form.control}
                name="rating"
                render={({ field }) => (
                  <FormItem className="space-y-3">
                    <FormLabel>Rating</FormLabel>
                    <FormControl>
                      <div className="flex items-center">
                        {[1, 2, 3, 4, 5].map((star) => (
                          <button
                            key={star}
                            type="button"
                            className="p-1 focus:outline-none"
                            onClick={() => field.onChange(star)}
                            onMouseEnter={() => setHoveredStar(star)}
                            onMouseLeave={() => setHoveredStar(null)}
                          >
                            <Star
                              className={`h-8 w-8 ${
                                (hoveredStar !== null
                                  ? star <= hoveredStar
                                  : star <= field.value)
                                  ? "text-yellow-400 fill-yellow-400"
                                  : "text-gray-300"
                              } transition-colors`}
                            />
                          </button>
                        ))}
                        <span className="ml-2 text-lg font-medium">
                          {field.value > 0 ? field.value : ""}
                        </span>
                      </div>
                    </FormControl>
                    <FormDescription>
                      Click on a star to rate your experience.
                    </FormDescription>
                    <FormMessage />
                  </FormItem>
                )}
              />
              
              <FormField
                control={form.control}
                name="comment"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Your Review</FormLabel>
                    <FormControl>
                      <Textarea
                        placeholder="Share your experience with this mentor. What did you learn? Would you recommend them to others?"
                        className="min-h-[150px]"
                        {...field}
                      />
                    </FormControl>
                    <FormDescription>
                      Your review helps other mentees make informed decisions.
                    </FormDescription>
                    <FormMessage />
                  </FormItem>
                )}
              />
              
              <div className="flex gap-4">
                <Button type="submit" disabled={isLoading || success}>
                  {isLoading ? "Submitting..." : "Submit Review"}
                </Button>
                <Button 
                  type="button" 
                  variant="outline" 
                  onClick={() => navigate("/bookings")}
                  disabled={isLoading || success}
                >
                  Cancel
                </Button>
              </div>
            </form>
          </Form>
        </div>
      </div>
    </MainLayout>
  );
}