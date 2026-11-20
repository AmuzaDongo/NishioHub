import { PageLoader } from '@/components/loaders/PageLoader';
import { MainLayout } from "@/components/layout/main-layout";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Separator } from "@/components/ui/separator";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { useAuth } from "@/lib/auth-context";
import { useServices } from "@/lib/services-context";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { Calendar, Clock, MapPin, MessageSquare, Star } from "lucide-react";
import { useEffect } from "react";
import { useParams, Link, useNavigate } from "react-router-dom";
import { Helmet } from "react-helmet-async";
import { roleName } from "@/lib/utils";

export default function MentorProfilePage() {
  const { mentorId } = useParams<{ mentorId: string }>();
  const { getMentorById, getServicesByMentor, getReviewsForMentor, isLoading } = useServices();
  const { user } = useAuth();
  const navigate = useNavigate();

  const mentor = mentorId ? getMentorById(mentorId) : undefined;
  const mentorServices = mentor ? getServicesByMentor(String(mentor.id)) : [];
  const mentorReviews = mentor ? getReviewsForMentor(String(mentor.id)) : [];

  useEffect(() => {
    if (!mentorId) navigate("/services");
  }, [mentorId, navigate]);
  
  if (isLoading) {
    return (
      <MainLayout>
        <div className="container mx-auto py-12 px-4 text-center">
          <PageLoader label="Loading mentor profile..."/>
        </div>
      </MainLayout>
    );
  }
  
  if (!mentor) {
    return (
      <MainLayout>
        <div className="container mx-auto py-12 px-4 text-center">
          <h2 className="text-2xl font-bold mb-4">Mentor Not Found</h2>
          <p className="mb-6">The mentor profile you're looking for doesn't exist or has been removed.</p>
          <Button asChild>
            <Link to="/services">Browse All Mentors</Link>
          </Button>
        </div>
      </MainLayout>
    );
  }
  
  const averageRating = mentorReviews.length > 0
    ? mentorReviews.reduce((sum, review) => sum + review.rating, 0) / mentorReviews.length
    : 0;
    
  const formatRating = (rating: number) => {
    return rating.toFixed(1);
  };
  
  const renderStars = (rating: number) => {
    return (
      <div className="flex items-center">
        {[1, 2, 3, 4, 5].map((star) => (
          <Star
            key={star}
            className={`w-4 h-4 ${
              star <= rating
                ? "text-yellow-500 fill-yellow-500"
                : "text-gray-300"
            }`}
          />
        ))}
      </div>
    );
  };
  
  return (
    <MainLayout>
      <Helmet>
        <title>{mentor.name} - Mentor Profile - nishioHub</title>
      </Helmet>
      
      {/* Hero Section */}
      <section className="bg-gradient-to-br from-primary/10 to-accent/10 py-12">
        <div className="container mx-auto px-4">
          <div className="flex flex-col md:flex-row items-center md:items-start gap-8">
            <div className="relative">
              <Avatar className="w-40 h-40 border-4 border-background">
                <AvatarImage src={mentor.avatar} alt={mentor.name} />
                <AvatarFallback className="text-4xl">{mentor.name?.charAt(0) || "?"}</AvatarFallback>
              </Avatar>
              {mentor.isVerified && (
                <Badge className="absolute bottom-0 right-0">Verified</Badge>
              )}
            </div>
            
            <div className="md:flex-1 text-center md:text-left">
              <h1 className="text-3xl md:text-4xl font-bold mb-2">{mentor.name}</h1>
              <p className="text-xl text-primary mb-4">{mentor.title}</p>
              
              <div className="flex flex-wrap items-center justify-center md:justify-start gap-4 mb-6">
                <div className="flex items-center">
                  <MapPin className="w-4 h-4 mr-1 text-muted-foreground" />
                  <span>{mentor.location}</span>
                </div>
                
                <div className="flex items-center">
                  <Star className="w-4 h-4 mr-1 text-yellow-500" />
                  <span>
                    {formatRating(averageRating)} ({mentorReviews.length} reviews)
                  </span>
                </div>
                
                <div className="flex items-center">
                  <Clock className="w-4 h-4 mr-1 text-muted-foreground" />
                  <span>{mentor.yearsOfExperience}+ years experience</span>
                </div>
              </div>
              
              <div className="flex flex-wrap gap-2 justify-center md:justify-start mb-6">
                {(mentor.skills || []).map((skill, index) => (
                  <Badge key={index} variant="secondary">
                    {skill}
                  </Badge>
                ))}
              </div>
              
              <div className="flex flex-col sm:flex-row gap-4 justify-center md:justify-start">
                <Button asChild>
                  <Link to={`/messages?userId=${mentor.id}`}>
                    <MessageSquare className="mr-2 h-4 w-4" />
                    Message
                  </Link>
                </Button>
                {user && roleName(user) === "mentee" && (
                  <Button variant="outline" asChild>
                    <Link to={`/services?mentorId=${mentor.id}`}>
                      View Services
                    </Link>
                  </Button>
                )}
              </div>
            </div>
          </div>
        </div>
      </section>
      
      {/* Main Content */}
      <section className="container mx-auto py-12 px-4">
        <div className="grid md:grid-cols-3 gap-10">
          {/* Sidebar */}
          <div className="md:col-span-1 space-y-6">
            <Card>
              <CardHeader>
                <CardTitle>About</CardTitle>
              </CardHeader>
              <CardContent>
                <p className="text-muted-foreground mb-6">
                  {mentor.bio}
                </p>
                
                <div className="space-y-4">
                  <div>
                    <h4 className="text-sm font-medium mb-2">Languages</h4>
                    <div className="flex flex-wrap gap-2">
                      {(mentor.languages || []).map((language, index) => (
                        <Badge key={index} variant="outline">
                          {language}
                        </Badge>
                      ))}
                    </div>
                  </div>
                  
                  <div>
                    <h4 className="text-sm font-medium mb-2">Education</h4>
                    <ul className="space-y-2">
                      {(mentor.education || []).map((edu, index) => (
                        <li key={index} className="text-sm">
                          <p className="font-medium">{edu.degree}</p>
                          <p className="text-muted-foreground">{edu.institution}, {edu.year}</p>
                        </li>
                      ))}
                    </ul>
                  </div>
                </div>
              </CardContent>
            </Card>
            
            <Card>
              <CardHeader>
                <CardTitle>Experience</CardTitle>
              </CardHeader>
              <CardContent>
                <ul className="space-y-4">
                  {(mentor.experience || []).map((exp, index) => (
                    <li key={index}>
                      <p className="font-medium">{exp.title}</p>
                      <p className="text-muted-foreground">{exp.company}</p>
                      <p className="text-sm text-muted-foreground">{exp.period}</p>
                      <p className="text-sm mt-1">{exp.description}</p>
                    </li>
                  ))}
                </ul>
              </CardContent>
            </Card>
          </div>
          
          {/* Main Content */}
          <div className="md:col-span-2">
            <Tabs defaultValue="services">
              <TabsList className="mb-6">
                <TabsTrigger value="services">Services</TabsTrigger>
                <TabsTrigger value="reviews">Reviews</TabsTrigger>
              </TabsList>
              
              <TabsContent value="services" className="space-y-6">
                <h2 className="text-2xl font-bold mb-6">Available Services</h2>
                
                {mentorServices.length > 0 ? (
                  <div className="grid md:grid-cols-2 gap-4">
                    {mentorServices.map((service) => (
                      <Card key={service.id} className="overflow-hidden">
                        <div className="h-40 overflow-hidden">
                          <img 
                            src={service.image} 
                            alt={service.title}
                            className="w-full h-full object-cover"
                          />
                        </div>
                        <CardHeader>
                          <CardTitle className="text-xl">{service.title}</CardTitle>
                          <CardDescription>{service.shortDescription}</CardDescription>
                        </CardHeader>
                        <CardContent>
                          <div className="flex justify-between items-center mb-4">
                            <p className="text-xl font-bold">${service.price}</p>
                            <Badge>{service.category}</Badge>
                          </div>
                          <Button className="w-full" asChild>
                            <Link to={`/services/${service.id}`}>
                              View Details
                            </Link>
                          </Button>
                        </CardContent>
                      </Card>
                    ))}
                  </div>
                ) : (
                  <Card>
                    <CardContent className="py-8 text-center">
                      <p>This mentor hasn't added any services yet.</p>
                    </CardContent>
                  </Card>
                )}
              </TabsContent>
              
              <TabsContent value="reviews">
                <h2 className="text-2xl font-bold mb-6">Client Reviews</h2>
                
                <div className="mb-8">
                  <div className="flex items-center gap-4 mb-4">
                    <div className="flex items-center">
                      <Star className="w-6 h-6 text-yellow-500 fill-yellow-500" />
                      <span className="text-2xl font-bold ml-2">{formatRating(averageRating)}</span>
                    </div>
                    <p className="text-muted-foreground">Based on {mentorReviews.length} reviews</p>
                  </div>
                  
                  <div className="flex gap-2">
                    {[5, 4, 3, 2, 1].map((rating) => {
                      const count = mentorReviews.filter(r => Math.floor(r.rating) === rating).length;
                      const percentage = mentorReviews.length > 0 
                        ? (count / mentorReviews.length) * 100
                        : 0;
                      
                      return (
                        <div key={rating} className="flex-1">
                          <div className="flex items-center mb-1">
                            <span className="text-sm mr-1">{rating}</span>
                            <Star className="w-3 h-3" />
                          </div>
                          <div className="h-2 bg-muted rounded-full overflow-hidden">
                            <div 
                              className="h-full bg-yellow-500" 
                              style={{ width: `${percentage}%` }}
                            ></div>
                          </div>
                        </div>
                      );
                    })}
                  </div>
                </div>
                
                {mentorReviews.length > 0 ? (
                  <div className="space-y-6">
                    {mentorReviews.map((review) => {
                      const reviewUser = review.mentee;
                      
                      return (
                        <Card key={review.id}>
                          <CardContent className="pt-6">
                            <div className="flex justify-between mb-4">
                              <div className="flex items-center">
                                <Avatar className="h-10 w-10 mr-3">
                                  <AvatarImage src={reviewUser?.avatar} />
                                  <AvatarFallback>
                                    {reviewUser?.name?.charAt(0) || "U"}
                                  </AvatarFallback>
                                </Avatar>
                                <div>
                                  <p className="font-medium">{reviewUser?.name}</p>
                                  <div className="flex items-center">
                                    {renderStars(review.rating)}
                                  </div>
                                </div>
                              </div>
                              <div className="text-sm text-muted-foreground">
                                <Calendar className="inline w-3 h-3 mr-1" />
                                {review.date}
                              </div>
                            </div>
                            <p className="mb-2 font-medium">{review.title}</p>
                            <p className="text-muted-foreground">{review.content}</p>
                          </CardContent>
                        </Card>
                      );
                    })}
                  </div>
                ) : (
                  <Card>
                    <CardContent className="py-8 text-center">
                      <p>This mentor hasn't received any reviews yet.</p>
                    </CardContent>
                  </Card>
                )}
              </TabsContent>
            </Tabs>
          </div>
        </div>
      </section>
      
      {/* CTA Section */}
      <section className="bg-muted/30 py-16">
        <div className="container mx-auto px-4 text-center">
          <h2 className="text-3xl font-bold mb-4">Ready to Connect?</h2>
          <p className="text-muted-foreground mb-8 max-w-2xl mx-auto">
            Take the first step towards achieving your goals with personalized mentorship.
          </p>
          <div className="flex flex-col sm:flex-row justify-center gap-4">
            <Button size="lg" asChild>
              <Link to={`/services?mentorId=${mentor.id}`}>Book a Session</Link>
            </Button>
            <Button size="lg" variant="outline" asChild>
              <Link to={`/messages?userId=${mentor.id}`}>Send a Message</Link>
            </Button>
          </div>
        </div>
      </section>
    </MainLayout>
  );
}