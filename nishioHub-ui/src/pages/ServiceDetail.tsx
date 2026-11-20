import { useEffect, useState } from "react";
import { useParams, useNavigate, Link } from "react-router-dom";
import { format } from "date-fns";
import { Calendar } from "@/components/ui/calendar";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import { MainLayout } from "@/components/layout/main-layout";
import { useAuth } from "@/lib/auth-context";
import { useServices } from "@/lib/services-context";
import { useMessaging } from "@/lib/messaging-context";
import { Calendar as CalendarIcon, Clock, MessageSquare, Star } from "lucide-react";
import { AvailabilitySlot } from "@/types";

export default function ServiceDetailPage() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const { user, isAuthenticated } = useAuth();
  const { services, getServiceById, categories, getReviewsForService, createBooking, getMentorById, getAvailability } = useServices();
  const { getOrCreateConversation } = useMessaging();
  
  const service = getServiceById(id || "");
  const mentor = service ? (service.mentor || getMentorById(String(service.mentorId))) : null;
  const category = service ? categories.find(c => c.id === service.categoryId) : null;
  const reviews = service ? getReviewsForService(service.id) : [];
  
  const [selectedDate, setSelectedDate] = useState<Date | undefined>(undefined);
  const [timeSlot, setTimeSlot] = useState<string | null>(null);
  const [isBookingModalOpen, setIsBookingModalOpen] = useState(false);
  const [isConfirmationOpen, setIsConfirmationOpen] = useState(false);
  const [isBookingInProgress, setIsBookingInProgress] = useState(false);
  const [availability, setAvailability] = useState<AvailabilitySlot[]>([]);

  useEffect(() => {
    if (!mentor) return;
    getAvailability(String(mentor.id))
      .then(setAvailability)
      .catch((error) => console.error("Failed to load availability:", error));
  }, [mentor, getAvailability]);
  
  // Redirect if service not found
  if (!service || !mentor) {
    return <div>Service not found</div>;
  }
  
  const sameDay = (a: Date, b: Date) =>
    a.getFullYear() === b.getFullYear() &&
    a.getMonth() === b.getMonth() &&
    a.getDate() === b.getDate();

  const availableTimeSlots = selectedDate
    ? availability
        .filter((slot) => !slot.isBooked && sameDay(new Date(slot.startsAt), selectedDate))
        .map((slot) => ({
          id: slot.id,
          label: format(new Date(slot.startsAt), "h:mm a"),
          startsAt: slot.startsAt,
        }))
    : [];
  
  const handleBookSession = async () => {
    if (!isAuthenticated) {
      navigate("/login");
      return;
    }
    
    if (!selectedDate || !timeSlot) {
      return;
    }
    
    setIsBookingInProgress(true);
    
    const selectedSlot = availableTimeSlots.find((slot) => slot.label === timeSlot);
    if (!selectedSlot) return;

    try {
      const success = await createBooking(
        String(service.id),
        new Date(selectedSlot.startsAt),
        selectedSlot.id
      );
      
      if (success) {
        setIsBookingModalOpen(false);
        setIsConfirmationOpen(true);
      }
    } catch (error) {
      console.error("Booking failed:", error);
    } finally {
      setIsBookingInProgress(false);
    }
  };
  
  const handleContactMentor = async () => {
    if (!isAuthenticated) {
      navigate("/login");
      return;
    }
    
    const conversationId = await getOrCreateConversation(mentor.id);
    if (conversationId) navigate(`/messages/${conversationId}`);
  };
  
  return (
    <MainLayout>
      <div className="container py-8">
        <div className="grid md:grid-cols-3 gap-8">
          {/* Main Content */}
          <div className="md:col-span-2 space-y-6">
            <div>
              <Link to="/services" className="text-sm text-muted-foreground hover:text-primary">
                ← Back to all services
              </Link>
              <h1 className="text-3xl font-bold mt-4 mb-2">{service.title}</h1>
              {category && (
                <div className="flex items-center space-x-2 mb-4">
                  <span className="text-sm text-muted-foreground">Category:</span>
                  <Link 
                    to={`/categories/${category.slug}`} 
                    className="bg-primary/10 text-primary text-sm px-3 py-1 rounded-full hover:bg-primary/20 transition-colors"
                  >
                    {category.name}
                  </Link>
                </div>
              )}
            </div>
            
            <div className="aspect-video bg-muted rounded-lg"></div>
            
            <Tabs defaultValue="description">
              <TabsList>
                <TabsTrigger value="description">Description</TabsTrigger>
                <TabsTrigger value="reviews">
                  Reviews ({reviews.length})
                </TabsTrigger>
              </TabsList>
              <TabsContent value="description" className="pt-6">
                <div className="prose max-w-none">
                  <p className="whitespace-pre-line">{service.description}</p>
                </div>
                
                <div className="mt-8">
                  <h3 className="font-semibold text-lg mb-2">What You'll Get</h3>
                  <ul className="space-y-2">
                    <li className="flex items-start">
                      <span className="mr-2 mt-1 text-primary">✓</span>
                      <span>Personalized {service.duration}-minute 1:1 session</span>
                    </li>
                    <li className="flex items-start">
                      <span className="mr-2 mt-1 text-primary">✓</span>
                      <span>Expert guidance tailored to your specific needs</span>
                    </li>
                    <li className="flex items-start">
                      <span className="mr-2 mt-1 text-primary">✓</span>
                      <span>Follow-up resources and recommendations</span>
                    </li>
                    <li className="flex items-start">
                      <span className="mr-2 mt-1 text-primary">✓</span>
                      <span>Option to record the session for future reference</span>
                    </li>
                  </ul>
                </div>
                
                <div className="mt-8">
                  <h3 className="font-semibold text-lg mb-2">Tags</h3>
                  <div className="flex flex-wrap gap-2">
                    {service.tags.map(tag => (
                      <span 
                        key={tag} 
                        className="px-3 py-1 bg-muted text-muted-foreground text-sm rounded-full"
                      >
                        {tag}
                      </span>
                    ))}
                  </div>
                </div>
              </TabsContent>
              <TabsContent value="reviews" className="pt-6 space-y-6">
                {reviews.length > 0 ? (
                  <>
                    <div className="flex items-center space-x-2 mb-6">
                      <div className="bg-primary/10 text-primary font-medium px-3 py-1 rounded-full flex items-center">
                        <Star className="h-4 w-4 mr-1 fill-current" />
                        <span>{service.rating?.toFixed(1)}</span>
                      </div>
                      <span className="text-muted-foreground">({reviews.length} reviews)</span>
                    </div>
                    {reviews.map(review => {
                      const reviewMentee = review.mentee;
                      return (
                        <div key={review.id} className="border-b pb-6">
                          <div className="flex justify-between items-start">
                            <div className="flex items-center space-x-3">
                              <Avatar>
                                <AvatarImage src={reviewMentee?.avatar} />
                                <AvatarFallback>{reviewMentee?.name?.charAt(0) || "?"}</AvatarFallback>
                              </Avatar>
                              <div>
                                <p className="font-medium">{reviewMentee?.name}</p>
                                <p className="text-sm text-muted-foreground">
                                  {/* {review.createdAt.toLocaleDateString()} */}
                                </p>
                              </div>
                            </div>
                            <div className="flex">
                              {[1, 2, 3, 4, 5].map(star => (
                                <Star 
                                  key={star} 
                                  className={`h-4 w-4 ${star <= review.rating ? "text-yellow-400 fill-current" : "text-gray-300"}`}
                                />
                              ))}
                            </div>
                          </div>
                          <p className="mt-3">{review.comment}</p>
                        </div>
                      );
                    })}
                  </>
                ) : (
                  <div className="text-center py-12">
                    <p className="text-muted-foreground mb-4">No reviews yet for this service.</p>
                  </div>
                )}
              </TabsContent>
            </Tabs>
          </div>
          
          {/* Sidebar */}
          <div>
            <div className="sticky top-20">
              <Card>
                <CardContent className="p-6 space-y-6">
                  <div className="flex items-center space-x-4">
                    <Avatar className="h-12 w-12">
                      <AvatarImage src={mentor.avatar} alt={mentor.name} />
                      <AvatarFallback>{mentor.name.charAt(0)}</AvatarFallback>
                    </Avatar>
                    <div>
                      <Link to={`/profile/${mentor.id}`} className="font-medium hover:text-primary">
                        {mentor.name}
                      </Link>
                      <p className="text-sm text-muted-foreground">{mentor.location}</p>
                    </div>
                  </div>
                  
                  <div className="space-y-2">
                    <div className="flex justify-between">
                      <span className="text-muted-foreground">Price</span>
                      <span className="font-bold">${service.price}</span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-muted-foreground">Duration</span>
                      <span>{service.duration} min</span>
                    </div>
                    {service.rating && (
                      <div className="flex justify-between">
                        <span className="text-muted-foreground">Rating</span>
                        <span className="flex items-center">
                          <Star className="h-4 w-4 text-yellow-400 fill-current mr-1" />
                          {service.rating.toFixed(1)} ({service.reviewCount})
                        </span>
                      </div>
                    )}
                  </div>
                  
                  <div className="space-y-3">
                    <Dialog open={isBookingModalOpen} onOpenChange={setIsBookingModalOpen}>
                      <DialogTrigger asChild>
                        <Button className="w-full">Book a Session</Button>
                      </DialogTrigger>
                      <DialogContent className="sm:max-w-[500px]">
                        <DialogHeader>
                          <DialogTitle>Book a Session</DialogTitle>
                          <DialogDescription>
                            Select a date and time that works for you to book your session with {mentor.name}.
                          </DialogDescription>
                        </DialogHeader>
                        <div className="grid gap-6 py-4">
                          <div className="grid gap-2">
                            <div className="flex items-center gap-2">
                              <CalendarIcon className="h-4 w-4 text-muted-foreground" />
                              <span className="font-medium">Select Date</span>
                            </div>
                            <Calendar
                              mode="single"
                              selected={selectedDate}
                              onSelect={setSelectedDate}
                              className="border rounded-md"
                              disabled={(date) => {
                                // Disable past dates and limit future dates to 60 days
                                const today = new Date();
                                today.setHours(0, 0, 0, 0);
                                const maxDate = new Date();
                                maxDate.setDate(maxDate.getDate() + 60);
                                return date < today || date > maxDate;
                              }}
                            />
                          </div>
                          
                          <div className="grid gap-2">
                            <div className="flex items-center gap-2">
                              <Clock className="h-4 w-4 text-muted-foreground" />
                              <span className="font-medium">Select Time</span>
                            </div>
                            {selectedDate ? (
                              availableTimeSlots.length > 0 ? (
                                <div className="grid grid-cols-3 gap-2">
                                  {availableTimeSlots.map((slot) => (
                                    <Button
                                      key={slot.id}
                                      variant={timeSlot === slot.label ? "default" : "outline"}
                                      onClick={() => setTimeSlot(slot.label)}
                                      size="sm"
                                    >
                                      {slot.label}
                                    </Button>
                                  ))}
                                </div>
                              ) : (
                                <p className="text-center text-muted-foreground py-6">
                                  No available time slots for this date.
                                </p>
                              )
                            ) : (
                              <p className="text-center text-muted-foreground py-6">
                                Please select a date first.
                              </p>
                            )}
                          </div>
                        </div>
                        <DialogFooter>
                          <div className="flex w-full justify-between items-center">
                            <div>
                              <p className="font-medium">${service.price}</p>
                              <p className="text-sm text-muted-foreground">{service.duration} min session</p>
                            </div>
                            <Button 
                              onClick={handleBookSession}
                              disabled={!selectedDate || !timeSlot || isBookingInProgress}
                            >
                              {isBookingInProgress ? "Booking..." : "Confirm Booking"}
                            </Button>
                          </div>
                        </DialogFooter>
                      </DialogContent>
                    </Dialog>
                    
                    <Button variant="outline" className="w-full" onClick={handleContactMentor}>
                      <MessageSquare className="h-4 w-4 mr-2" />
                      Contact Mentor
                    </Button>
                  </div>
                </CardContent>
              </Card>
            </div>
          </div>
        </div>
        
        {/* Related Services */}
        <section className="mt-16">
          <h2 className="text-2xl font-bold mb-6">More from {mentor.name}</h2>
          <div className="grid md:grid-cols-3 gap-6">
            {/* Just show other services from this mentor */}
            {services
              .filter(s => String(s.mentorId) === String(mentor.id) && String(s.id) !== String(service.id))
              .slice(0, 3)
              .map(relatedService => (
                <Card key={relatedService.id} className="overflow-hidden">
                  <div className="aspect-video bg-muted"></div>
                  <CardContent className="p-5">
                    <Link to={`/services/${relatedService.id}`}>
                      <h3 className="font-semibold text-lg mb-2 hover:text-primary transition-colors">
                        {relatedService.title}
                      </h3>
                    </Link>
                    <p className="text-sm text-muted-foreground line-clamp-2 mb-4">
                      {relatedService.description}
                    </p>
                    <div className="flex justify-between items-center">
                      <div>
                        <span className="text-lg font-bold">${relatedService.price}</span>
                        <span className="text-muted-foreground text-sm">/{relatedService.duration} min</span>
                      </div>
                      <Button asChild variant="secondary" size="sm">
                        <Link to={`/services/${relatedService.id}`}>View Details</Link>
                      </Button>
                    </div>
                  </CardContent>
                </Card>
              ))}
          </div>
        </section>
      </div>
      
      {/* Booking Confirmation Dialog */}
      <Dialog open={isConfirmationOpen} onOpenChange={setIsConfirmationOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Booking Confirmed!</DialogTitle>
            <DialogDescription>
              Your session with {mentor.name} has been scheduled.
            </DialogDescription>
          </DialogHeader>
          <div className="py-4">
            <Card>
              <CardContent className="p-4 space-y-3">
                <div className="flex justify-between">
                  <span className="text-muted-foreground">Service</span>
                  <span className="font-medium">{service.title}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-muted-foreground">Date & Time</span>
                  <span className="font-medium">
                    {selectedDate && timeSlot
                      ? `${format(selectedDate, "MMM d, yyyy")} at ${timeSlot}`
                      : ""}
                  </span>
                </div>
                <div className="flex justify-between">
                  <span className="text-muted-foreground">Duration</span>
                  <span>{service.duration} minutes</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-muted-foreground">Price</span>
                  <span className="font-bold">${service.price}</span>
                </div>
              </CardContent>
            </Card>
          </div>
          <DialogFooter className="flex-col sm:flex-col gap-2">
            <Button 
              className="w-full" 
              onClick={() => {
                setIsConfirmationOpen(false);
                navigate("/bookings");
              }}
            >
              View My Bookings
            </Button>
            <Button 
              variant="outline" 
              className="w-full"
              onClick={() => {
                setIsConfirmationOpen(false);
              }}
            >
              Close
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </MainLayout>
  );
}