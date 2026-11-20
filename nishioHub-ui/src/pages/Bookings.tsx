import { PageLoader } from '@/components/loaders/PageLoader';
import { BookingSessionContent } from '@/components/booking-session-content';
import { useState } from "react";
import { Link, Navigate, useNavigate } from "react-router-dom";
import { format } from "date-fns";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import {
  Tabs,
  TabsContent,
  TabsList,
  TabsTrigger,
} from "@/components/ui/tabs";
import { Badge } from "@/components/ui/badge";
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
import { Calendar, Clock, MessageSquare, Video, X } from "lucide-react";

export default function BookingsPage() {
  const { user, isLoading: authLoading } = useAuth();
  const { getBookingsForUser, getServiceById, getMentorById, cancelBooking, isLoading } = useServices();
  const navigate = useNavigate();
  const { getOrCreateConversation } = useMessaging();
  const [activeTab, setActiveTab] = useState<"upcoming" | "past">("upcoming");
  const [cancelDialogOpen, setCancelDialogOpen] = useState(false);
  const [selectedBookingId, setSelectedBookingId] = useState<string | null>(null);
  
  // Redirect if user is not logged in
  if (authLoading) return <PageLoader label="Loading bookings…"/>;
  if (!user) {
    return <Navigate to="/login" />;
  }

  if (isLoading) {
    return (
      <MainLayout>
        <div className="container py-12 text-center">
          <PageLoader label="Loading bookings..."/>
        </div>
      </MainLayout>
    );
  }
  
  const allBookings = getBookingsForUser();
  const today = new Date();
  
  const upcomingBookings = allBookings.filter(
    b => new Date(b.scheduledAt) >= today && b.status !== "cancelled"
  );
  
  const pastBookings = allBookings.filter(
    b => new Date(b.scheduledAt) < today || b.status === "cancelled" || b.status === "completed"
  );
  
  // Sort bookings by date
  upcomingBookings.sort((a, b) => 
    new Date(a.scheduledAt).getTime() - new Date(b.scheduledAt).getTime()
  );
  
  pastBookings.sort((a, b) => 
    new Date(b.scheduledAt).getTime() - new Date(a.scheduledAt).getTime()
  );
  
  const handleCancelBooking = (bookingId: string) => {
    setSelectedBookingId(bookingId);
    setCancelDialogOpen(true);
  };
  
  const confirmCancelBooking = async () => {
    if (selectedBookingId) {
      await cancelBooking(selectedBookingId);
    }
    setCancelDialogOpen(false);
    setSelectedBookingId(null);
  };
  
  const handleContactMentor = async (mentorId: string) => {
    const conversationId = await getOrCreateConversation(mentorId);
    if (conversationId) navigate(`/messages/${conversationId}`);
  };
  
  const renderBookingCard = (bookingId: string, mentorId: string, serviceId: string, status: string, date: Date, price: number) => {
    const booking = allBookings.find(item => String(item.id) === String(bookingId));
    const mentor = booking?.mentor || getMentorById(String(mentorId));
    const service = booking?.service || getServiceById(String(serviceId));
    const isPastBooking = new Date(date) < today || status === "completed" || status === "cancelled";
    
    if (!mentor || !service) return null;
    
    return (
      <Card key={bookingId} className="mb-4">
        <CardContent className="p-6">
          <div className="flex flex-col lg:flex-row gap-6">
            <div className="flex-1">
              <div className="flex items-center justify-between">
                <h3 className="text-lg font-semibold">{service.title}</h3>
                <Badge
                  variant={
                    status === "completed" ? "default" :
                    status === "confirmed" ? "success" :
                    status === "pending" ? "warning" : 
                    "destructive"
                  }
                >
                  {status.charAt(0).toUpperCase() + status.slice(1)}
                </Badge>
              </div>
              
              <div className="flex items-center mt-3 mb-4">
                <div className="h-10 w-10 rounded-full bg-muted overflow-hidden mr-3">
                  <img
                    src={mentor.avatar}
                    alt={mentor.name}
                    className="h-full w-full object-cover"
                  />
                </div>
                <div>
                  <div className="font-medium">{mentor.name}</div>
                  <div className="text-sm text-muted-foreground">{mentor.skills?.[0]}</div>
                </div>
              </div>
              
              <div className="grid grid-cols-2 gap-y-2 text-sm">
                <div className="flex items-center text-muted-foreground">
                  <Calendar className="h-4 w-4 mr-2" />
                  Date
                </div>
                <div>{format(date, "MMMM d, yyyy")}</div>
                
                <div className="flex items-center text-muted-foreground">
                  <Clock className="h-4 w-4 mr-2" />
                  Time
                </div>
                <div>
                  {format(date, "h:mm a")}
                </div>
                
                <div className="flex items-center text-muted-foreground">
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    width="16"
                    height="16"
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    strokeWidth="2"
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    className="mr-2"
                  >
                    <circle cx="12" cy="12" r="10" />
                    <polyline points="12 6 12 12 16 14" />
                  </svg>
                  Duration
                </div>
                <div>{service.duration} minutes</div>
              </div>
            </div>
            
            <div className="lg:w-48 flex flex-col">
              <div className="text-center mb-4">
                <div className="text-2xl font-bold">${price}</div>
                <div className="text-sm text-muted-foreground">
                  {isPastBooking && status === "completed" ? "Completed" : "Total Price"}
                </div>
              </div>
              
              <div className="mt-auto space-y-2">
                {!isPastBooking && status !== "cancelled" && (
                  <>
                    <Button className="w-full" variant="outline" asChild>
                      <Link to={`/session/${bookingId}`}>
                        <Video className="h-4 w-4 mr-2" />
                        Join Session
                      </Link>
                    </Button>
                    
                    <Button 
                      onClick={() => handleContactMentor(mentorId)}
                      className="w-full"
                      variant="outline"
                    >
                      <MessageSquare className="h-4 w-4 mr-2" />
                      Message
                    </Button>
                    
                    <Button
                      onClick={() => handleCancelBooking(bookingId)}
                      className="w-full"
                      variant="destructive"
                    >
                      <X className="h-4 w-4 mr-2" />
                      Cancel
                    </Button>
                  </>
                )}
                
                {isPastBooking && status !== "cancelled" && status !== "completed" && (
                  <Button className="w-full" variant="default" asChild>
                    <Link to={`/review/${serviceId}`}>
                      Leave Review
                    </Link>
                  </Button>
                )}
                
                <BookingSessionContent id={Number(bookingId)} />
                {isPastBooking && status === "completed" && (
                  <Button className="w-full" variant="outline" asChild>
                    <Link to={`/services/${serviceId}`}>
                      Book Again
                    </Link>
                  </Button>
                )}
              </div>
            </div>
          </div>
        </CardContent>
      </Card>
    );
  };
  
  return (
    <MainLayout>
      <div className="container py-8">
        <div className="flex flex-col md:flex-row md:items-center md:justify-between mb-8">
          <div>
            <h1 className="text-3xl font-bold">My Bookings</h1>
            <p className="text-muted-foreground">Manage your mentorship sessions</p>
          </div>
          <div className="mt-4 md:mt-0">
            <Button asChild>
              <Link to="/services">Find New Mentors</Link>
            </Button>
          </div>
        </div>

        <Tabs value={activeTab} onValueChange={(v) => setActiveTab(v as "upcoming" | "past")} className="w-full">
          <TabsList className="grid w-full grid-cols-2 mb-6">
            <TabsTrigger value="upcoming">
              Upcoming ({upcomingBookings.length})
            </TabsTrigger>
            <TabsTrigger value="past">
              Past ({pastBookings.length})
            </TabsTrigger>
          </TabsList>
          
          <TabsContent value="upcoming">
            {upcomingBookings.length > 0 ? (
              upcomingBookings.map(booking => renderBookingCard(
                booking.id,
                booking.mentorId,
                booking.serviceId,
                booking.status,
                new Date(booking.scheduledAt),
                booking.totalPrice
              ))
            ) : (
              <div className="text-center py-16 bg-muted/30 rounded-lg">
                <h3 className="font-medium mb-2">No upcoming bookings</h3>
                <p className="text-muted-foreground mb-6">
                  You don't have any upcoming mentorship sessions scheduled.
                </p>
                <Button asChild>
                  <Link to="/services">Browse Mentors</Link>
                </Button>
              </div>
            )}
          </TabsContent>
          
          <TabsContent value="past">
            {pastBookings.length > 0 ? (
              pastBookings.map(booking => renderBookingCard(
                booking.id,
                booking.mentorId,
                booking.serviceId,
                booking.status,
                new Date(booking.scheduledAt),
                booking.totalPrice
              ))
            ) : (
              <div className="text-center py-16 bg-muted/30 rounded-lg">
                <h3 className="font-medium mb-2">No past bookings</h3>
                <p className="text-muted-foreground mb-6">
                  Your booking history will appear here.
                </p>
                <Button asChild>
                  <Link to="/services">Browse Mentors</Link>
                </Button>
              </div>
            )}
          </TabsContent>
        </Tabs>
      </div>
      
      {/* Cancel Booking Dialog */}
      <Dialog open={cancelDialogOpen} onOpenChange={setCancelDialogOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Cancel Booking</DialogTitle>
            <DialogDescription>
              Are you sure you want to cancel this booking? This action cannot be undone.
            </DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <Button 
              variant="outline" 
              onClick={() => setCancelDialogOpen(false)}
            >
              Keep Booking
            </Button>
            <Button 
              variant="destructive" 
              onClick={confirmCancelBooking}
            >
              Yes, Cancel Booking
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </MainLayout>
  );
}