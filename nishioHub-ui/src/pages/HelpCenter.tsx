import { MainLayout } from "@/components/layout/main-layout";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { ScrollArea } from "@/components/ui/scroll-area";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { BookOpen, Clock, FileQuestion, HelpCircle, Inbox, MessageCircle, Phone, Search, Users } from "lucide-react";
import { useState } from "react";
import { Link } from "react-router-dom";
import { Helmet } from "react-helmet-async";

const helpCategories = [
  {
    id: "getting-started",
    name: "Getting Started",
    icon: <BookOpen className="w-5 h-5 mr-2" />,
    articles: [
      {
        id: "create-account",
        title: "Creating your account",
        description: "Learn how to set up your nishioHub account and complete your profile.",
        popular: true
      },
      {
        id: "find-mentor",
        title: "Finding the right mentor",
        description: "Tips for searching, filtering, and selecting a mentor that matches your needs.",
        popular: true
      },
      {
        id: "first-session",
        title: "Preparing for your first mentorship session",
        description: "What to expect and how to get the most out of your first mentorship session.",
        popular: false
      },
      {
        id: "become-mentor",
        title: "Becoming a mentor",
        description: "Requirements and steps to become a mentor on nishioHub.",
        popular: false
      },
    ]
  },
  {
    id: "bookings",
    name: "Bookings & Scheduling",
    icon: <Clock className="w-5 h-5 mr-2" />,
    articles: [
      {
        id: "book-session",
        title: "How to book a mentorship session",
        description: "Step-by-step guide to booking sessions with mentors.",
        popular: true
      },
      {
        id: "cancel-reschedule",
        title: "Cancelling or rescheduling sessions",
        description: "Policies and procedures for changing your session time or cancelling.",
        popular: true
      },
      {
        id: "set-availability",
        title: "Setting your availability as a mentor",
        description: "How to manage your schedule and availability for mentee bookings.",
        popular: false
      },
      {
        id: "timezone",
        title: "Managing timezones",
        description: "Understanding how timezones work for global mentorship sessions.",
        popular: false
      },
    ]
  },
  {
    id: "payments",
    name: "Payments & Billing",
    icon: <Inbox className="w-5 h-5 mr-2" />,
    articles: [
      {
        id: "payment-methods",
        title: "Accepted payment methods",
        description: "Learn about the payment options available on nishioHub.",
        popular: false
      },
      {
        id: "refund-policy",
        title: "Refund policy",
        description: "Understand our refund policy for cancelled or unsatisfactory sessions.",
        popular: true
      },
      {
        id: "mentor-payments",
        title: "Receiving payments as a mentor",
        description: "How and when mentors receive payment for their services.",
        popular: true
      },
      {
        id: "invoices",
        title: "Accessing invoices and receipts",
        description: "How to find and download your payment history and receipts.",
        popular: false
      },
    ]
  },
  {
    id: "communication",
    name: "Communication",
    icon: <MessageCircle className="w-5 h-5 mr-2" />,
    articles: [
      {
        id: "messaging",
        title: "Using the messaging system",
        description: "How to send and receive messages with your mentor or mentee.",
        popular: true
      },
      {
        id: "video-calls",
        title: "Video call sessions",
        description: "Technical requirements and troubleshooting for video mentorship sessions.",
        popular: false
      },
      {
        id: "notifications",
        title: "Managing notifications",
        description: "Customize how and when you receive platform notifications.",
        popular: false
      },
    ]
  },
  {
    id: "account",
    name: "Account Management",
    icon: <Users className="w-5 h-5 mr-2" />,
    articles: [
      {
        id: "edit-profile",
        title: "Editing your profile",
        description: "How to update your personal information, bio, and profile picture.",
        popular: true
      },
      {
        id: "change-password",
        title: "Changing your password",
        description: "Steps to update your password or recover a forgotten password.",
        popular: false
      },
      {
        id: "delete-account",
        title: "Deleting your account",
        description: "How to permanently delete your nishioHub account and data.",
        popular: false
      },
    ]
  },
];

export default function HelpCenterPage() {
  const [searchQuery, setSearchQuery] = useState("");
  const [selectedCategory, setSelectedCategory] = useState("getting-started");
  
  const filteredArticles = searchQuery
    ? helpCategories.flatMap(cat => cat.articles).filter(article => 
        article.title.toLowerCase().includes(searchQuery.toLowerCase()) ||
        article.description.toLowerCase().includes(searchQuery.toLowerCase())
      )
    : helpCategories.find(cat => cat.id === selectedCategory)?.articles || [];
  
  const popularArticles = helpCategories.flatMap(cat => 
    cat.articles.filter(article => article.popular)
  );
  
  return (
    <MainLayout>
      <Helmet>
        <title>Help Center - nishioHub</title>
      </Helmet>
      
      <div className="container mx-auto py-12 px-4">
        <div className="text-center mb-10">
          <h1 className="text-4xl font-bold mb-4">How can we help you?</h1>
          <p className="text-muted-foreground mb-6 max-w-2xl mx-auto">
            Find answers to common questions, learn how to use nishioHub, or contact our support team for assistance.
          </p>
          
          <div className="relative max-w-xl mx-auto mb-8">
            <Search className="absolute left-3 top-3 h-5 w-5 text-muted-foreground" />
            <Input
              placeholder="Search for help articles..."
              className="pl-10"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
            />
          </div>
        </div>
        
        {/* Main Help Content */}
        <div className="grid md:grid-cols-3 gap-8">
          {/* Left Sidebar */}
          <div className="md:col-span-1">
            <Card className="sticky top-20">
              <CardHeader>
                <CardTitle>Help Topics</CardTitle>
              </CardHeader>
              <ScrollArea className="h-[calc(100vh-300px)]">
                <div className="px-4 pb-4">
                  {helpCategories.map((category) => (
                    <Button
                      key={category.id}
                      variant={selectedCategory === category.id && !searchQuery ? "default" : "ghost"}
                      className="w-full justify-start mb-1 font-normal"
                      onClick={() => {
                        setSelectedCategory(category.id);
                        setSearchQuery("");
                      }}
                    >
                      {category.icon}
                      {category.name}
                    </Button>
                  ))}
                  
                  <div className="mt-8">
                    <h3 className="font-medium mb-3">Need more help?</h3>
                    <Button variant="outline" className="w-full justify-start mb-2">
                      <Phone className="w-4 h-4 mr-2" />
                      Contact Support
                    </Button>
                    <Button variant="outline" className="w-full justify-start">
                      <FileQuestion className="w-4 h-4 mr-2" />
                      Submit a Ticket
                    </Button>
                  </div>
                </div>
              </ScrollArea>
            </Card>
          </div>
          
          {/* Main Content */}
          <div className="md:col-span-2">
            {searchQuery ? (
              <>
                <h2 className="text-2xl font-semibold mb-4">
                  Search Results
                  <Badge variant="outline" className="ml-3">
                    {filteredArticles.length} results for "{searchQuery}"
                  </Badge>
                </h2>
                
                {filteredArticles.length > 0 ? (
                  <div className="grid gap-4">
                    {filteredArticles.map((article) => (
                      <Link to={`/help-center/${article.id}`} key={article.id}>
                        <Card className="hover:bg-accent/50 transition-colors cursor-pointer">
                          <CardHeader className="pb-2">
                            <CardTitle className="text-lg">{article.title}</CardTitle>
                          </CardHeader>
                          <CardContent>
                            <p className="text-muted-foreground">{article.description}</p>
                          </CardContent>
                        </Card>
                      </Link>
                    ))}
                  </div>
                ) : (
                  <Card>
                    <CardContent className="py-8 text-center">
                      <HelpCircle className="w-12 h-12 mx-auto mb-4 text-muted-foreground" />
                      <h3 className="text-xl font-semibold mb-2">No results found</h3>
                      <p className="text-muted-foreground mb-4">
                        We couldn't find any articles matching your search. Please try different keywords or contact support.
                      </p>
                      <Button asChild>
                        <Link to="/contact">Contact Support</Link>
                      </Button>
                    </CardContent>
                  </Card>
                )}
              </>
            ) : (
              <Tabs defaultValue="articles" className="w-full">
                <TabsList className="grid grid-cols-2 mb-6">
                  <TabsTrigger value="articles">All Articles</TabsTrigger>
                  <TabsTrigger value="popular">Popular Articles</TabsTrigger>
                </TabsList>
                
                <TabsContent value="articles">
                  <h2 className="text-2xl font-semibold mb-4">
                    {helpCategories.find(cat => cat.id === selectedCategory)?.name}
                  </h2>
                  
                  <div className="grid gap-4">
                    {filteredArticles.map((article) => (
                      <Link to={`/help-center/${article.id}`} key={article.id}>
                        <Card className="hover:bg-accent/50 transition-colors cursor-pointer">
                          <CardHeader className="pb-2">
                            <CardTitle className="text-lg">{article.title}</CardTitle>
                          </CardHeader>
                          <CardContent>
                            <p className="text-muted-foreground">{article.description}</p>
                          </CardContent>
                        </Card>
                      </Link>
                    ))}
                  </div>
                </TabsContent>
                
                <TabsContent value="popular">
                  <h2 className="text-2xl font-semibold mb-4">Popular Articles</h2>
                  
                  <div className="grid gap-4">
                    {popularArticles.map((article) => (
                      <Link to={`/help-center/${article.id}`} key={article.id}>
                        <Card className="hover:bg-accent/50 transition-colors cursor-pointer">
                          <CardHeader className="pb-2">
                            <CardTitle className="text-lg">{article.title}</CardTitle>
                          </CardHeader>
                          <CardContent>
                            <p className="text-muted-foreground">{article.description}</p>
                          </CardContent>
                        </Card>
                      </Link>
                    ))}
                  </div>
                </TabsContent>
              </Tabs>
            )}
          </div>
        </div>
      </div>
    </MainLayout>
  );
}