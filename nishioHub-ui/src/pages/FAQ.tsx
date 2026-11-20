import { MainLayout } from "@/components/layout/main-layout";
import { Accordion, AccordionContent, AccordionItem, AccordionTrigger } from "@/components/ui/accordion";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Separator } from "@/components/ui/separator";
import { Search } from "lucide-react";
import { useState } from "react";
import { Helmet } from "react-helmet";

const faqCategories = [
  { id: "general", name: "General" },
  { id: "account", name: "Account" },
  { id: "mentor", name: "For Mentors" },
  { id: "mentee", name: "For Mentees" },
  { id: "payments", name: "Payments" },
  { id: "technical", name: "Technical" },
];

const faqItems = [
  {
    category: "general",
    question: "What is nishioHub?",
    answer: "nishioHub is a platform connecting mentees with experienced mentors across various fields. Our mission is to facilitate knowledge sharing and professional growth through personalized mentorship relationships."
  },
  {
    category: "general",
    question: "How does nishioHub work?",
    answer: "nishioHub allows mentees to browse and connect with mentors based on their expertise, reviews, and availability. Once connected, you can schedule sessions, communicate through our messaging system, and track your progress."
  },
  {
    category: "account",
    question: "How do I create an account?",
    answer: "You can create an account by clicking the 'Register' button in the top-right corner of the homepage. Fill out the required information and select whether you want to join as a mentor or mentee."
  },
  {
    category: "account",
    question: "How do I reset my password?",
    answer: "On the login page, click 'Forgot Password' and enter the email address associated with your account. You'll receive instructions to reset your password via email."
  },
  {
    category: "mentor",
    question: "How do I become a mentor?",
    answer: "When registering, select 'Mentor' as your role. You'll need to complete your profile with your expertise, experience, and the services you offer. Our team will review your application before your profile goes live."
  },
  {
    category: "mentor",
    question: "How do I set my availability?",
    answer: "As a mentor, you can set your availability in your dashboard under 'Manage Schedule'. You can block off times when you're unavailable and set your regular hours for booking."
  },
  {
    category: "mentee",
    question: "How do I find the right mentor?",
    answer: "You can search for mentors by category, skills, or keywords. Use filters to narrow down mentors based on price range, availability, or ratings. Review mentor profiles and reviews before making your decision."
  },
  {
    category: "mentee",
    question: "How do I book a session?",
    answer: "Once you find a mentor you'd like to work with, go to their service page and select 'Book Session'. Choose an available time slot, include any specific questions or topics you'd like to discuss, and complete the payment."
  },
  {
    category: "payments",
    question: "What payment methods are accepted?",
    answer: "We accept major credit cards, PayPal, and bank transfers. All payments are processed securely through our payment gateway."
  },
  {
    category: "payments",
    question: "What is your refund policy?",
    answer: "If a session is canceled by the mentor, you'll receive a full refund. If you need to cancel, you must do so at least 24 hours before the scheduled session to receive a full refund. Cancellations within 24 hours may be subject to a cancellation fee."
  },
  {
    category: "technical",
    question: "What do I need for virtual mentoring sessions?",
    answer: "For virtual sessions, you'll need a stable internet connection, a device with a camera and microphone, and any specific software or tools your mentor suggests for your session."
  },
  {
    category: "technical",
    question: "What if I experience technical difficulties during a session?",
    answer: "If you encounter technical issues during a session, try refreshing your browser or reconnecting. If problems persist, contact your mentor to reschedule or continue via an alternative platform. You can report technical issues to our support team."
  },
];

export default function FAQPage() {
  const [activeCategory, setActiveCategory] = useState<string>("general");
  const [searchQuery, setSearchQuery] = useState<string>("");
  
  const filteredFAQs = searchQuery 
    ? faqItems.filter(item => 
        item.question.toLowerCase().includes(searchQuery.toLowerCase()) || 
        item.answer.toLowerCase().includes(searchQuery.toLowerCase())
      )
    : faqItems.filter(item => item.category === activeCategory);
  
  return (
    <MainLayout>
      <Helmet>
        <title>FAQ - nishioHub</title>
      </Helmet>
      
      <div className="container mx-auto py-12">
        <div className="max-w-4xl mx-auto">
          <h1 className="text-4xl font-bold text-center mb-2">Frequently Asked Questions</h1>
          <p className="text-muted-foreground text-center mb-8">
            Find answers to common questions about nishioHub
          </p>
          
          {/* Search Bar */}
          <div className="mb-8 relative">
            <Input
              placeholder="Search for questions..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="pl-10"
            />
            <Search className="w-5 h-5 absolute top-3 left-3 text-muted-foreground" />
          </div>
          
          {/* Category Tabs */}
          <div className="flex flex-wrap gap-2 mb-6">
            {faqCategories.map((category) => (
              <Button
                key={category.id}
                variant={activeCategory === category.id && !searchQuery ? "default" : "outline"}
                onClick={() => {
                  setActiveCategory(category.id);
                  setSearchQuery("");
                }}
                className="mb-2"
              >
                {category.name}
              </Button>
            ))}
          </div>
          
          <Separator className="mb-6" />
          
          {/* FAQ Accordion */}
          {searchQuery && (
            <div className="mb-4">
              <Badge variant="outline" className="mb-4">
                Search results for: "{searchQuery}"
              </Badge>
            </div>
          )}
          
          {filteredFAQs.length > 0 ? (
            <Accordion type="single" collapsible className="w-full">
              {filteredFAQs.map((faq, index) => (
                <AccordionItem key={index} value={`item-${index}`}>
                  <AccordionTrigger className="text-left">
                    {faq.question}
                  </AccordionTrigger>
                  <AccordionContent>
                    <p>{faq.answer}</p>
                  </AccordionContent>
                </AccordionItem>
              ))}
            </Accordion>
          ) : (
            <Card>
              <CardContent className="pt-6 text-center">
                <p>No FAQs found matching your query. Please try another search term.</p>
              </CardContent>
            </Card>
          )}
          
          {/* Contact Support */}
          <div className="mt-12 bg-muted rounded-lg p-6 text-center">
            <h2 className="text-xl font-semibold mb-2">Still have questions?</h2>
            <p className="text-muted-foreground mb-4">
              Our support team is here to help with any other questions you might have.
            </p>
            <Button asChild>
              <a href="/contact">Contact Support</a>
            </Button>
          </div>
        </div>
      </div>
    </MainLayout>
  );
}