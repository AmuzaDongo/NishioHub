import { useSearchParams } from 'react-router-dom';
import { submitPublicInquiry } from '@/lib/public-home-api';
import { operationError } from '@/components/admin/dashboard-operations';
import { usePlatform } from '@/lib/platform-context';
import { MainLayout } from "@/components/layout/main-layout";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Form, FormControl, FormDescription, FormField, FormItem, FormLabel, FormMessage } from "@/components/ui/form";
import { Input } from "@/components/ui/input";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Separator } from "@/components/ui/separator";
import { Textarea } from "@/components/ui/textarea";
import { Clock, Mail, MapPin, MessageSquare, Phone } from "lucide-react";
import { useState } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { Helmet } from "react-helmet";

const contactFormSchema = z.object({
  name: z.string().min(2, {
    message: "Name must be at least 2 characters.",
  }),
  email: z.string().email({
    message: "Please enter a valid email address.",
  }),
  subject: z.string().min(5, {
    message: "Subject must be at least 5 characters.",
  }),
  category: z.string({
    required_error: "Please select a category.",
  }).min(1, "Please select a category."),
  message: z.string().min(10, {
    message: "Message must be at least 10 characters.",
  }).max(1000, {
    message: "Message cannot exceed 1000 characters.",
  }),
});

export default function ContactPage() {
  const platform = usePlatform();
  const [contactParams] = useSearchParams();
  const requestedCategory = contactParams.get('category') || '';
  const contactCategory = ['general','support','billing','mentorship','feedback','other','partnership'].includes(requestedCategory) ? requestedCategory : '';
  const partnership = contactCategory === 'partnership';
  const [submissionError, setSubmissionError] = useState('');
  const [reference, setReference] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [isSubmitted, setIsSubmitted] = useState(false);
  
  const form = useForm<z.infer<typeof contactFormSchema>>({
    resolver: zodResolver(contactFormSchema),
    defaultValues: {
      name: "",
      email: "",
      subject: contactParams.get("subject")?.slice(0, 150) || (partnership ? "School or organization partnership" : ""),
      category: contactCategory,
      message: "",
    },
  });
  
  async function onSubmit(data: z.infer<typeof contactFormSchema>) {
    setIsSubmitting(true); setSubmissionError('');
    try {
      const result = await submitPublicInquiry({ name: data.name ?? '', email: data.email ?? '', subject: data.subject ?? '', category: data.category ?? '', message: data.message ?? '' });
      setReference(result.reference); setIsSubmitted(true); form.reset();
    } catch (error) { setSubmissionError(operationError(error)); }
    finally { setIsSubmitting(false); }
  }
  
  return (
    <MainLayout>
      <Helmet>
        <title>Contact Us - nishioHub</title>
      </Helmet>
      
      <div className="container mx-auto py-12 px-4">
        <div className="max-w-5xl mx-auto">
          <h1 className="text-4xl font-bold mb-4">Contact Us</h1>
          <p className="text-muted-foreground mb-10 max-w-2xl">
            Have questions or need assistance? Our team is here to help. Fill out the form below or use our other contact methods.
          </p>
          
          <div className="grid md:grid-cols-3 gap-8">
            {/* Contact Info */}
            <div className="md:col-span-1 space-y-6">
              <Card>
                <CardHeader>
                  <CardTitle className="flex items-center">
                    <Mail className="w-5 h-5 mr-2" />
                    Email
                  </CardTitle>
                </CardHeader>
                <CardContent>
                  <p>{platform.support_email}</p>
                  <p className="text-xs text-muted-foreground mt-1">
                    For general inquiries and support
                  </p>
                </CardContent>
              </Card>
              
              <Card>
                <CardHeader>
                  <CardTitle className="flex items-center">
                    <Phone className="w-5 h-5 mr-2" />
                    Phone
                  </CardTitle>
                </CardHeader>
                <CardContent>
                  <p>{platform.support_phone || "Contact us using the form"}</p>
                  <p className="text-xs text-muted-foreground mt-1">
                    Contact the team for availability
                  </p>
                </CardContent>
              </Card>
              
              <Card>
                <CardHeader>
                  <CardTitle className="flex items-center">
                    <MapPin className="w-5 h-5 mr-2" />
                    Office
                  </CardTitle>
                </CardHeader>
                <CardContent>
                  <p>123 Ntinda</p>
                  <p>Kampala, Uganda</p>
                  <p className="text-xs text-muted-foreground mt-1">
                    By appointment only
                  </p>
                </CardContent>
              </Card>
              
              <Card>
                <CardHeader>
                  <CardTitle className="flex items-center">
                    <Clock className="w-5 h-5 mr-2" />
                    Business Hours
                  </CardTitle>
                </CardHeader>
                <CardContent className="space-y-2">
                  <p className="flex justify-between">
                    <span>Monday - Friday</span>
                    <span>Contact the team</span>
                  </p>
                  <p className="flex justify-between">
                    <span>Saturday</span>
                    <span>10:00 AM - 2:00 PM EST</span>
                  </p>
                  <p className="flex justify-between">
                    <span>Sunday</span>
                    <span>Closed</span>
                  </p>
                </CardContent>
              </Card>
            </div>
            
            {/* Contact Form */}
            <div className="md:col-span-2">
              <Card>
                <CardHeader>
                  <CardTitle className="text-xl flex items-center">
                    <MessageSquare className="w-5 h-5 mr-2" />
                    Send us a Message
                  </CardTitle>
                  <CardDescription>
                    Fill out the form below and we'll get back to you as soon as possible.
                  </CardDescription>
                </CardHeader>
                <CardContent>
                  {isSubmitted ? (
                    <div className="text-center py-10">
                      <h3 className="text-2xl font-semibold mb-2">Thank You!</h3>
                      <p className="text-muted-foreground mb-6">
                        We've received your request. Please keep the reference below for your records.
                      </p>
                      <p className="break-all text-xs">Reference: {reference}</p><Button onClick={() => setIsSubmitted(false)}>
                        Send Another Message
                      </Button>
                    </div>
                  ) : (
                    <Form {...form}>
                      <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-6">{submissionError && <p role="alert" className="rounded-lg bg-red-50 p-3 text-sm text-red-700">{submissionError}</p>}
                        <div className="grid md:grid-cols-2 gap-6">
                          <FormField
                            control={form.control}
                            name="name"
                            render={({ field }) => (
                              <FormItem>
                                <FormLabel>Name</FormLabel>
                                <FormControl>
                                  <Input placeholder="Your full name" {...field} />
                                </FormControl>
                                <FormMessage />
                              </FormItem>
                            )}
                          />
                          
                          <FormField
                            control={form.control}
                            name="email"
                            render={({ field }) => (
                              <FormItem>
                                <FormLabel>Email</FormLabel>
                                <FormControl>
                                  <Input placeholder="your.email@example.com" {...field} />
                                </FormControl>
                                <FormMessage />
                              </FormItem>
                            )}
                          />
                        </div>
                        
                        <div className="grid md:grid-cols-2 gap-6">
                          <FormField
                            control={form.control}
                            name="subject"
                            render={({ field }) => (
                              <FormItem>
                                <FormLabel>Subject</FormLabel>
                                <FormControl>
                                  <Input placeholder="Brief subject of your inquiry" {...field} />
                                </FormControl>
                                <FormMessage />
                              </FormItem>
                            )}
                          />
                          
                          <FormField
                            control={form.control}
                            name="category"
                            render={({ field }) => (
                              <FormItem>
                                <FormLabel>Category</FormLabel>
                                <Select onValueChange={field.onChange} defaultValue={field.value}>
                                  <FormControl>
                                    <SelectTrigger>
                                      <SelectValue placeholder="Select a category" />
                                    </SelectTrigger>
                                  </FormControl>
                                  <SelectContent>
                                    <SelectItem value="partnership">School / Organization Partnership</SelectItem>
                                    <SelectItem value="general">General Inquiry</SelectItem>
                                    <SelectItem value="support">Technical Support</SelectItem>
                                    <SelectItem value="billing">Billing & Payments</SelectItem>
                                    <SelectItem value="mentorship">Mentorship Questions</SelectItem>
                                    <SelectItem value="feedback">Feedback & Suggestions</SelectItem>
                                    <SelectItem value="other">Other</SelectItem>
                                  </SelectContent>
                                </Select>
                                <FormMessage />
                              </FormItem>
                            )}
                          />
                        </div>
                        
                        <FormField
                          control={form.control}
                          name="message"
                          render={({ field }) => (
                            <FormItem>
                              <FormLabel>Message</FormLabel>
                              <FormControl>
                                <Textarea
                                  placeholder="Please describe your inquiry in detail..."
                                  className="min-h-[150px]"
                                  {...field}
                                />
                              </FormControl>
                              <FormDescription>
                                {field.value.length}/1000 characters
                              </FormDescription>
                              <FormMessage />
                            </FormItem>
                          )}
                        />
                        
                        <div className="flex justify-end">
                          <Button type="submit" disabled={isSubmitting}>
                            {isSubmitting ? "Sending..." : "Send Message"}
                          </Button>
                        </div>
                      </form>
                    </Form>
                  )}
                </CardContent>
              </Card>
            </div>
          </div>
          
          <Separator className="my-12" />
          
          {/* FAQ Section */}
          <div className="text-center mb-6">
            <h2 className="text-2xl font-semibold">Frequently Asked Questions</h2>
            <p className="text-muted-foreground">
              Check out our FAQ section for quick answers to common questions.
            </p>
          </div>
          
          <div className="grid md:grid-cols-2 gap-6 mb-12">
            <Card>
              <CardHeader>
                <CardTitle className="text-lg">How do I find a mentor?</CardTitle>
              </CardHeader>
              <CardContent>
                <p className="text-muted-foreground">
                  Browse our categories or use the search function to find mentors that match your needs.
                  You can filter by expertise, price range, and availability.
                </p>
              </CardContent>
            </Card>
            
            <Card>
              <CardHeader>
                <CardTitle className="text-lg">What if I need to cancel a session?</CardTitle>
              </CardHeader>
              <CardContent>
                <p className="text-muted-foreground">
                  You can cancel or reschedule sessions through your dashboard. Please note that cancellations
                  within 24 hours of the scheduled time may be subject to our cancellation policy.
                </p>
              </CardContent>
            </Card>
            
            <Card>
              <CardHeader>
                <CardTitle className="text-lg">How do I become a mentor?</CardTitle>
              </CardHeader>
              <CardContent>
                <p className="text-muted-foreground">
                  Select the "Mentor" role when registering or update your existing account. Complete your profile
                  with your expertise and experience, and set up your services and availability.
                </p>
              </CardContent>
            </Card>
            
            <Card>
              <CardHeader>
                <CardTitle className="text-lg">How do payments work?</CardTitle>
              </CardHeader>
              <CardContent>
                <p className="text-muted-foreground">
                  Payments are processed securely through our platform. Mentees pay when booking a session,
                  and mentors receive payments after the session is completed, minus our service fee.
                </p>
              </CardContent>
            </Card>
          </div>
          
          <div className="text-center">
            <Button asChild size="lg">
              <a href="/faq">View All FAQs</a>
            </Button>
          </div>
        </div>
      </div>
    </MainLayout>
  );
}