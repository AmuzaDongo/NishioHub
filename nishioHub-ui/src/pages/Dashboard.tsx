import { useState } from "react";
import { Link, Navigate } from "react-router-dom";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import {
  Tabs,
  TabsContent,
  TabsList,
  TabsTrigger,
} from "@/components/ui/tabs";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { Badge } from "@/components/ui/badge";
import { MainLayout } from "@/components/layout/main-layout";
import { hasRole, isPlatformAdmin, roleName } from "@/lib/utils";
import { useAuth } from "@/lib/auth-context";
import { useServices } from "@/lib/services-context";
import { useMessaging } from "@/lib/messaging-context";
import { CalendarClock, DollarSign, MessageSquare, PlusCircle, Users } from "lucide-react";

export default function DashboardPage() {
  const { user } = useAuth();
  const { getServicesByMentor, bookings } = useServices();
  const { hasUnreadMessages } = useMessaging();
  const [view, setView] = useState<"upcoming" | "past" | "all">("upcoming");
  
  if (isPlatformAdmin(user)) return <Navigate to="/admin" replace />;
  if (roleName(user) === "mentee") return <Navigate to="/mentee/dashboard" replace />;

  // Redirect if user is not a mentor
  if (!user || !hasRole(user, "mentor")) {
    return <Navigate to="/" />;
  }
  
  const mentorServices = getServicesByMentor(String(user.id));
  const mentorBookings = bookings.filter(booking => String(booking.mentorId) === String(user.id));
  
  // Calculate some stats
  const completedBookings = mentorBookings.filter(b => b.status === "completed");
  const totalEarnings = completedBookings.reduce((sum, b) => sum + b.totalPrice, 0);
  const uniqueMentees = new Set(mentorBookings.map(b => b.menteeId)).size;
  
  // Filter bookings based on view
  const today = new Date();
  let displayedBookings = mentorBookings;
  
  switch (view) {
    case "upcoming":
      displayedBookings = mentorBookings.filter(
        b => new Date(b.scheduledAt) >= today && b.status !== "cancelled"
      );
      break;
    case "past":
      displayedBookings = mentorBookings.filter(
        b => new Date(b.scheduledAt) < today || b.status === "completed"
      );
      break;
    // "all" shows everything
  }
  
  // Sort bookings by date
  displayedBookings.sort((a, b) => {
    if (view === "past") {
      return new Date(b.scheduledAt).getTime() - new Date(a.scheduledAt).getTime();
    }
    return new Date(a.scheduledAt).getTime() - new Date(b.scheduledAt).getTime();
  });
  
  return (
    <MainLayout>
      <div className="container py-8">
        <div className="flex flex-col md:flex-row md:items-center md:justify-between mb-8 gap-4">
          <div>
            <h1 className="text-3xl font-bold">Mentor Dashboard</h1>
            <p className="text-muted-foreground">Manage your services and bookings</p>
          </div>
          <div className="flex flex-wrap gap-3">
            <Button asChild variant="outline"><Link to="/mentor/mentorship"><Users className="h-4 w-4 mr-2" />My Mentorship</Link></Button>
            <Button asChild variant="outline">
              <Link to="/messages">
                <MessageSquare className="h-4 w-4 mr-2" />
                Messages
                {hasUnreadMessages && (
                  <span className="ml-2 h-2 w-2 rounded-full bg-red-500" />
                )}
              </Link>
            </Button>
            <Button asChild>
              <Link to="/services/create">
                <PlusCircle className="h-4 w-4 mr-2" />
                Create Service
              </Link>
            </Button>
          </div>
        </div>

        {/* Stats Cards */}
        <div className="grid sm:grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
          <Card>
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">Total Earnings</CardTitle>
              <DollarSign className="h-4 w-4 text-muted-foreground" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">${totalEarnings}</div>
              <p className="text-xs text-muted-foreground">
                From {completedBookings.length} completed sessions
              </p>
            </CardContent>
          </Card>
          <Card>
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">Active Services</CardTitle>
              <svg
                xmlns="http://www.w3.org/2000/svg"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth="2"
                className="h-4 w-4 text-muted-foreground"
              >
                <rect width="18" height="18" x="3" y="3" rx="2" />
                <path d="M9 9h6v6H9z" />
              </svg>
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">{mentorServices.length}</div>
              <p className="text-xs text-muted-foreground">
                {mentorServices.length === 0 ? "Create your first service" : "Across different categories"}
              </p>
            </CardContent>
          </Card>
          <Card>
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">Upcoming Sessions</CardTitle>
              <CalendarClock className="h-4 w-4 text-muted-foreground" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">
                {mentorBookings.filter(b => 
                  new Date(b.scheduledAt) >= today && b.status !== "cancelled"
                ).length}
              </div>
              <p className="text-xs text-muted-foreground">
                Scheduled for the future
              </p>
            </CardContent>
          </Card>
          <Card>
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">Unique Mentees</CardTitle>
              <Users className="h-4 w-4 text-muted-foreground" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">{uniqueMentees}</div>
              <p className="text-xs text-muted-foreground">
                People you've mentored
              </p>
            </CardContent>
          </Card>
        </div>

        {/* Services Table */}
        <div className="mb-8">
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-xl font-semibold">Your Services</h2>
            <Button asChild variant="outline" size="sm">
              <Link to="/services/manage">Manage Services</Link>
            </Button>
          </div>
          <div className="rounded-md border">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Service</TableHead>
                  <TableHead>Price</TableHead>
                  <TableHead>Duration</TableHead>
                  <TableHead>Rating</TableHead>
                  <TableHead className="text-right">Action</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {mentorServices.length > 0 ? (
                  mentorServices.map(service => (
                    <TableRow key={service.id}>
                      <TableCell className="font-medium">{service.title}</TableCell>
                      <TableCell>${service.price}</TableCell>
                      <TableCell>{service.duration} min</TableCell>
                      <TableCell>
                        {service.rating ? (
                          <div className="flex items-center">
                            <svg
                              xmlns="http://www.w3.org/2000/svg"
                              viewBox="0 0 24 24"
                              fill="currentColor"
                              className="h-4 w-4 text-yellow-400"
                            >
                              <path fillRule="evenodd" d="M10.788 3.21c.448-1.077 1.976-1.077 2.424 0l2.082 5.007 5.404.433c1.164.093 1.636 1.545.749 2.305l-4.117 3.527 1.257 5.273c.271 1.136-.964 2.033-1.96 1.425L12 18.354 7.373 21.18c-.996.608-2.231-.29-1.96-1.425l1.257-5.273-4.117-3.527c-.887-.76-.415-2.212.749-2.305l5.404-.433 2.082-5.006z" clipRule="evenodd" />
                            </svg>
                            <span className="ml-1">{service.rating.toFixed(1)}</span>
                            <span className="ml-1 text-muted-foreground text-xs">({service.reviewCount})</span>
                          </div>
                        ) : (
                          <span className="text-muted-foreground text-sm">No ratings yet</span>
                        )}
                      </TableCell>
                      <TableCell className="text-right">
                        <Button asChild size="sm" variant="ghost">
                          <Link to={`/services/${service.id}`}>View</Link>
                        </Button>
                      </TableCell>
                    </TableRow>
                  ))
                ) : (
                  <TableRow>
                    <TableCell colSpan={5} className="h-24 text-center">
                      <div className="flex flex-col items-center gap-2">
                        <p className="text-muted-foreground">You haven't created any services yet.</p>
                        <Button asChild size="sm">
                          <Link to="/services/create">Create Your First Service</Link>
                        </Button>
                      </div>
                    </TableCell>
                  </TableRow>
                )}
              </TableBody>
            </Table>
          </div>
        </div>

        {/* Bookings */}
        <div>
          <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4 mb-4">
            <h2 className="text-xl font-semibold">Bookings</h2>
            <Tabs 
              value={view} 
              onValueChange={(v) => setView(v as "upcoming" | "past" | "all")}
              className="w-full sm:w-auto"
            >
              <TabsList className="grid w-full grid-cols-3 sm:w-[400px]">
                <TabsTrigger value="upcoming">Upcoming</TabsTrigger>
                <TabsTrigger value="past">Past</TabsTrigger>
                <TabsTrigger value="all">All</TabsTrigger>
              </TabsList>
            </Tabs>
          </div>

          <div className="rounded-md border">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Mentee</TableHead>
                  <TableHead>Service</TableHead>
                  <TableHead>Date & Time</TableHead>
                  <TableHead>Status</TableHead>
                  <TableHead className="text-right">Action</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {displayedBookings.length > 0 ? (
                  displayedBookings.map(booking => {
                    const service = booking.service || mentorServices.find(s => String(s.id) === String(booking.serviceId));
                    const mentee = booking.mentee;
                    return (
                      <TableRow key={booking.id}>
                        <TableCell className="font-medium">
                          <div className="flex items-center space-x-2">
                            <div className="h-8 w-8 rounded-full bg-muted overflow-hidden">
                              {mentee?.avatar && (
                                <img
                                  src={mentee.avatar}
                                  alt={mentee.name}
                                  className="h-full w-full object-cover"
                                />
                              )}
                            </div>
                            <span>{mentee?.name}</span>
                          </div>
                        </TableCell>
                        <TableCell>{service?.title}</TableCell>
                        <TableCell>
                          <div className="space-y-1">
                            <div>{new Date(booking.scheduledAt).toLocaleDateString()}</div>
                            <div className="text-sm text-muted-foreground">
                              {new Date(booking.scheduledAt).toLocaleTimeString([], { 
                                hour: '2-digit', 
                                minute: '2-digit' 
                              })}
                            </div>
                          </div>
                        </TableCell>
                        <TableCell>
                          <Badge
                            variant={
                              booking.status === "completed" ? "default" :
                              booking.status === "confirmed" ? "success" :
                              booking.status === "pending" ? "warning" : "destructive"
                            }
                          >
                            {booking.status.charAt(0).toUpperCase() + booking.status.slice(1)}
                          </Badge>
                        </TableCell>
                        <TableCell className="text-right">
                          <Button asChild size="sm" variant="ghost">
                            <Link to={`/bookings/${booking.id}`}>View</Link>
                          </Button>
                        </TableCell>
                      </TableRow>
                    );
                  })
                ) : (
                  <TableRow>
                    <TableCell colSpan={5} className="h-24 text-center">
                      <p className="text-muted-foreground">
                        {view === "upcoming" ? "No upcoming bookings." : 
                         view === "past" ? "No past bookings." : 
                         "No bookings yet."}
                      </p>
                    </TableCell>
                  </TableRow>
                )}
              </TableBody>
            </Table>
          </div>
        </div>
      </div>
    </MainLayout>
  );
}