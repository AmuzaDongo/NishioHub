import { MainLayout } from "@/components/layout/main-layout";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Separator } from "@/components/ui/separator";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Calendar, Search, Tag, User } from "lucide-react";
import { Link } from "react-router-dom";
import { Helmet } from "react-helmet";

// Mock blog data
const blogPosts = [
  {
    id: 1,
    title: "10 Tips for Successful Mentor-Mentee Relationships",
    excerpt: "Building a successful mentor-mentee relationship requires clear communication, defined goals, and mutual respect. In this article, we explore the key elements that make mentoring partnerships thrive.",
    category: "mentorship",
    date: "July 18, 2025",
    author: "Sarah Johnson",
    authorRole: "Senior Mentor Success Manager",
    authorImage: "https://i.pravatar.cc/150?img=1",
    image: "https://images.unsplash.com/photo-1521737604893-d14cc237f11d",
    tags: ["mentorship", "communication", "career growth"]
  },
  {
    id: 2,
    title: "How to Prepare for Your First Mentoring Session",
    excerpt: "First mentoring sessions can be nerve-wracking. Learn how to prepare effectively, set expectations, and make a great impression with your new mentor.",
    category: "tips",
    date: "July 15, 2025",
    author: "Michael Chen",
    authorRole: "Career Development Specialist",
    authorImage: "https://i.pravatar.cc/150?img=3",
    image: "https://images.unsplash.com/photo-1517245386807-bb43f82c33c4",
    tags: ["first session", "preparation", "mentee tips"]
  },
  {
    id: 3,
    title: "The Growing Demand for Tech Mentorship in 2025",
    excerpt: "With the rapid evolution of technology, mentorship in tech fields is more valuable than ever. Discover the trends and benefits of tech mentorship in today's market.",
    category: "industry",
    date: "July 10, 2025",
    author: "Priya Patel",
    authorRole: "Tech Industry Analyst",
    authorImage: "https://i.pravatar.cc/150?img=5",
    image: "https://images.unsplash.com/photo-1531482615713-2afd69097998",
    tags: ["tech industry", "trends", "career development"]
  },
  {
    id: 4,
    title: "Mentorship vs. Coaching: Understanding the Differences",
    excerpt: "While often used interchangeably, mentorship and coaching serve different purposes. This article breaks down the key differences and helps you determine which approach is right for your needs.",
    category: "education",
    date: "July 5, 2025",
    author: "James Wilson",
    authorRole: "Professional Development Coach",
    authorImage: "https://i.pravatar.cc/150?img=8",
    image: "https://images.unsplash.com/photo-1522071820081-009f0129c71c",
    tags: ["coaching", "mentorship", "professional development"]
  },
  {
    id: 5,
    title: "How to Become a More Effective Mentor",
    excerpt: "Effective mentoring requires more than just expertise in your field. Explore strategies to enhance your listening skills, provide constructive feedback, and guide mentees toward success.",
    category: "mentorship",
    date: "June 28, 2025",
    author: "Elena Rodriguez",
    authorRole: "Executive Mentor",
    authorImage: "https://i.pravatar.cc/150?img=10",
    image: "https://images.unsplash.com/photo-1573497491765-dccce02b29df",
    tags: ["mentor tips", "leadership", "feedback"]
  },
  {
    id: 6,
    title: "Remote Mentorship: Making Virtual Connections Work",
    excerpt: "In an increasingly remote world, virtual mentorship has become essential. Learn best practices for building meaningful mentor-mentee relationships in a digital environment.",
    category: "remote",
    date: "June 22, 2025",
    author: "Thomas Lee",
    authorRole: "Remote Work Strategist",
    authorImage: "https://i.pravatar.cc/150?img=12",
    image: "https://images.unsplash.com/photo-1516321318423-f06f85e504b3",
    tags: ["remote mentorship", "virtual communication", "digital tools"]
  }
];

const categories = [
  { id: "all", name: "All Posts" },
  { id: "mentorship", name: "Mentorship" },
  { id: "tips", name: "Tips & Advice" },
  { id: "industry", name: "Industry Insights" },
  { id: "education", name: "Education" },
  { id: "remote", name: "Remote Work" },
];

const featuredPost = blogPosts[0];
const recentPosts = blogPosts.slice(1, 4);
const allPosts = blogPosts;

export default function BlogPage() {
  return (
    <MainLayout>
      <Helmet>
        <title>Blog - nishioHub</title>
      </Helmet>
      
      <div className="container mx-auto py-12 px-4">
        {/* Featured Post */}
        <div className="mb-16">
          <div className="grid lg:grid-cols-5 gap-8">
            <div className="lg:col-span-3">
              <Link to={`/blog/${featuredPost.id}`}>
                <div className="relative h-[400px] rounded-xl overflow-hidden">
                  <img 
                    src={featuredPost.image} 
                    alt={featuredPost.title}
                    className="w-full h-full object-cover transition-transform duration-300 hover:scale-105"
                  />
                  <div className="absolute inset-0 bg-gradient-to-t from-black/70 via-black/30 to-transparent flex flex-col justify-end p-6 text-white">
                    <Badge className="w-fit mb-2">{featuredPost.category}</Badge>
                    <h1 className="text-3xl font-bold mb-2">{featuredPost.title}</h1>
                    <p className="mb-4 line-clamp-2">{featuredPost.excerpt}</p>
                    <div className="flex items-center">
                      <img 
                        src={featuredPost.authorImage} 
                        alt={featuredPost.author}
                        className="w-10 h-10 rounded-full mr-3"
                      />
                      <div>
                        <p className="font-medium">{featuredPost.author}</p>
                        <div className="flex items-center text-sm opacity-90">
                          <Calendar className="w-4 h-4 mr-1" />
                          <span>{featuredPost.date}</span>
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              </Link>
            </div>
            
            <div className="lg:col-span-2">
              <div className="h-full flex flex-col">
                <h2 className="text-2xl font-bold mb-6">Recent Posts</h2>
                <div className="space-y-6 flex-grow">
                  {recentPosts.map((post) => (
                    <Link to={`/blog/${post.id}`} key={post.id}>
                      <Card className="h-[120px] flex overflow-hidden hover:bg-accent/50 transition-colors">
                        <div className="w-1/3 h-full">
                          <img 
                            src={post.image} 
                            alt={post.title}
                            className="w-full h-full object-cover"
                          />
                        </div>
                        <div className="w-2/3 p-4 flex flex-col justify-between">
                          <div>
                            <Badge className="mb-1">{post.category}</Badge>
                            <h3 className="font-semibold line-clamp-2">{post.title}</h3>
                          </div>
                          <div className="flex items-center text-xs text-muted-foreground">
                            <Calendar className="w-3 h-3 mr-1" />
                            <span>{post.date}</span>
                          </div>
                        </div>
                      </Card>
                    </Link>
                  ))}
                </div>
                
                <div className="mt-6">
                  <Button asChild variant="outline" className="w-full">
                    <Link to="/blog?view=all">View All Posts</Link>
                  </Button>
                </div>
              </div>
            </div>
          </div>
        </div>
        
        <Separator className="my-12" />
        
        {/* Blog Content */}
        <div className="grid lg:grid-cols-4 gap-10">
          {/* Sidebar */}
          <div className="lg:col-span-1 space-y-8">
            <div>
              <h3 className="text-lg font-semibold mb-4">Search</h3>
              <div className="relative">
                <Search className="absolute left-3 top-3 h-4 w-4 text-muted-foreground" />
                <Input placeholder="Search articles..." className="pl-10" />
              </div>
            </div>
            
            <div>
              <h3 className="text-lg font-semibold mb-4">Categories</h3>
              <div className="space-y-2">
                {categories.map((category) => (
                  <Link to={`/blog?category=${category.id}`} key={category.id}>
                    <Button 
                      variant="ghost" 
                      className="w-full justify-start"
                    >
                      {category.name}
                    </Button>
                  </Link>
                ))}
              </div>
            </div>
            
            <div>
              <h3 className="text-lg font-semibold mb-4">Popular Tags</h3>
              <div className="flex flex-wrap gap-2">
                <Badge variant="secondary">mentorship</Badge>
                <Badge variant="secondary">career growth</Badge>
                <Badge variant="secondary">tech industry</Badge>
                <Badge variant="secondary">leadership</Badge>
                <Badge variant="secondary">remote work</Badge>
                <Badge variant="secondary">coaching</Badge>
                <Badge variant="secondary">skill development</Badge>
              </div>
            </div>
            
            <div>
              <h3 className="text-lg font-semibold mb-4">Subscribe</h3>
              <Card>
                <CardContent className="pt-6">
                  <p className="text-sm text-muted-foreground mb-4">
                    Get the latest articles and resources sent straight to your inbox.
                  </p>
                  <Input placeholder="Your email" className="mb-3" />
                  <Button className="w-full">Subscribe</Button>
                </CardContent>
              </Card>
            </div>
          </div>
          
          {/* Main Content */}
          <div className="lg:col-span-3">
            <Tabs defaultValue="latest">
              <div className="flex justify-between items-center mb-8">
                <h2 className="text-2xl font-bold">All Articles</h2>
                <TabsList>
                  <TabsTrigger value="latest">Latest</TabsTrigger>
                  <TabsTrigger value="popular">Popular</TabsTrigger>
                </TabsList>
              </div>
              
              <TabsContent value="latest" className="space-y-0 mt-0">
                <div className="grid md:grid-cols-2 gap-6">
                  {allPosts.map((post) => (
                    <Card key={post.id} className="overflow-hidden">
                      <div className="h-[200px] overflow-hidden">
                        <img 
                          src={post.image} 
                          alt={post.title}
                          className="w-full h-full object-cover transition-transform duration-300 hover:scale-105"
                        />
                      </div>
                      <CardHeader>
                        <div className="flex items-center justify-between">
                          <Badge>{post.category}</Badge>
                          <div className="flex items-center text-sm text-muted-foreground">
                            <Calendar className="w-4 h-4 mr-1" />
                            <span>{post.date}</span>
                          </div>
                        </div>
                        <CardTitle className="text-xl mt-2">
                          <Link to={`/blog/${post.id}`} className="hover:text-primary">
                            {post.title}
                          </Link>
                        </CardTitle>
                        <CardDescription className="line-clamp-2">
                          {post.excerpt}
                        </CardDescription>
                      </CardHeader>
                      <CardFooter className="flex justify-between items-center pt-0">
                        <div className="flex items-center">
                          <img 
                            src={post.authorImage} 
                            alt={post.author}
                            className="w-8 h-8 rounded-full mr-2"
                          />
                          <span className="text-sm font-medium">{post.author}</span>
                        </div>
                        <div className="flex items-center">
                          <Tag className="w-4 h-4 mr-1 text-muted-foreground" />
                          <span className="text-sm text-muted-foreground">{post.tags[0]}</span>
                        </div>
                      </CardFooter>
                    </Card>
                  ))}
                </div>
                
                <div className="flex justify-center mt-10">
                  <Button variant="outline" className="mr-2">Previous</Button>
                  <Button>Next</Button>
                </div>
              </TabsContent>
              
              <TabsContent value="popular" className="space-y-0 mt-0">
                <div className="grid md:grid-cols-2 gap-6">
                  {allPosts.slice().reverse().map((post) => (
                    <Card key={post.id} className="overflow-hidden">
                      <div className="h-[200px] overflow-hidden">
                        <img 
                          src={post.image} 
                          alt={post.title}
                          className="w-full h-full object-cover transition-transform duration-300 hover:scale-105"
                        />
                      </div>
                      <CardHeader>
                        <div className="flex items-center justify-between">
                          <Badge>{post.category}</Badge>
                          <div className="flex items-center text-sm text-muted-foreground">
                            <Calendar className="w-4 h-4 mr-1" />
                            <span>{post.date}</span>
                          </div>
                        </div>
                        <CardTitle className="text-xl mt-2">
                          <Link to={`/blog/${post.id}`} className="hover:text-primary">
                            {post.title}
                          </Link>
                        </CardTitle>
                        <CardDescription className="line-clamp-2">
                          {post.excerpt}
                        </CardDescription>
                      </CardHeader>
                      <CardFooter className="flex justify-between items-center pt-0">
                        <div className="flex items-center">
                          <img 
                            src={post.authorImage} 
                            alt={post.author}
                            className="w-8 h-8 rounded-full mr-2"
                          />
                          <span className="text-sm font-medium">{post.author}</span>
                        </div>
                        <div className="flex items-center">
                          <Tag className="w-4 h-4 mr-1 text-muted-foreground" />
                          <span className="text-sm text-muted-foreground">{post.tags[0]}</span>
                        </div>
                      </CardFooter>
                    </Card>
                  ))}
                </div>
                
                <div className="flex justify-center mt-10">
                  <Button variant="outline" className="mr-2">Previous</Button>
                  <Button>Next</Button>
                </div>
              </TabsContent>
            </Tabs>
          </div>
        </div>
      </div>
    </MainLayout>
  );
}