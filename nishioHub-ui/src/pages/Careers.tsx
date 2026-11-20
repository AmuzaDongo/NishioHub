import { MainLayout } from "@/components/layout/main-layout";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Separator } from "@/components/ui/separator";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { BriefcaseIcon, Building2, Clock, DollarSign, GlobeIcon, MapPin, Search, Star } from "lucide-react";
import { Link } from "react-router-dom";
import { Helmet } from "react-helmet";

// Mock job data
const jobOpenings = [
  {
    id: 1,
    title: "Senior Mentor Success Manager",
    department: "Operations",
    location: "Remote",
    type: "Full-time",
    salary: "$80,000 - $95,000",
    experience: "5+ years",
    description: "We're looking for an experienced Mentor Success Manager to help our mentors deliver exceptional mentorship experiences. You'll be responsible for onboarding new mentors, providing ongoing support, and developing strategies to enhance mentor engagement and success on our platform.",
    responsibilities: [
      "Develop and implement mentor onboarding programs",
      "Provide ongoing support to mentors",
      "Analyze mentor performance metrics and feedback",
      "Identify opportunities for mentor skill development",
      "Collaborate with product and marketing teams to improve the mentor experience"
    ],
    requirements: [
      "5+ years of experience in community management, customer success, or similar role",
      "Experience with mentorship programs or educational platforms",
      "Excellent communication and relationship-building skills",
      "Data-driven approach to problem-solving",
      "Bachelor's degree in business, education, or related field"
    ],
    postedDate: "July 15, 2025",
    featured: true
  },
  {
    id: 2,
    title: "Full Stack Developer",
    department: "Engineering",
    location: "San Francisco, CA (Hybrid)",
    type: "Full-time",
    salary: "$120,000 - $150,000",
    experience: "3+ years",
    description: "Join our engineering team to build and improve our mentorship platform. You'll work on feature development, performance optimization, and integrating new technologies to enhance the user experience for both mentors and mentees.",
    responsibilities: [
      "Develop and maintain features across the full stack",
      "Collaborate with product managers and designers",
      "Write clean, maintainable, and well-tested code",
      "Participate in code reviews and architectural discussions",
      "Help improve engineering standards and practices"
    ],
    requirements: [
      "3+ years of full stack development experience",
      "Proficiency in React, TypeScript, and Node.js",
      "Experience with database design and ORM frameworks",
      "Knowledge of CI/CD practices and tools",
      "Bachelor's degree in Computer Science or equivalent experience"
    ],
    postedDate: "July 10, 2025",
    featured: true
  },
  {
    id: 3,
    title: "Content Marketing Specialist",
    department: "Marketing",
    location: "Remote",
    type: "Full-time",
    salary: "$65,000 - $80,000",
    experience: "2+ years",
    description: "We're seeking a content marketing specialist to develop high-quality content that educates our audience about the benefits of mentorship and positions nishioHub as a thought leader in professional development.",
    responsibilities: [
      "Create blog posts, case studies, and educational materials",
      "Develop and manage content calendar",
      "Collaborate with design team on visual content",
      "Analyze content performance metrics",
      "Support SEO and social media strategies through content"
    ],
    requirements: [
      "2+ years of content marketing experience",
      "Strong writing and editing skills",
      "Experience with SEO best practices",
      "Knowledge of content management systems",
      "Bachelor's degree in Marketing, Communications, or related field"
    ],
    postedDate: "July 5, 2025",
    featured: false
  },
  {
    id: 4,
    title: "UX/UI Designer",
    department: "Product",
    location: "Remote",
    type: "Full-time",
    salary: "$90,000 - $110,000",
    experience: "3+ years",
    description: "Join our product team to create intuitive, accessible, and delightful user experiences for our mentorship platform. You'll work closely with product managers, developers, and user researchers to design features that meet the needs of mentors and mentees.",
    responsibilities: [
      "Design user-centered interfaces for web and mobile applications",
      "Create wireframes, prototypes, and high-fidelity designs",
      "Conduct user research and usability testing",
      "Develop and maintain our design system",
      "Collaborate with engineering on implementation details"
    ],
    requirements: [
      "3+ years of UX/UI design experience",
      "Proficiency in Figma or similar design tools",
      "Experience designing for web and mobile platforms",
      "Knowledge of accessibility standards",
      "Portfolio demonstrating strong UX thinking and visual design skills"
    ],
    postedDate: "June 28, 2025",
    featured: false
  },
  {
    id: 5,
    title: "Customer Support Specialist",
    department: "Operations",
    location: "Remote",
    type: "Full-time",
    salary: "$50,000 - $60,000",
    experience: "1+ years",
    description: "We're looking for a customer support specialist to assist our users with platform questions, troubleshooting, and account management. You'll be the voice of nishioHub and ensure our users have a positive experience.",
    responsibilities: [
      "Respond to user inquiries via email, chat, and phone",
      "Troubleshoot technical issues and escalate when necessary",
      "Maintain knowledge base articles and support documentation",
      "Collect and analyze user feedback",
      "Identify patterns in support requests to improve user experience"
    ],
    requirements: [
      "1+ years of customer support experience",
      "Excellent written and verbal communication skills",
      "Problem-solving mindset and attention to detail",
      "Experience with support ticketing systems",
      "Bachelor's degree or equivalent experience"
    ],
    postedDate: "June 20, 2025",
    featured: false
  },
  {
    id: 6,
    title: "Data Analyst",
    department: "Data",
    location: "Remote",
    type: "Full-time",
    salary: "$75,000 - $90,000",
    experience: "2+ years",
    description: "As a Data Analyst at nishioHub, you'll help us understand user behavior, optimize matchmaking algorithms, and identify opportunities for platform improvement through data analysis and visualization.",
    responsibilities: [
      "Analyze user engagement and retention metrics",
      "Build and maintain dashboards and reports",
      "Collaborate with product and marketing teams on A/B testing",
      "Develop models to improve mentor-mentee matching",
      "Present insights and recommendations to leadership"
    ],
    requirements: [
      "2+ years of data analysis experience",
      "Proficiency in SQL and data visualization tools",
      "Experience with Python or R for data analysis",
      "Strong statistical knowledge",
      "Bachelor's degree in Statistics, Mathematics, Computer Science, or related field"
    ],
    postedDate: "June 15, 2025",
    featured: false
  }
];

const departments = [
  "All Departments",
  "Engineering",
  "Product",
  "Marketing",
  "Operations",
  "Data",
  "HR"
];

const locations = [
  "All Locations",
  "Remote",
  "San Francisco, CA",
  "New York, NY",
  "London, UK"
];

export default function CareersPage() {
  const featuredJobs = jobOpenings.filter(job => job.featured);
  
  return (
    <MainLayout>
      <Helmet>
        <title>Careers - nishioHub</title>
      </Helmet>
      
      {/* Hero Section */}
      <section className="bg-gradient-to-br from-primary/10 to-accent/10 py-20">
        <div className="container mx-auto px-4 text-center">
          <h1 className="text-4xl md:text-5xl font-bold mb-6">Join Our Mission</h1>
          <p className="text-xl text-muted-foreground max-w-2xl mx-auto mb-8">
            Help us connect mentors and mentees around the world and make professional growth accessible to everyone.
          </p>
          <div className="flex flex-col md:flex-row justify-center gap-4">
            <Button size="lg" asChild>
              <a href="#openings">View Open Positions</a>
            </Button>
            <Button size="lg" variant="outline" asChild>
              <a href="#culture">Learn About Our Culture</a>
            </Button>
          </div>
        </div>
      </section>
      
      {/* Why Join Us Section */}
      <section id="culture" className="py-16 bg-background">
        <div className="container mx-auto px-4">
          <div className="text-center mb-12">
            <h2 className="text-3xl font-bold mb-4">Why Join nishioHub?</h2>
            <p className="text-muted-foreground max-w-2xl mx-auto">
              We're building a platform that changes lives by connecting people for meaningful mentorship. 
              Our team is passionate, collaborative, and committed to our mission.
            </p>
          </div>
          
          <div className="grid md:grid-cols-3 gap-8">
            <Card>
              <CardHeader>
                <div className="bg-primary/10 w-12 h-12 rounded-full flex items-center justify-center mb-4">
                  <Star className="h-6 w-6 text-primary" />
                </div>
                <CardTitle>Meaningful Impact</CardTitle>
              </CardHeader>
              <CardContent>
                <p className="text-muted-foreground">
                  Your work directly impacts thousands of mentorship relationships and helps people achieve their professional goals.
                </p>
              </CardContent>
            </Card>
            
            <Card>
              <CardHeader>
                <div className="bg-primary/10 w-12 h-12 rounded-full flex items-center justify-center mb-4">
                  <GlobeIcon className="h-6 w-6 text-primary" />
                </div>
                <CardTitle>Remote-First Culture</CardTitle>
              </CardHeader>
              <CardContent>
                <p className="text-muted-foreground">
                  We believe in flexibility and trust. Work from anywhere and maintain a healthy work-life balance.
                </p>
              </CardContent>
            </Card>
            
            <Card>
              <CardHeader>
                <div className="bg-primary/10 w-12 h-12 rounded-full flex items-center justify-center mb-4">
                  <Building2 className="h-6 w-6 text-primary" />
                </div>
                <CardTitle>Growth Opportunities</CardTitle>
              </CardHeader>
              <CardContent>
                <p className="text-muted-foreground">
                  We invest in your professional development with mentorship programs, learning stipends, and clear career paths.
                </p>
              </CardContent>
            </Card>
          </div>
          
          <div className="mt-16">
            <h3 className="text-2xl font-bold mb-6 text-center">Our Benefits</h3>
            <div className="grid grid-cols-2 md:grid-cols-4 gap-6 max-w-4xl mx-auto">
              <div className="text-center">
                <div className="bg-accent/10 w-16 h-16 rounded-full flex items-center justify-center mx-auto mb-4">
                  <DollarSign className="h-8 w-8 text-accent-foreground" />
                </div>
                <h4 className="font-semibold mb-2">Competitive Salary</h4>
                <p className="text-sm text-muted-foreground">Above-market compensation</p>
              </div>
              
              <div className="text-center">
                <div className="bg-accent/10 w-16 h-16 rounded-full flex items-center justify-center mx-auto mb-4">
                  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className="h-8 w-8 text-accent-foreground">
                    <path d="M16 2v4"></path>
                    <path d="M8 2v4"></path>
                    <path d="M3 10h18"></path>
                    <path d="M4 6h16a1 1 0 0 1 1 1v13a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1V7a1 1 0 0 1 1-1Z"></path>
                    <path d="M8 14h.01"></path>
                    <path d="M12 14h.01"></path>
                    <path d="M16 14h.01"></path>
                    <path d="M8 18h.01"></path>
                    <path d="M12 18h.01"></path>
                    <path d="M16 18h.01"></path>
                  </svg>
                </div>
                <h4 className="font-semibold mb-2">Unlimited PTO</h4>
                <p className="text-sm text-muted-foreground">Take time when you need it</p>
              </div>
              
              <div className="text-center">
                <div className="bg-accent/10 w-16 h-16 rounded-full flex items-center justify-center mx-auto mb-4">
                  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className="h-8 w-8 text-accent-foreground">
                    <path d="M3 14h3a2 2 0 0 1 2 2v3a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-7a9 9 0 0 1 18 0v7a2 2 0 0 1-2 2h-1a2 2 0 0 1-2-2v-3a2 2 0 0 1 2-2h3"></path>
                  </svg>
                </div>
                <h4 className="font-semibold mb-2">Health Benefits</h4>
                <p className="text-sm text-muted-foreground">Medical, dental & vision</p>
              </div>
              
              <div className="text-center">
                <div className="bg-accent/10 w-16 h-16 rounded-full flex items-center justify-center mx-auto mb-4">
                  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className="h-8 w-8 text-accent-foreground">
                    <path d="M12 20a8 8 0 1 0 0-16 8 8 0 0 0 0 16Z"></path>
                    <path d="M12 14a2 2 0 1 0 0-4 2 2 0 0 0 0 4Z"></path>
                    <path d="M12 2v2"></path>
                    <path d="M12 22v-2"></path>
                    <path d="m17 20.66-1-1.73"></path>
                    <path d="M11 10.27 7 3.34"></path>
                    <path d="m20.66 17-1.73-1"></path>
                    <path d="m3.34 7 1.73 1"></path>
                    <path d="M22 12h-2"></path>
                    <path d="M2 12h2"></path>
                    <path d="m20.66 7-1.73 1"></path>
                    <path d="m3.34 17 1.73-1"></path>
                    <path d="m17 3.34-1 1.73"></path>
                    <path d="m7 20.66 1-1.73"></path>
                  </svg>
                </div>
                <h4 className="font-semibold mb-2">Learning Budget</h4>
                <p className="text-sm text-muted-foreground">$1,000 annual stipend</p>
              </div>
            </div>
          </div>
        </div>
      </section>
      
      <Separator />
      
      {/* Open Positions */}
      <section id="openings" className="py-16">
        <div className="container mx-auto px-4">
          <h2 className="text-3xl font-bold mb-4 text-center">Open Positions</h2>
          <p className="text-muted-foreground mb-8 text-center max-w-2xl mx-auto">
            Join our growing team and help build the future of mentorship. We're looking for talented individuals who share our passion and values.
          </p>
          
          {/* Search and Filters */}
          <div className="mb-8 max-w-4xl mx-auto">
            <div className="relative mb-4">
              <Search className="absolute left-3 top-3 h-5 w-5 text-muted-foreground" />
              <Input placeholder="Search for positions..." className="pl-10" />
            </div>
            
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
              <select className="p-2 border rounded-md bg-background">
                {departments.map((dept) => (
                  <option key={dept} value={dept}>{dept}</option>
                ))}
              </select>
              
              <select className="p-2 border rounded-md bg-background">
                {locations.map((loc) => (
                  <option key={loc} value={loc}>{loc}</option>
                ))}
              </select>
              
              <select className="p-2 border rounded-md bg-background">
                <option value="all">All Job Types</option>
                <option value="full-time">Full-time</option>
                <option value="part-time">Part-time</option>
                <option value="contract">Contract</option>
                <option value="internship">Internship</option>
              </select>
            </div>
          </div>
          
          {/* Featured Jobs */}
          {featuredJobs.length > 0 && (
            <div className="mb-10">
              <h3 className="text-xl font-semibold mb-4">Featured Positions</h3>
              <div className="grid gap-4">
                {featuredJobs.map((job) => (
                  <Link to={`/careers/${job.id}`} key={job.id}>
                    <Card className="hover:border-primary transition-colors">
                      <CardHeader className="pb-2">
                        <div className="flex justify-between items-start">
                          <div>
                            <Badge className="mb-2">Featured</Badge>
                            <CardTitle>{job.title}</CardTitle>
                            <CardDescription className="flex items-center mt-1">
                              <BriefcaseIcon className="w-4 h-4 mr-1" />
                              {job.department}
                            </CardDescription>
                          </div>
                          <div className="text-right">
                            <p className="font-medium">{job.salary}</p>
                            <p className="text-sm text-muted-foreground mt-1">Posted: {job.postedDate}</p>
                          </div>
                        </div>
                      </CardHeader>
                      <CardContent className="py-2">
                        <p className="text-muted-foreground line-clamp-2">
                          {job.description}
                        </p>
                      </CardContent>
                      <CardFooter className="flex justify-between items-center pt-2">
                        <div className="flex items-center text-sm">
                          <MapPin className="w-4 h-4 mr-1 text-muted-foreground" />
                          <span>{job.location}</span>
                        </div>
                        <div className="flex items-center text-sm">
                          <Clock className="w-4 h-4 mr-1 text-muted-foreground" />
                          <span>{job.type}</span>
                        </div>
                      </CardFooter>
                    </Card>
                  </Link>
                ))}
              </div>
            </div>
          )}
          
          {/* All Jobs */}
          <div>
            <h3 className="text-xl font-semibold mb-4">All Positions</h3>
            <div className="grid gap-4">
              {jobOpenings.map((job) => (
                <Link to={`/careers/${job.id}`} key={job.id}>
                  <Card className="hover:border-primary transition-colors">
                    <CardHeader className="pb-2">
                      <div className="flex justify-between items-start">
                        <div>
                          <CardTitle>{job.title}</CardTitle>
                          <CardDescription className="flex items-center mt-1">
                            <BriefcaseIcon className="w-4 h-4 mr-1" />
                            {job.department}
                          </CardDescription>
                        </div>
                        <div className="text-right">
                          <p className="font-medium">{job.salary}</p>
                          <p className="text-sm text-muted-foreground mt-1">Posted: {job.postedDate}</p>
                        </div>
                      </div>
                    </CardHeader>
                    <CardContent className="py-2">
                      <p className="text-muted-foreground line-clamp-2">
                        {job.description}
                      </p>
                    </CardContent>
                    <CardFooter className="flex justify-between items-center pt-2">
                      <div className="flex items-center text-sm">
                        <MapPin className="w-4 h-4 mr-1 text-muted-foreground" />
                        <span>{job.location}</span>
                      </div>
                      <div className="flex items-center text-sm">
                        <Clock className="w-4 h-4 mr-1 text-muted-foreground" />
                        <span>{job.type}</span>
                      </div>
                    </CardFooter>
                  </Card>
                </Link>
              ))}
            </div>
            
            {/* Pagination */}
            <div className="flex justify-center mt-8">
              <Button variant="outline" className="mr-2">Previous</Button>
              <Button variant="outline" className="mx-1">1</Button>
              <Button className="mx-1">2</Button>
              <Button variant="outline" className="mx-1">3</Button>
              <Button variant="outline" className="ml-2">Next</Button>
            </div>
          </div>
        </div>
      </section>
      
      {/* CTA Section */}
      <section className="bg-gradient-to-br from-primary/10 to-accent/10 py-16">
        <div className="container mx-auto px-4 text-center">
          <h2 className="text-3xl font-bold mb-4">Don't See a Perfect Fit?</h2>
          <p className="text-muted-foreground mb-6 max-w-2xl mx-auto">
            We're always on the lookout for talented individuals who share our passion for mentorship. 
            Send us your resume and we'll keep you in mind for future opportunities.
          </p>
          <Button size="lg" asChild>
            <a href="mailto:careers@nishioHub.example">Submit Your Resume</a>
          </Button>
        </div>
      </section>
    </MainLayout>
  );
}