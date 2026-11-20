import { useState, useEffect } from "react";
import { useParams, Link, useNavigate } from "react-router-dom";
import { MainLayout } from "@/components/layout/main-layout";
import { useServices } from "@/lib/services-context";
import { Search, Filter, Star, Clock, DollarSign, ArrowRight } from "lucide-react";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from "@/components/ui/card";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { Badge } from "@/components/ui/badge";
import { Helmet } from "react-helmet-async";
import { Separator } from "@/components/ui/separator";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import {
  Accordion,
  AccordionContent,
  AccordionItem,
  AccordionTrigger,
} from "@/components/ui/accordion";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";

export default function CategoryDetail() {
  const { slug } = useParams<{ slug: string }>();
  const navigate = useNavigate();
  const { categories, services, getServicesInCategory, getMentorById } = useServices();
  const [searchQuery, setSearchQuery] = useState("");
  const [priceRange, setPriceRange] = useState<[number, number]>([0, 1000]);
  const [sortBy, setSortBy] = useState("recommended");
  const [filterRating, setFilterRating] = useState(0);
  const [viewMode, setViewMode] = useState("grid");
  
  // Find the category by slug
  const category = categories.find(cat => cat.slug === slug);
  
  useEffect(() => {
    if (!category && categories.length > 0) {
      navigate("/categories", { replace: true });
    }
  }, [category, categories, navigate]);
  
  if (!category) {
    return null;
  }
  
  // Get services for this category
  const categoryServices = getServicesInCategory(category.id);
  
  // Filter services based on search query and filters
  const filteredServices = categoryServices.filter(service => {
    const matchesSearch = service.title.toLowerCase().includes(searchQuery.toLowerCase()) || 
                         service.description.toLowerCase().includes(searchQuery.toLowerCase()) ||
                         service.tags.some(tag => tag.toLowerCase().includes(searchQuery.toLowerCase()));
    const matchesPrice = service.price >= priceRange[0] && service.price <= priceRange[1];
    
    // Get average rating for the service
    const mentor = service.mentor || getMentorById(String(service.mentorId));
    const avgRating = mentor?.rating || 0;
    const matchesRating = filterRating === 0 || avgRating >= filterRating;
    
    return matchesSearch && matchesPrice && matchesRating;
  });
  
  // Sort services
  const sortedServices = [...filteredServices].sort((a, b) => {
    if (sortBy === "price-asc") {
      return a.price - b.price;
    } else if (sortBy === "price-desc") {
      return b.price - a.price;
    } else if (sortBy === "rating-desc") {
      const mentorA = a.mentor || getMentorById(String(a.mentorId));
      const mentorB = b.mentor || getMentorById(String(b.mentorId));
      return (mentorB?.rating || 0) - (mentorA?.rating || 0);
    }
    // Default: recommended
    return 0;
  });

  return (
    <MainLayout>
      <Helmet>
        <title>{category.name} | nishioHub</title>
        <meta name="description" content={`Browse ${category.name} mentors and services on nishioHub`} />
      </Helmet>
      
      <div className="container py-8">
        {/* Hero Section */}
        <div className="mb-8">
          <div className="flex items-center gap-2 text-sm text-muted-foreground mb-2">
            <Link to="/categories">Categories</Link>
            <ArrowRight className="h-3 w-3" />
            <span>{category.name}</span>
          </div>
          
          <div className="flex flex-col md:flex-row items-start md:items-center gap-6">
            <div className="w-24 h-24 rounded-md overflow-hidden bg-muted flex items-center justify-center">
              {(category.image_url || category.iconPath) ? (
                <img
                  src={category.image_url || category.iconPath || undefined}
                  alt={category.name}
                  className="w-full h-full object-cover"
                />
              ) : (
                <span className="text-3xl font-bold text-muted-foreground">
                  {category.name.charAt(0)}
                </span>
              )}
            </div>
            <div>
              <h1 className="text-3xl md:text-4xl font-bold">{category.name}</h1>
              {category.description && (
                <p className="text-muted-foreground mt-2 max-w-3xl">{category.description}</p>
              )}
              <div className="flex flex-wrap gap-2 mt-4">
                {category.topics && category.topics.map((topic, index) => (
                  <Badge key={index} variant="secondary">{topic}</Badge>
                ))}
              </div>
            </div>
          </div>
        </div>

        {/* Stats Bar */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
          <Card>
            <CardContent className="pt-6">
              <div className="flex items-center gap-4">
                <div className="bg-primary/10 p-3 rounded-full">
                  <svg className="h-6 w-6 text-primary" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z" />
                  </svg>
                </div>
                <div>
                  <h4 className="text-xl font-bold">{filteredServices.length}</h4>
                  <p className="text-muted-foreground text-sm">Available Mentors</p>
                </div>
              </div>
            </CardContent>
          </Card>
          <Card>
            <CardContent className="pt-6">
              <div className="flex items-center gap-4">
                <div className="bg-primary/10 p-3 rounded-full">
                  <Star className="h-6 w-6 text-primary" />
                </div>
                <div>
                  <h4 className="text-xl font-bold">4.8</h4>
                  <p className="text-muted-foreground text-sm">Average Rating</p>
                </div>
              </div>
            </CardContent>
          </Card>
          <Card>
            <CardContent className="pt-6">
              <div className="flex items-center gap-4">
                <div className="bg-primary/10 p-3 rounded-full">
                  <Clock className="h-6 w-6 text-primary" />
                </div>
                <div>
                  <h4 className="text-xl font-bold">60 min</h4>
                  <p className="text-muted-foreground text-sm">Average Session</p>
                </div>
              </div>
            </CardContent>
          </Card>
        </div>

        {/* Search & Filter */}
        <div className="mb-8 flex flex-col md:flex-row gap-4">
          <div className="relative flex-1">
            <Search className="absolute left-3 top-3 h-4 w-4 text-muted-foreground" />
            <Input
              placeholder={`Search in ${category.name}...`}
              className="pl-10"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
            />
          </div>
          <Dialog>
            <DialogTrigger asChild>
              <Button variant="outline" className="gap-2">
                <Filter className="h-4 w-4" />
                Filters
              </Button>
            </DialogTrigger>
            <DialogContent className="sm:max-w-md">
              <DialogHeader>
                <DialogTitle>Filter Options</DialogTitle>
                <DialogDescription>
                  Refine your search to find the perfect mentor
                </DialogDescription>
              </DialogHeader>
              <div className="grid gap-6 py-4">
                <div className="space-y-2">
                  <h4 className="font-medium text-sm">Price Range</h4>
                  <div className="grid grid-cols-2 gap-4">
                    <div>
                      <label className="text-xs text-muted-foreground">Min Price</label>
                      <Input 
                        type="number"
                        min={0}
                        value={priceRange[0]}
                        onChange={(e) => setPriceRange([parseInt(e.target.value) || 0, priceRange[1]])}
                      />
                    </div>
                    <div>
                      <label className="text-xs text-muted-foreground">Max Price</label>
                      <Input 
                        type="number"
                        min={0}
                        value={priceRange[1]}
                        onChange={(e) => setPriceRange([priceRange[0], parseInt(e.target.value) || 1000])}
                      />
                    </div>
                  </div>
                </div>
                <div className="space-y-2">
                  <h4 className="font-medium text-sm">Rating</h4>
                  <Select 
                    value={filterRating.toString()} 
                    onValueChange={(value) => setFilterRating(parseInt(value))}
                  >
                    <SelectTrigger>
                      <SelectValue placeholder="Any rating" />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="0">Any rating</SelectItem>
                      <SelectItem value="4">4+ stars</SelectItem>
                      <SelectItem value="4.5">4.5+ stars</SelectItem>
                      <SelectItem value="5">5 stars only</SelectItem>
                    </SelectContent>
                  </Select>
                </div>
              </div>
              <div className="flex justify-end">
                <Button>Apply Filters</Button>
              </div>
            </DialogContent>
          </Dialog>
          <Select value={sortBy} onValueChange={setSortBy}>
            <SelectTrigger className="w-[200px]">
              <SelectValue placeholder="Sort by" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="recommended">Recommended</SelectItem>
              <SelectItem value="price-asc">Price: Low to High</SelectItem>
              <SelectItem value="price-desc">Price: High to Low</SelectItem>
              <SelectItem value="rating-desc">Highest Rated</SelectItem>
            </SelectContent>
          </Select>
        </div>

        {/* Services List */}
        <Tabs defaultValue={viewMode} onValueChange={setViewMode} className="mb-6">
          <div className="flex items-center justify-between">
            <h2 className="text-xl font-semibold">
              {sortedServices.length} {sortedServices.length === 1 ? 'Service' : 'Services'} Available
            </h2>
            <TabsList>
              <TabsTrigger value="grid">Grid</TabsTrigger>
              <TabsTrigger value="list">List</TabsTrigger>
            </TabsList>
          </div>
          
          {/* Grid View */}
          <TabsContent value="grid">
            {sortedServices.length > 0 ? (
              <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6 mt-6">
                {sortedServices.map((service) => {
                  const mentor = service.mentor || getMentorById(String(service.mentorId));
                  return (
                    <Link to={`/services/${service.id}`} key={service.id} className="group">
                      <Card className="overflow-hidden transition-all hover:shadow-md h-full">
                        <div className="aspect-video w-full overflow-hidden">
                          <img 
                            src={service.imageUrl || "https://placehold.co/600x400/e2e8f0/475569?text=Service+Image"}
                            alt={service.title}
                            className="w-full h-full object-cover transition-transform duration-300 group-hover:scale-105"
                          />
                        </div>
                        <CardHeader className="p-4">
                          <div className="flex justify-between items-start">
                            <CardTitle className="text-lg">{service.title}</CardTitle>
                            <span className="font-bold">${service.price}</span>
                          </div>
                          <CardDescription className="line-clamp-2">{service.description}</CardDescription>
                        </CardHeader>
                        <CardContent className="p-4 pt-0">
                          <div className="flex items-center gap-2">
                            <Avatar className="h-7 w-7">
                              <AvatarImage src={mentor?.avatar} />
                              <AvatarFallback>{mentor?.name?.charAt(0) || "?"}</AvatarFallback>
                            </Avatar>
                            <span className="text-sm font-medium">{mentor?.name}</span>
                            {mentor && (
                              <div className="flex items-center ml-auto">
                                <Star className="h-4 w-4 text-yellow-400 fill-yellow-400" />
                                <span className="text-sm font-medium ml-1">{mentor.rating}</span>
                              </div>
                            )}
                          </div>
                        </CardContent>
                        <CardFooter className="p-4 pt-0">
                          <div className="flex justify-between items-center w-full">
                            <div className="flex items-center gap-1">
                              <Clock className="h-4 w-4 text-muted-foreground" />
                              <span className="text-xs text-muted-foreground">{service.duration} min</span>
                            </div>
                            <Button variant="ghost" size="sm" className="gap-1 group-hover:text-primary">
                              View Details
                              <ArrowRight className="h-3 w-3" />
                            </Button>
                          </div>
                        </CardFooter>
                      </Card>
                    </Link>
                  );
                })}
              </div>
            ) : (
              <div className="text-center py-16 bg-muted/50 rounded-lg mt-6">
                <h3 className="text-lg font-semibold">No services found</h3>
                <p className="text-muted-foreground mt-1">Try adjusting your search or filters</p>
                <Button className="mt-4" onClick={() => {
                  setSearchQuery("");
                  setPriceRange([0, 1000]);
                  setFilterRating(0);
                }}>
                  Reset Filters
                </Button>
              </div>
            )}
          </TabsContent>
          
          {/* List View */}
          <TabsContent value="list">
            {sortedServices.length > 0 ? (
              <div className="space-y-4 mt-6">
                {sortedServices.map((service) => {
                  const mentor = service.mentor || getMentorById(String(service.mentorId));
                  return (
                    <Link to={`/services/${service.id}`} key={service.id} className="group">
                      <Card className="overflow-hidden transition-all hover:shadow-md">
                        <div className="flex flex-col md:flex-row">
                          <div className="md:w-48 w-full">
                            <img 
                              src={service.imageUrl || "https://placehold.co/600x400/e2e8f0/475569?text=Service+Image"}
                              alt={service.title}
                              className="w-full h-full object-cover md:h-48 h-40"
                            />
                          </div>
                          <div className="flex-1 p-4">
                            <div className="flex flex-col md:flex-row justify-between gap-2">
                              <div>
                                <h3 className="text-lg font-semibold">{service.title}</h3>
                                <p className="text-muted-foreground line-clamp-2 mt-1">{service.description}</p>
                              </div>
                              <div className="text-lg font-bold md:text-right whitespace-nowrap">
                                ${service.price}
                              </div>
                            </div>
                            
                            <div className="flex flex-wrap gap-1 mt-3">
                              {service.tags.slice(0, 3).map((tag, index) => (
                                <Badge key={index} variant="secondary" className="font-normal">{tag}</Badge>
                              ))}
                              {service.tags.length > 3 && (
                                <Badge variant="outline" className="font-normal">+{service.tags.length - 3} more</Badge>
                              )}
                            </div>
                            
                            <div className="flex items-center mt-4">
                              <Avatar className="h-6 w-6 mr-2">
                                <AvatarImage src={mentor?.avatar} />
                                <AvatarFallback>{mentor?.name?.charAt(0) || "?"}</AvatarFallback>
                              </Avatar>
                              <span className="text-sm">{mentor?.name}</span>
                              {mentor && (
                                <div className="flex items-center ml-4">
                                  <Star className="h-3 w-3 text-yellow-400 fill-yellow-400" />
                                  <span className="text-xs ml-1">{mentor.rating}</span>
                                </div>
                              )}
                              <div className="flex items-center ml-4">
                                <Clock className="h-3 w-3 text-muted-foreground" />
                                <span className="text-xs ml-1 text-muted-foreground">{service.duration} min</span>
                              </div>
                              <Button variant="ghost" size="sm" className="ml-auto gap-1 group-hover:text-primary">
                                View Details
                                <ArrowRight className="h-3 w-3" />
                              </Button>
                            </div>
                          </div>
                        </div>
                      </Card>
                    </Link>
                  );
                })}
              </div>
            ) : (
              <div className="text-center py-16 bg-muted/50 rounded-lg mt-6">
                <h3 className="text-lg font-semibold">No services found</h3>
                <p className="text-muted-foreground mt-1">Try adjusting your search or filters</p>
                <Button className="mt-4" onClick={() => {
                  setSearchQuery("");
                  setPriceRange([0, 1000]);
                  setFilterRating(0);
                }}>
                  Reset Filters
                </Button>
              </div>
            )}
          </TabsContent>
        </Tabs>

        {/* Related Categories */}
        <div className="mt-12">
          <h2 className="text-2xl font-bold mb-6">Related Categories</h2>
          <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
            {categories
              .filter(cat => cat.id !== category.id)
              .slice(0, 4)
              .map(cat => (
                <Link to={`/categories/${cat.slug}`} key={cat.id}>
                  <Card className="hover:shadow-md transition-shadow">
                    <CardHeader>
                      <CardTitle>{cat.name}</CardTitle>
                    </CardHeader>
                    <CardFooter className="pt-0">
                      <Button variant="ghost" className="w-full justify-start pl-2">
                        Explore
                        <ArrowRight className="ml-2 h-4 w-4" />
                      </Button>
                    </CardFooter>
                  </Card>
                </Link>
              ))}
          </div>
        </div>

        {/* FAQ */}
        <div className="mt-12">
          <h2 className="text-2xl font-bold mb-6">Frequently Asked Questions</h2>
          <Accordion type="single" collapsible className="w-full">
            <AccordionItem value="item-1">
              <AccordionTrigger>How do I choose the right mentor in this category?</AccordionTrigger>
              <AccordionContent>
                To find the right mentor, consider factors like their expertise, experience, teaching style, and reviews from other mentees. 
                You can also filter by price, rating, and specific skills to narrow down your options.
              </AccordionContent>
            </AccordionItem>
            <AccordionItem value="item-2">
              <AccordionTrigger>What happens during a mentoring session?</AccordionTrigger>
              <AccordionContent>
                Mentoring sessions are personalized to your needs. You'll typically discuss your goals, challenges, and receive guidance, 
                feedback, and resources from your mentor. Sessions can include screen sharing, code reviews, portfolio feedback, or 
                general career advice depending on the mentor and your objectives.
              </AccordionContent>
            </AccordionItem>
            <AccordionItem value="item-3">
              <AccordionTrigger>How do I prepare for my first session?</AccordionTrigger>
              <AccordionContent>
                For your first session, prepare by: 1) Setting clear goals for what you want to achieve, 2) Preparing specific questions, 
                3) Gathering relevant materials or work samples to share, and 4) Testing your audio/video setup before the meeting.
              </AccordionContent>
            </AccordionItem>
            <AccordionItem value="item-4">
              <AccordionTrigger>Can I get a refund if I'm not satisfied?</AccordionTrigger>
              <AccordionContent>
                Yes, nishioHub offers a satisfaction guarantee. If you're not satisfied with your first session, you can request a refund 
                within 24 hours. For details, please review our refund policy in the Help Center.
              </AccordionContent>
            </AccordionItem>
          </Accordion>
        </div>

        {/* CTA */}
        <div className="mt-12 bg-gradient-to-r from-primary/10 via-primary/5 to-primary/10 rounded-lg p-8 text-center">
          <h2 className="text-2xl font-bold mb-2">Ready to find your perfect {category.name} mentor?</h2>
          <p className="text-muted-foreground mb-6 max-w-2xl mx-auto">
            Take the next step in your journey and connect with experienced professionals who can help you achieve your goals.
          </p>
          <div className="flex flex-wrap justify-center gap-4">
            <Button asChild size="lg">
              <Link to={`/services?category=${category.slug}`}>Browse All {category.name} Services</Link>
            </Button>
            <Button asChild variant="outline" size="lg">
              <Link to="/how-it-works">Learn How It Works</Link>
            </Button>
          </div>
        </div>
      </div>
    </MainLayout>
  );
}