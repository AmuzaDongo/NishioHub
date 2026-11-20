import { MentorCardSkeletonGrid } from '@/components/loaders/MentorCardSkeleton';
import { useState, useEffect } from "react";
import { useLocation, Link } from "react-router-dom";
import { MainLayout } from "@/components/layout/main-layout";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Slider } from "@/components/ui/slider";
import { Checkbox } from "@/components/ui/checkbox";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import {
  Sheet,
  SheetClose,
  SheetContent,
  SheetFooter,
  SheetHeader,
  SheetTitle,
  SheetTrigger,
} from "@/components/ui/sheet";
import { useServices } from "@/lib/services-context";
import { Service } from "@/types";
import { Search, SlidersHorizontal } from "lucide-react";

export default function ServicesPage() {
  const location = useLocation();
  const { services, categories, getMentorById, isLoading, error, refresh } = useServices();

  // Extract query params
  const queryParams = new URLSearchParams(location.search);
  const initialQuery = queryParams.get('q') || "";
  const initialCategorySlug = queryParams.get('category') || "";

  // Filter states
  const [searchQuery, setSearchQuery] = useState(initialQuery);
  const [filteredServices, setFilteredServices] = useState<Service[]>(services);
  const [selectedCategories, setSelectedCategories] = useState<string[]>([]);
  const [priceRange, setPriceRange] = useState<[number, number]>([0, 300]);
  const [sortBy, setSortBy] = useState<string>("recommended");

  // Resolve a category slug from the URL to its id once categories load.
  useEffect(() => {
    if (!initialCategorySlug || categories.length === 0) return;
    const match = categories.find((category) => category.slug === initialCategorySlug);
    if (match) setSelectedCategories([String(match.id)]);
  }, [initialCategorySlug, categories]);

  // Apply filters
  useEffect(() => {
    let results = services;
    
    // Search query filter
    if (searchQuery) {
      const lowercaseQuery = searchQuery.toLowerCase();
      results = results.filter(
        service =>
          service.title.toLowerCase().includes(lowercaseQuery) ||
          service.description.toLowerCase().includes(lowercaseQuery) ||
          service.tags.some(tag => tag.toLowerCase().includes(lowercaseQuery))
      );
    }
    
    // Category filter
    if (selectedCategories.length > 0) {
      results = results.filter(service => 
        selectedCategories.includes(String(service.categoryId))
      );
    }
    
    // Price range filter
    results = results.filter(
      service => service.price >= priceRange[0] && service.price <= priceRange[1]
    );
    
    // Apply sorting
    switch (sortBy) {
      case "price-low":
        results = [...results].sort((a, b) => a.price - b.price);
        break;
      case "price-high":
        results = [...results].sort((a, b) => b.price - a.price);
        break;
      case "rating":
        results = [...results].sort((a, b) => (b.rating || 0) - (a.rating || 0));
        break;
      case "newest":
        results = [...results].sort(
          (a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime()
        );
        break;
      // Default is recommended (no specific sort)
      default:
        break;
    }
    
    setFilteredServices(results);
  }, [searchQuery, selectedCategories, priceRange, sortBy, services]);

  const handleSearch = (e: React.FormEvent) => {
    e.preventDefault();
    // Already handled by the effect
  };

  const toggleCategory = (categoryId: string) => {
    setSelectedCategories(prev =>
      prev.includes(categoryId)
        ? prev.filter(id => id !== categoryId)
        : [...prev, categoryId]
    );
  };

  const clearFilters = () => {
    setSelectedCategories([]);
    setPriceRange([0, 300]);
    setSortBy("recommended");
  };

  return (
    <MainLayout>
      {/* Hero Section */}
      <section className="bg-muted py-12">
        <div className="container">
          <div className="max-w-3xl mx-auto text-center space-y-6">
            <h1 className="text-3xl md:text-4xl font-bold">Find Your Perfect Mentor</h1>
            <p className="text-lg text-muted-foreground">
              Browse through our curated list of expert mentors ready to help you achieve your goals.
            </p>
            <form onSubmit={handleSearch} className="relative max-w-xl mx-auto">
              <Input
                type="search"
                placeholder="Search by skill, topic, or keyword"
                className="pr-12"
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
              />
              <Button 
                type="submit" 
                size="icon"
                className="absolute right-1 top-1 h-8 w-8"
              >
                <Search className="h-4 w-4" />
              </Button>
            </form>
          </div>
        </div>
      </section>

      {/* Services Grid */}
      <section className="py-8 md:py-12">
        <div className="container">
          <div className="flex flex-col lg:flex-row gap-8">
            {/* Filters - Desktop */}
            <div className="w-full lg:w-64 hidden lg:block">
              <div className="space-y-6">
                <div>
                  <h3 className="font-medium mb-3">Categories</h3>
                  <div className="space-y-2">
                    {categories.map(category => (
                      <div key={category.id} className="flex items-center space-x-2">
                        <Checkbox 
                          id={`category-${category.id}`}
                          checked={selectedCategories.includes(category.id)}
                          onCheckedChange={() => toggleCategory(category.id)}
                        />
                        <label 
                          htmlFor={`category-${category.id}`}
                          className="text-sm font-medium leading-none peer-disabled:cursor-not-allowed peer-disabled:opacity-70"
                        >
                          {category.name}
                        </label>
                      </div>
                    ))}
                  </div>
                </div>
                
                <div>
                  <h3 className="font-medium mb-3">Price Range</h3>
                  <div className="px-2">
                    <Slider
                      defaultValue={priceRange}
                      min={0}
                      max={300}
                      step={10}
                      value={priceRange}
                      onValueChange={(value) => setPriceRange(value as [number, number])}
                    />
                    <div className="flex items-center justify-between mt-2 text-sm">
                      <span>${priceRange[0]}</span>
                      <span>${priceRange[1]}</span>
                    </div>
                  </div>
                </div>
                
                <Button variant="outline" onClick={clearFilters} className="w-full">
                  Clear Filters
                </Button>
              </div>
            </div>
            
            {/* Filters - Mobile */}
            <Sheet>
              <div className="lg:hidden flex justify-between items-center mb-4">
                <SheetTrigger asChild>
                  <Button variant="outline" size="sm">
                    <SlidersHorizontal className="h-4 w-4 mr-2" />
                    Filters
                  </Button>
                </SheetTrigger>
                <Select value={sortBy} onValueChange={setSortBy}>
                  <SelectTrigger className="w-[180px]">
                    <SelectValue placeholder="Sort by" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="recommended">Recommended</SelectItem>
                    <SelectItem value="price-low">Price: Low to High</SelectItem>
                    <SelectItem value="price-high">Price: High to Low</SelectItem>
                    <SelectItem value="rating">Highest Rated</SelectItem>
                    <SelectItem value="newest">Newest</SelectItem>
                  </SelectContent>
                </Select>
              </div>
              <SheetContent side="left">
                <SheetHeader>
                  <SheetTitle>Filters</SheetTitle>
                </SheetHeader>
                <div className="space-y-6 py-4">
                  <div>
                    <h3 className="font-medium mb-3">Categories</h3>
                    <div className="space-y-2">
                      {categories.map(category => (
                        <div key={category.id} className="flex items-center space-x-2">
                          <Checkbox 
                            id={`mobile-category-${category.id}`}
                            checked={selectedCategories.includes(category.id)}
                            onCheckedChange={() => toggleCategory(category.id)}
                          />
                          <label 
                            htmlFor={`mobile-category-${category.id}`}
                            className="text-sm font-medium leading-none peer-disabled:cursor-not-allowed peer-disabled:opacity-70"
                          >
                            {category.name}
                          </label>
                        </div>
                      ))}
                    </div>
                  </div>
                  
                  <div>
                    <h3 className="font-medium mb-3">Price Range</h3>
                    <div className="px-2">
                      <Slider
                        defaultValue={priceRange}
                        min={0}
                        max={300}
                        step={10}
                        value={priceRange}
                        onValueChange={(value) => setPriceRange(value as [number, number])}
                      />
                      <div className="flex items-center justify-between mt-2 text-sm">
                        <span>${priceRange[0]}</span>
                        <span>${priceRange[1]}</span>
                      </div>
                    </div>
                  </div>
                </div>
                <SheetFooter>
                  <SheetClose asChild>
                    <Button variant="outline" onClick={clearFilters}>
                      Clear Filters
                    </Button>
                  </SheetClose>
                  <SheetClose asChild>
                    <Button>Apply Filters</Button>
                  </SheetClose>
                </SheetFooter>
              </SheetContent>
            </Sheet>
            
            {/* Main Content */}
            <div className="flex-1">
              {/* Sort - Desktop */}
              <div className="hidden lg:flex justify-end mb-6">
                <Select value={sortBy} onValueChange={setSortBy}>
                  <SelectTrigger className="w-[220px]">
                    <SelectValue placeholder="Sort by" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="recommended">Recommended</SelectItem>
                    <SelectItem value="price-low">Price: Low to High</SelectItem>
                    <SelectItem value="price-high">Price: High to Low</SelectItem>
                    <SelectItem value="rating">Highest Rated</SelectItem>
                    <SelectItem value="newest">Newest</SelectItem>
                  </SelectContent>
                </Select>
              </div>
              
              {/* Results count */}
              <p className="text-muted-foreground mb-6">
                {isLoading && !services.length ? 'Finding mentors…' : `${filteredServices.length} services found`}
                {searchQuery && ` for "${searchQuery}"`}
              </p>
              
              {/* Results Grid */}
              {isLoading && !services.length ? <MentorCardSkeletonGrid/> : error && !services.length ? <div role="alert" className="rounded-xl border border-violet-200 p-6"><p>Mentors could not be loaded.</p><button className="mt-3 font-bold text-violet-700 underline" onClick={() => refresh()}>Try Again</button></div> : filteredServices.length > 0 ? (
                <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-6">
                  {filteredServices.map(service => {
                    const mentor = service.mentor || getMentorById(String(service.mentorId));
                    const category = categories.find(cat => cat.id === service.categoryId);
                    
                    return (
                      <Card key={service.id} className="overflow-hidden">
                        <div className="aspect-[3/2] bg-gradient-to-br from-blue-100 to-blue-50 relative">
                          {category && (
                            <span className="absolute top-2 left-2 bg-white/80 backdrop-blur-sm text-xs font-medium py-1 px-2 rounded">
                              {category.name}
                            </span>
                          )}
                          {service.rating && (
                            <div className="absolute top-2 right-2 bg-white/80 backdrop-blur-sm rounded-full py-1 px-2 flex items-center">
                              <svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" viewBox="0 0 24 24" fill="currentColor" className="text-yellow-400 mr-1">
                                <polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2" />
                              </svg>
                              <span className="text-xs font-medium">{service.rating.toFixed(1)}</span>
                            </div>
                          )}
                        </div>
                        <CardContent className="p-5">
                          <div className="flex items-center gap-3 mb-3">
                            <img 
                              src={mentor?.avatar} 
                              alt={mentor?.name} 
                              className="w-8 h-8 rounded-full object-cover"
                            />
                            <div>
                              <div className="text-sm font-medium">{mentor?.name}</div>
                              <div className="text-xs text-muted-foreground">{mentor?.location}</div>
                            </div>
                          </div>
                          <Link to={`/services/${service.id}`}>
                            <h3 className="font-semibold text-base mb-2 hover:text-primary transition-colors">
                              {service.title}
                            </h3>
                          </Link>
                          <p className="text-sm text-muted-foreground line-clamp-2 mb-3">
                            {service.description}
                          </p>
                          <div className="flex flex-wrap gap-1 mb-3">
                            {service.tags.slice(0, 3).map(tag => (
                              <span key={tag} className="px-2 py-1 bg-muted text-xs rounded-full">
                                {tag}
                              </span>
                            ))}
                            {service.tags.length > 3 && (
                              <span className="px-2 py-1 bg-muted text-xs rounded-full">
                                +{service.tags.length - 3}
                              </span>
                            )}
                          </div>
                          <div className="flex justify-between items-center pt-2 border-t">
                            <div>
                              <span className="text-lg font-bold">${service.price}</span>
                              <span className="text-muted-foreground text-sm">/{service.duration} min</span>
                            </div>
                            <Button asChild variant="secondary" size="sm">
                              <Link to={`/services/${service.id}`}>View Details</Link>
                            </Button>
                          </div>
                        </CardContent>
                      </Card>
                    );
                  })}
                </div>
              ) : (
                <div className="text-center py-12 bg-muted rounded-lg">
                  <div className="mb-4 text-muted-foreground">
                    <svg xmlns="http://www.w3.org/2000/svg" width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" className="mx-auto">
                      <circle cx="11" cy="11" r="8"></circle>
                      <line x1="21" y1="21" x2="16.65" y2="16.65"></line>
                    </svg>
                  </div>
                  <h3 className="text-lg font-medium mb-2">No services found</h3>
                  <p className="text-muted-foreground mb-4">
                    Try adjusting your search or filters to find what you're looking for.
                  </p>
                  <Button onClick={clearFilters}>Clear All Filters</Button>
                </div>
              )}
            </div>
          </div>
        </div>
      </section>
    </MainLayout>
  );
}