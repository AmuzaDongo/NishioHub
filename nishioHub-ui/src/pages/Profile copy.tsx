import { useState } from "react";
import { useParams, Link, useNavigate } from "react-router-dom";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { Badge } from "@/components/ui/badge";
import { MainLayout } from "@/components/layout/main-layout";
import { useAuth } from "@/lib/auth-context";
import { useServices } from "@/lib/services-context";
import { useMessaging } from "@/lib/messaging-context";
import { useUsers } from "@/lib/users-context";
import { roleName } from "@/lib/utils";
import { CalendarClock, Clock, Mail, MapPin, MessageSquare, Star } from "lucide-react";

type ProfileView = {
  id: string | number;
  full_name?: string;
  name?: string;
  email?: string;
  avatar?: string;
  profile_picture?: string;
  profile?: { profile_picture?: string } | null;
  role?: unknown;
  skills?: string[];
  joinedAt?:  string | Date;
};

type ReviewMentee = {
  id?: string | number;
  name?: string;
  avatar?: string;
  profile?: { profile_picture?: string } | null;
};

export default function ProfilePage() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const { user: currentUser } = useAuth();
  const { getMentorById, getServicesByMentor, getReviewsForMentor, isLoading: mentorsLoading } = useServices();
  const { getOrCreateConversation } = useMessaging();
  const { users, isLoading: usersLoading } = useUsers();
  const [activeTab, setActiveTab] = useState("services");

  // Prefer the mentor endpoint for mentor ids, then the users list.
  const mentor = id ? getMentorById(id) : undefined;
  const profileUser = (mentor || users.find((candidate) => String(candidate.id) === String(id)) || users[0] || null) as ProfileView | null;
  const isLoading = mentorsLoading || usersLoading;

  const isOwnProfile = !!currentUser && !!profileUser && String(currentUser.id) === String(profileUser.id);
  const isMentor = roleName(profileUser) === "mentor";
  const isMentee = roleName(profileUser) === "mentee";
  // Get mentor services and reviews if applicable
  const mentorServices = isMentor && profileUser ? getServicesByMentor(String(profileUser.id)) : [];
  const mentorReviews = isMentor && profileUser ? getReviewsForMentor(String(profileUser.id)) : [];

  // Calculate average rating
  const averageRating = mentorReviews.length > 0
    ? mentorReviews.reduce((sum, review) => sum + review.rating, 0) / mentorReviews.length
    : 0;
  
  const handleContactUser = async () => {
    if (!profileUser || !currentUser) return;
    
    const conversationId = await getOrCreateConversation(String(profileUser.id));
    if (conversationId) navigate(`/messages/${conversationId}`);
  };
  
  if (isLoading) {
    return (
      <MainLayout>
        <div className="container py-12 text-center">
          <p className="text-muted-foreground">Loading profile...</p>
        </div>
      </MainLayout>
    );
  }

  if (!profileUser) {
    return (
      <MainLayout>
        <div className="container py-12 text-center">
          <h1 className="text-3xl font-bold mb-4">Profile Not Found</h1>
          <p className="mb-8">The user profile you're looking for doesn't exist.</p>
          <Button asChild>
            <Link to="/">Go Home</Link>
          </Button>
        </div>
      </MainLayout>
    );
  }
  
  return (
    <MainLayout>
      <div className="container py-8">
        {/* Profile Header */}
        <div className="mb-8">
          <div className="flex flex-col md:flex-row md:items-end gap-6">
            <Avatar className="h-24 w-24 border-4 border-background">
              <AvatarImage src={profileUser.profile?.profile_picture || profileUser.profile_picture || profileUser.avatar} />
              <AvatarFallback>{profileUser.full_name?.charAt(0) || "?"}</AvatarFallback>
            </Avatar>
            <div className="flex-1">
              <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
                <div>
                  <div className="flex items-center gap-2">
                    <h1 className="text-3xl font-bold">{profileUser.full_name}</h1>
                    <Badge className="transform translate-x-1/4 translate-y-1/4" variant="secondary">
                      {roleName(profileUser)}
                    </Badge>
                  </div>
                  <div className="flex flex-wrap items-center gap-3 text-muted-foreground mt-1">
                    {profileUser.email && (
                      <div className="flex items-center">
                        <MapPin className="h-4 w-4 mr-1" />
                        <span>{profileUser.email}</span>
                      </div>
                    )}
                    {isMentor && mentorReviews.length > 0 && (
                      <div className="flex items-center">
                        <Star className="h-4 w-4 mr-1 text-yellow-400 fill-yellow-400" />
                        <span>
                          {averageRating.toFixed(1)} ({mentorReviews.length} reviews)
                        </span>
                      </div>
                    )}
                  </div>
                  <Badge className="transform translate-x-1/4 translate-y-1/4" variant="secondary">
                    {roleName(profileUser)}
                  </Badge>
                </div>
                {!isOwnProfile && (
                  <Button onClick={handleContactUser}>
                    <MessageSquare className="h-4 w-4 mr-2" />
                    Contact
                  </Button>
                )}
                {isOwnProfile && (
                  <Button asChild variant="outline">
                    <Link to="/edit-profile">
                      Edit Profile
                    </Link>
                  </Button>
                )}
              </div>
            </div>
          </div>
        </div>
        
        {/* Profile Content */}
        <div className="grid lg:grid-cols-3 gap-8">
          {/* Left Sidebar */}
          <div className="space-y-6">
            <Card>
              <CardContent className="p-6">
                <h3 className="font-medium text-lg mb-4">About</h3>
                <p className="text-muted-foreground mb-6">
                  {profileUser.full_name || "No bio available."}
                </p>
                
                <div className="space-y-4">
                  <div className="flex items-start">
                    <Mail className="h-4 w-4 text-muted-foreground mt-1 mr-3" />
                    <div>
                      <div className="text-sm text-muted-foreground mb-1">Email</div>
                      <a 
                        href={`mailto:${profileUser.email}`}
                        className="text-primary hover:underline"
                      >
                        {profileUser.email}
                      </a>
                    </div>
                  </div>
                  
                  <div className="flex items-start">
                    <Clock className="h-4 w-4 text-muted-foreground mt-1 mr-3" />
                    <div>
                      <div className="text-sm text-muted-foreground mb-1">Member Since</div>
                      <div>{profileUser.joinedAt ? new Date(profileUser.joinedAt).toLocaleDateString() : "Unknown"}</div>
                    </div>
                  </div>
                </div>
              </CardContent>
            </Card>
            
            {/* <Card>
              <CardContent className="p-6">
                <h3 className="font-medium text-lg mb-4">Skills</h3>
                {profileUser.skills && profileUser.skills.length > 0 ? (
                  <div className="flex flex-wrap gap-2">
                    {profileUser.skills.map((skill) => (
                      <Badge key={skill} variant="secondary">
                        {skill}
                      </Badge>
                    ))}
                  </div>
                ) : (
                  <p className="text-muted-foreground">No skills listed.</p>
                )}
              </CardContent>
            </Card> */}
          </div>
          
          {/* Main Content */}
          <div className="lg:col-span-2">
            <Tabs 
              value={activeTab} 
              onValueChange={setActiveTab}
              className="w-full"
            >
              <TabsList className="grid w-full grid-cols-2 mb-6">
                <TabsTrigger value="services" disabled={!isMentor}>
                  Services
                </TabsTrigger>
                <TabsTrigger value="reviews" disabled={!isMentor}>
                  Reviews
                </TabsTrigger>
              </TabsList>
              
              <TabsContent value="services">
                {isMentor ? (
                  mentorServices.length > 0 ? (
                    <div className="grid md:grid-cols-2 gap-6">
                      {mentorServices.map(service => (
                        <Card key={service.id} className="overflow-hidden">
                          <div className="aspect-[3/2] bg-muted"></div>
                          <CardContent className="p-5">
                            <Link to={`/services/${service.id}`}>
                              <h3 className="font-semibold text-lg mb-2 hover:text-primary transition-colors">
                                {service.title}
                              </h3>
                            </Link>
                            <p className="text-sm text-muted-foreground line-clamp-2 mb-4">
                              {service.description}
                            </p>
                            
                            <div className="flex justify-between items-center">
                              <div className="flex items-center gap-2">
                                <CalendarClock className="h-4 w-4 text-muted-foreground" />
                                <span className="text-sm">{service.duration} min</span>
                              </div>
                              <div>
                                <span className="text-lg font-bold">${service.price}</span>
                              </div>
                            </div>
                          </CardContent>
                        </Card>
                      ))}
                    </div>
                  ) : (
                    <div className="text-center py-12 bg-muted/30 rounded-lg">
                      <h3 className="font-medium mb-2">No services available</h3>
                      <p className="text-muted-foreground">
                        {isOwnProfile 
                          ? "You haven't created any services yet." 
                          : "This mentor hasn't created any services yet."}
                      </p>
                      {isOwnProfile && (
                        <Button className="mt-4" asChild>
                          <Link to="/services/create">Create a Service</Link>
                        </Button>
                      )}
                    </div>
                  )
                ) : (
                  <div className="text-center py-12 bg-muted/30 rounded-lg">
                    <h3 className="font-medium mb-2">User is not a mentor</h3>
                    <p className="text-muted-foreground">
                      This user doesn't offer mentoring services.
                    </p>
                  </div>
                )}
              </TabsContent>
              
              <TabsContent value="reviews">
                {isMentor ? (
                  mentorReviews.length > 0 ? (
                    <div className="space-y-6">
                      <div className="flex items-center gap-4 mb-6">
                        <div className="bg-primary/10 text-primary rounded-full px-4 py-2 flex items-center">
                          <Star className="h-5 w-5 mr-1 fill-current" />
                          <span className="text-lg font-bold">{averageRating.toFixed(1)}</span>
                        </div>
                        <div className="text-muted-foreground">
                          Based on {mentorReviews.length} reviews
                        </div>
                      </div>
                      
                      {mentorReviews.map(review => {
                        const mentee = (review.mentee || users.find(u => String(u.id) === String(review.menteeId))) as ReviewMentee | undefined;
                        return (
                          <div key={review.id} className="border-b pb-6">
                            <div className="flex justify-between items-start">
                              <div className="flex items-center space-x-3">
                                <Avatar>
                                  <AvatarImage src={mentee?.avatar || mentee?.profile?.profile_picture} />
                                  <AvatarFallback>{mentee?.name?.charAt(0) || "?"}</AvatarFallback>
                                </Avatar>
                                <div>
                                  <p className="font-medium">{mentee?.name || "Mentee"}</p>
                                  <p className="text-sm text-muted-foreground">
                                    {new Date(review.createdAt).toLocaleDateString()}
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
                    </div>
                  ) : (
                    <div className="text-center py-12 bg-muted/30 rounded-lg">
                      <h3 className="font-medium mb-2">No reviews yet</h3>
                      <p className="text-muted-foreground">
                        {isOwnProfile 
                          ? "You haven't received any reviews yet." 
                          : "This mentor hasn't received any reviews yet."}
                      </p>
                    </div>
                  )
                ) : (
                  <div className="text-center py-12 bg-muted/30 rounded-lg">
                    <h3 className="font-medium mb-2">User is not a mentor</h3>
                    <p className="text-muted-foreground">
                      Only mentors can receive reviews.
                    </p>
                  </div>
                )}
              </TabsContent>
            </Tabs>
          </div>
        </div>
      </div>
    </MainLayout>
  );
}