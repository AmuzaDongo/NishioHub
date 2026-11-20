import { MainLayout } from "@/components/layout/main-layout";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Separator } from "@/components/ui/separator";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Check, Clock, MessageSquare, Search, ShieldCheck, Star, User, Users } from "lucide-react";
import { Link } from "react-router-dom";
import { Helmet } from "react-helmet";

export default function HowItWorksPage() {
  const menteeSteps = [
    {
      icon: <User className="h-8 w-8" />,
      title: "Create Your Profile",
      description: "Sign up and complete your profile with your background, goals, and the areas where you're seeking guidance."
    },
    {
      icon: <Search className="h-8 w-8" />,
      title: "Find the Right Mentor",
      description: "Browse mentor profiles or use our matching algorithm to find mentors who align with your goals and expertise needs."
    },
    {
      icon: <Clock className="h-8 w-8" />,
      title: "Book a Session",
      description: "Select a service, choose an available time slot that works for you, and complete the booking process."
    },
    {
      icon: <MessageSquare className="h-8 w-8" />,
      title: "Connect & Learn",
      description: "Attend your session prepared with questions. Follow up with your mentor through our messaging system."
    },
    {
      icon: <Star className="h-8 w-8" />,
      title: "Leave Feedback",
      description: "After your session, share your experience by leaving a review for your mentor to help others in their selection."
    }
  ];
  
  const mentorSteps = [
    {
      icon: <User className="h-8 w-8" />,
      title: "Create Your Profile",
      description: "Sign up as a mentor and showcase your expertise, experience, and the value you can provide to mentees."
    },
    {
      icon: <ShieldCheck className="h-8 w-8" />,
      title: "Verification Process",
      description: "Complete our verification process so mentees can trust in your credentials and expertise."
    },
    {
      icon: <Users className="h-8 w-8" />,
      title: "Set Up Your Services",
      description: "Define the services you offer, set your rates, and specify your availability for mentorship sessions."
    },
    {
      icon: <Clock className="h-8 w-8" />,
      title: "Manage Bookings",
      description: "Accept session requests, manage your calendar, and prepare for your mentorship sessions."
    },
    {
      icon: <MessageSquare className="h-8 w-8" />,
      title: "Mentor & Grow",
      description: "Conduct sessions, provide follow-up support through messaging, and build your reputation through reviews."
    }
  ];
  
  const faqs = [
    {
      question: "How do I find the right mentor for my needs?",
      answer: "You can browse mentors by category, use filters to narrow down options based on expertise, price range, or ratings, and read reviews from other mentees. Our matching algorithm can also suggest mentors based on your profile and goals."
    },
    {
      question: "What happens if I need to cancel or reschedule a session?",
      answer: "You can cancel or reschedule sessions through your dashboard. Cancellations made more than 24 hours before the session are fully refundable. For cancellations within 24 hours, refund policies vary by mentor."
    },
    {
      question: "How do payments work on nishioHub?",
      answer: "Payments are securely processed when you book a session. The funds are held until the session is completed, then released to the mentor. This ensures both parties are protected throughout the process."
    },
    {
      question: "Can I try a session before committing to multiple sessions?",
      answer: "Yes! Many mentors offer single sessions or introductory consultations. You can book these to ensure compatibility before investing in a longer-term mentorship arrangement."
    },
    {
      question: "How do I become a mentor on nishioHub?",
      answer: "Sign up and select 'Mentor' as your role. Complete your profile with your expertise, experience, and the services you want to offer. Our team will review your application, and once approved, you can start accepting mentees."
    }
  ];
  
  return (
    <MainLayout>
      <Helmet>
        <title>How It Works - nishioHub</title>
      </Helmet>
      
      {/* Hero Section */}
      <section className="bg-gradient-to-br from-primary/10 to-accent/10 py-20">
        <div className="container mx-auto px-4 text-center">
          <Badge className="mb-4">Simple Process</Badge>
          <h1 className="text-4xl md:text-5xl font-bold mb-6">How nishioHub Works</h1>
          <p className="text-xl text-muted-foreground max-w-3xl mx-auto mb-10">
            nishioHub connects mentees with experienced mentors in a straightforward, 
            efficient process designed to facilitate meaningful mentorship relationships.
          </p>
          <div className="flex justify-center gap-4">
            <Button size="lg" asChild>
              <Link to="/register">Get Started</Link>
            </Button>
            <Button size="lg" variant="outline" asChild>
              <Link to="/services">Browse Mentors</Link>
            </Button>
          </div>
        </div>
      </section>
      
      {/* Process Tabs */}
      <section className="py-16 container mx-auto px-4">
        <Tabs defaultValue="mentee" className="max-w-4xl mx-auto">
          <div className="flex justify-center mb-8">
            <TabsList className="grid w-full max-w-md grid-cols-2">
              <TabsTrigger value="mentee">For Mentees</TabsTrigger>
              <TabsTrigger value="mentor">For Mentors</TabsTrigger>
            </TabsList>
          </div>
          
          <TabsContent value="mentee">
            <h2 className="text-3xl font-bold mb-10 text-center">How to Find & Connect with Mentors</h2>
            <div className="space-y-12">
              {menteeSteps.map((step, index) => (
                <div key={index} className="flex flex-col md:flex-row gap-6 items-start md:items-center">
                  <div className="bg-primary/10 p-4 rounded-full text-primary flex-shrink-0">
                    {step.icon}
                  </div>
                  <div className="flex-1">
                    <div className="flex items-center gap-3 mb-2">
                      <Badge variant="outline" className="rounded-full w-6 h-6 p-0 flex items-center justify-center">
                        {index + 1}
                      </Badge>
                      <h3 className="text-xl font-bold">{step.title}</h3>
                    </div>
                    <p className="text-muted-foreground">{step.description}</p>
                  </div>
                </div>
              ))}
            </div>
            
            <div className="mt-12 text-center">
              <Button size="lg" asChild>
                <Link to="/register?role=mentee">Sign Up as a Mentee</Link>
              </Button>
            </div>
          </TabsContent>
          
          <TabsContent value="mentor">
            <h2 className="text-3xl font-bold mb-10 text-center">How to Become a Mentor</h2>
            <div className="space-y-12">
              {mentorSteps.map((step, index) => (
                <div key={index} className="flex flex-col md:flex-row gap-6 items-start md:items-center">
                  <div className="bg-primary/10 p-4 rounded-full text-primary flex-shrink-0">
                    {step.icon}
                  </div>
                  <div className="flex-1">
                    <div className="flex items-center gap-3 mb-2">
                      <Badge variant="outline" className="rounded-full w-6 h-6 p-0 flex items-center justify-center">
                        {index + 1}
                      </Badge>
                      <h3 className="text-xl font-bold">{step.title}</h3>
                    </div>
                    <p className="text-muted-foreground">{step.description}</p>
                  </div>
                </div>
              ))}
            </div>
            
            <div className="mt-12 text-center">
              <Button size="lg" asChild>
                <Link to="/register?role=mentor">Apply to be a Mentor</Link>
              </Button>
            </div>
          </TabsContent>
        </Tabs>
      </section>
      
      <Separator />
      
      {/* Benefits Section */}
      <section className="py-16 bg-muted/30">
        <div className="container mx-auto px-4">
          <h2 className="text-3xl font-bold mb-12 text-center">The nishioHub Advantage</h2>
          
          <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-8">
            <Card>
              <CardHeader>
                <div className="h-10 w-10 rounded-full bg-primary/10 flex items-center justify-center text-primary mb-4">
                  <Search className="h-5 w-5" />
                </div>
                <CardTitle>Intelligent Matching</CardTitle>
                <CardDescription>
                  Our algorithm suggests the most compatible mentors based on your goals, industry, and expertise needs.
                </CardDescription>
              </CardHeader>
              <CardContent>
                <ul className="space-y-2">
                  <li className="flex items-center">
                    <Check className="h-5 w-5 text-primary mr-2" />
                    <span>Personalized recommendations</span>
                  </li>
                  <li className="flex items-center">
                    <Check className="h-5 w-5 text-primary mr-2" />
                    <span>Filter by expertise and experience</span>
                  </li>
                  <li className="flex items-center">
                    <Check className="h-5 w-5 text-primary mr-2" />
                    <span>Find mentors in your industry</span>
                  </li>
                </ul>
              </CardContent>
            </Card>
            
            <Card>
              <CardHeader>
                <div className="h-10 w-10 rounded-full bg-primary/10 flex items-center justify-center text-primary mb-4">
                  <ShieldCheck className="h-5 w-5" />
                </div>
                <CardTitle>Verified Mentors</CardTitle>
                <CardDescription>
                  All mentors undergo a verification process to ensure they have the expertise they claim.
                </CardDescription>
              </CardHeader>
              <CardContent>
                <ul className="space-y-2">
                  <li className="flex items-center">
                    <Check className="h-5 w-5 text-primary mr-2" />
                    <span>Identity verification</span>
                  </li>
                  <li className="flex items-center">
                    <Check className="h-5 w-5 text-primary mr-2" />
                    <span>Credential checking</span>
                  </li>
                  <li className="flex items-center">
                    <Check className="h-5 w-5 text-primary mr-2" />
                    <span>Transparent review system</span>
                  </li>
                </ul>
              </CardContent>
            </Card>
            
            <Card>
              <CardHeader>
                <div className="h-10 w-10 rounded-full bg-primary/10 flex items-center justify-center text-primary mb-4">
                  <MessageSquare className="h-5 w-5" />
                </div>
                <CardTitle>Seamless Communication</CardTitle>
                <CardDescription>
                  Our platform provides integrated tools for scheduling, video calls, and messaging.
                </CardDescription>
              </CardHeader>
              <CardContent>
                <ul className="space-y-2">
                  <li className="flex items-center">
                    <Check className="h-5 w-5 text-primary mr-2" />
                    <span>Integrated video conferencing</span>
                  </li>
                  <li className="flex items-center">
                    <Check className="h-5 w-5 text-primary mr-2" />
                    <span>Direct messaging system</span>
                  </li>
                  <li className="flex items-center">
                    <Check className="h-5 w-5 text-primary mr-2" />
                    <span>Calendar integration</span>
                  </li>
                </ul>
              </CardContent>
            </Card>
            
            <Card>
              <CardHeader>
                <div className="h-10 w-10 rounded-full bg-primary/10 flex items-center justify-center text-primary mb-4">
                  <Clock className="h-5 w-5" />
                </div>
                <CardTitle>Flexible Scheduling</CardTitle>
                <CardDescription>
                  Book sessions that fit your schedule with our easy-to-use calendar system.
                </CardDescription>
              </CardHeader>
              <CardContent>
                <ul className="space-y-2">
                  <li className="flex items-center">
                    <Check className="h-5 w-5 text-primary mr-2" />
                    <span>Real-time availability</span>
                  </li>
                  <li className="flex items-center">
                    <Check className="h-5 w-5 text-primary mr-2" />
                    <span>Timezone conversion</span>
                  </li>
                  <li className="flex items-center">
                    <Check className="h-5 w-5 text-primary mr-2" />
                    <span>Easy rescheduling</span>
                  </li>
                </ul>
              </CardContent>
            </Card>
            
            <Card>
              <CardHeader>
                <div className="h-10 w-10 rounded-full bg-primary/10 flex items-center justify-center text-primary mb-4">
                  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className="h-5 w-5"><path d="M12 2v6a2 2 0 0 0 2 2h6v10a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h6Z"/><path d="M14 2v6h6"/><path d="M9 14h6"/><path d="M9 18h6"/></svg>
                </div>
                <CardTitle>Session Tracking</CardTitle>
                <CardDescription>
                  Keep track of your mentorship journey with detailed session history and notes.
                </CardDescription>
              </CardHeader>
              <CardContent>
                <ul className="space-y-2">
                  <li className="flex items-center">
                    <Check className="h-5 w-5 text-primary mr-2" />
                    <span>Session summaries</span>
                  </li>
                  <li className="flex items-center">
                    <Check className="h-5 w-5 text-primary mr-2" />
                    <span>Progress tracking</span>
                  </li>
                  <li className="flex items-center">
                    <Check className="h-5 w-5 text-primary mr-2" />
                    <span>Goal achievement monitoring</span>
                  </li>
                </ul>
              </CardContent>
            </Card>
            
            <Card>
              <CardHeader>
                <div className="h-10 w-10 rounded-full bg-primary/10 flex items-center justify-center text-primary mb-4">
                  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className="h-5 w-5"><circle cx="12" cy="12" r="10"/><path d="M16 8h-6a2 2 0 1 0 0 4h4a2 2 0 1 1 0 4H8"/><path d="M12 18V6"/></svg>
                </div>
                <CardTitle>Secure Payments</CardTitle>
                <CardDescription>
                  Our escrow payment system ensures fair transactions for both mentors and mentees.
                </CardDescription>
              </CardHeader>
              <CardContent>
                <ul className="space-y-2">
                  <li className="flex items-center">
                    <Check className="h-5 w-5 text-primary mr-2" />
                    <span>Secure payment processing</span>
                  </li>
                  <li className="flex items-center">
                    <Check className="h-5 w-5 text-primary mr-2" />
                    <span>Funds released after session</span>
                  </li>
                  <li className="flex items-center">
                    <Check className="h-5 w-5 text-primary mr-2" />
                    <span>Transparent pricing</span>
                  </li>
                </ul>
              </CardContent>
            </Card>
          </div>
        </div>
      </section>
      
      {/* FAQ Section */}
      <section className="py-16 container mx-auto px-4">
        <div className="max-w-3xl mx-auto">
          <h2 className="text-3xl font-bold mb-12 text-center">Frequently Asked Questions</h2>
          
          <div className="space-y-6">
            {faqs.map((faq, index) => (
              <Card key={index}>
                <CardHeader>
                  <CardTitle className="text-xl">{faq.question}</CardTitle>
                </CardHeader>
                <CardContent>
                  <p className="text-muted-foreground">{faq.answer}</p>
                </CardContent>
              </Card>
            ))}
          </div>
          
          <div className="mt-12 text-center">
            <p className="text-muted-foreground mb-6">Still have questions? We're here to help.</p>
            <Button asChild>
              <Link to="/contact">Contact Support</Link>
            </Button>
          </div>
        </div>
      </section>
      
      {/* CTA Section */}
      <section className="bg-gradient-to-br from-primary/10 to-accent/10 py-16">
        <div className="container mx-auto px-4 text-center">
          <h2 className="text-3xl font-bold mb-4">Ready to Start Your Mentorship Journey?</h2>
          <p className="text-muted-foreground mb-8 max-w-2xl mx-auto">
            Whether you're looking to find a mentor or share your expertise, nishioHub makes it easy to get started.
          </p>
          <div className="flex flex-col sm:flex-row justify-center gap-4">
            <Button size="lg" asChild>
              <Link to="/register">Create Your Account</Link>
            </Button>
            <Button size="lg" variant="outline" asChild>
              <Link to="/services">Browse Mentors</Link>
            </Button>
          </div>
        </div>
      </section>
    </MainLayout>
  );
}