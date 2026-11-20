import { useState } from "react";
import { Link } from "react-router-dom";
import { MainLayout } from "@/components/layout/main-layout";
import { useServices } from "@/lib/services-context";
import { Search, Filter, ArrowUpDown } from "lucide-react";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from "@/components/ui/card";
import { Helmet } from "react-helmet-async";
import { Separator } from "@/components/ui/separator";
import { Badge } from "@/components/ui/badge";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";

export default function Categories() {
  const { categories } = useServices();
  const [searchQuery, setSearchQuery] = useState("");
  const [isFilterOpen, setIsFilterOpen] = useState(false);
  const [sortBy, setSortBy] = useState("popular");

  // Filter categories based on search query
  const filteredCategories = categories.filter(category =>
    category.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
    (category.description && category.description.toLowerCase().includes(searchQuery.toLowerCase()))
  );

  const sortedCategories = [...filteredCategories].sort((a, b) => {
    switch (sortBy) {
      case "newest":
        return new Date(b.created_at || 0).getTime() - new Date(a.created_at || 0).getTime();
      case "alphabetical":
        return a.name.localeCompare(b.name);
      case "reverse-alpha":
        return b.name.localeCompare(a.name);
      default:
        return (a.position ?? 0) - (b.position ?? 0);
    }
  });

  return (
    <MainLayout>
      <Helmet>
        <title>Categories | nishioHub</title>
        <meta name="description" content="Browse mentoring categories on nishioHub" />
      </Helmet>
      
      <div className="container py-8">
        {/* Hero Section */}
        <div className="mb-8 text-center">
          <h1 className="text-3xl md:text-4xl font-bold mb-4">Browse Categories</h1>
          <p className="text-muted-foreground max-w-2xl mx-auto">
            Explore our wide range of mentoring categories and find the perfect mentor to help you achieve your goals.
          </p>
        </div>

        {/* Search & Filter */}
        <div className="mb-8 flex flex-col md:flex-row gap-4">
          <div className="relative flex-1">
            <Search className="absolute left-3 top-3 h-4 w-4 text-muted-foreground" />
            <Input
              placeholder="Search categories..."
              className="pl-10"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
            />
          </div>
          <Dialog open={isFilterOpen} onOpenChange={setIsFilterOpen}>
            <DialogTrigger asChild>
              <Button variant="outline" className="gap-2">
                <Filter className="h-4 w-4" />
                Filter Options
              </Button>
            </DialogTrigger>
            <DialogContent className="sm:max-w-md">
              <DialogHeader>
                <DialogTitle>Filter Categories</DialogTitle>
                <DialogDescription>
                  Customize your category browsing experience
                </DialogDescription>
              </DialogHeader>
              <div className="grid gap-4 py-4">
                <div className="grid grid-cols-4 items-center gap-4">
                  <span className="text-sm font-medium col-span-1">Sort By</span>
                  <Select value={sortBy} onValueChange={setSortBy}>
                    <SelectTrigger className="col-span-3">
                      <SelectValue placeholder="Select" />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="popular">Most Popular</SelectItem>
                      <SelectItem value="newest">Newest First</SelectItem>
                      <SelectItem value="alphabetical">Alphabetical (A-Z)</SelectItem>
                      <SelectItem value="reverse-alpha">Alphabetical (Z-A)</SelectItem>
                    </SelectContent>
                  </Select>
                </div>
              </div>
              <div className="flex justify-between">
                <Button variant="outline" onClick={() => setIsFilterOpen(false)}>Cancel</Button>
                <Button onClick={() => setIsFilterOpen(false)}>Apply Filters</Button>
              </div>
            </DialogContent>
          </Dialog>
          <Select value={sortBy} onValueChange={setSortBy}>
            <SelectTrigger className="w-[180px]">
              <SelectValue placeholder="Sort by" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="popular">Most Popular</SelectItem>
              <SelectItem value="newest">Newest First</SelectItem>
              <SelectItem value="alphabetical">A-Z</SelectItem>
              <SelectItem value="reverse-alpha">Z-A</SelectItem>
            </SelectContent>
          </Select>
        </div>

        {/* View Toggle */}
        <Tabs defaultValue="grid" className="mb-6">
          <div className="flex items-center justify-between">
            <h2 className="text-xl font-semibold">All Categories</h2>
            <TabsList>
              <TabsTrigger value="grid">Grid</TabsTrigger>
              <TabsTrigger value="list">List</TabsTrigger>
            </TabsList>
          </div>
          
          {/* Grid View */}
          <TabsContent value="grid">
            {sortedCategories.length > 0 ? (
              <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-6 mt-6">
                {sortedCategories.map((category) => (
                  <Link to={`/categories/${category.slug}`} key={category.id} className="group">
                    <Card className="overflow-hidden transition-all hover:shadow-lg h-full">
                      {(category.image_url || category.iconPath) ? (
                        <div className="aspect-[4/3] w-full overflow-hidden">
                          <img
                            src={category.image_url || category.iconPath || undefined}
                            alt={category.name}
                            className="w-full h-full object-cover transition-transform duration-300 group-hover:scale-105"
                          />
                        </div>
                      ) : (
                        <div className="aspect-[4/3] w-full bg-muted flex items-center justify-center">
                          <span className="text-4xl font-bold text-muted-foreground">
                            {category.name.charAt(0)}
                          </span>
                        </div>
                      )}
                      <CardHeader>
                        <CardTitle>{category.name}</CardTitle>
                        {category.description && (
                          <CardDescription className="line-clamp-2">{category.description}</CardDescription>
                        )}
                      </CardHeader>
                      <CardFooter className="pt-0">
                        <Button variant="ghost" className="w-full justify-start pl-2 group-hover:text-primary">
                          Browse Category
                          <ArrowUpDown className="ml-2 h-4 w-4" />
                        </Button>
                      </CardFooter>
                    </Card>
                  </Link>
                ))}
              </div>
            ) : (
              <div className="text-center py-10">
                <h3 className="text-lg font-semibold">No categories found</h3>
                <p className="text-muted-foreground mt-1">Try adjusting your search criteria</p>
              </div>
            )}
          </TabsContent>
          
          {/* List View */}
          <TabsContent value="list">
            {sortedCategories.length > 0 ? (
              <div className="space-y-4 mt-6">
                {sortedCategories.map((category) => (
                  <Link to={`/categories/${category.slug}`} key={category.id} className="group">
                    <Card className="overflow-hidden transition-all hover:shadow-md">
                      <div className="flex flex-col md:flex-row items-center gap-4 p-4">
                        {(category.image_url || category.iconPath) ? (
                          <div className="w-20 h-20 overflow-hidden rounded-md shrink-0">
                            <img
                              src={category.image_url || category.iconPath || undefined}
                              alt={category.name}
                              className="w-full h-full object-cover"
                            />
                          </div>
                        ) : (
                          <div className="w-20 h-20 rounded-md bg-muted flex items-center justify-center shrink-0">
                            <span className="text-2xl font-bold text-muted-foreground">
                              {category.name.charAt(0)}
                            </span>
                          </div>
                        )}
                        <div className="flex-1">
                          <h3 className="text-xl font-semibold">{category.name}</h3>
                          {category.description && (
                            <p className="text-muted-foreground mt-1">{category.description}</p>
                          )}
                        </div>
                        <Button variant="outline" className="shrink-0 group-hover:bg-primary group-hover:text-primary-foreground">
                          Browse Category
                        </Button>
                      </div>
                    </Card>
                  </Link>
                ))}
              </div>
            ) : (
              <div className="text-center py-10">
                <h3 className="text-lg font-semibold">No categories found</h3>
                <p className="text-muted-foreground mt-1">Try adjusting your search criteria</p>
              </div>
            )}
          </TabsContent>
        </Tabs>

        {/* Featured Sections */}
        <div className="mt-12">
          <h2 className="text-2xl font-bold mb-6">Popular Categories</h2>
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
            <div className="bg-muted/50 rounded-lg p-6">
              <h3 className="font-semibold text-lg mb-2">Software Development</h3>
              <p className="text-muted-foreground mb-4">Learn programming, web development, mobile apps and more</p>
              <div className="flex flex-wrap gap-2 mb-4">
                <Badge variant="secondary">React</Badge>
                <Badge variant="secondary">JavaScript</Badge>
                <Badge variant="secondary">Python</Badge>
                <Badge variant="secondary">Node.js</Badge>
              </div>
              <Button asChild variant="outline">
                <Link to="/categories/software-development">Explore</Link>
              </Button>
            </div>
            
            <div className="bg-muted/50 rounded-lg p-6">
              <h3 className="font-semibold text-lg mb-2">Product Management</h3>
              <p className="text-muted-foreground mb-4">Master product development, strategy, and team leadership</p>
              <div className="flex flex-wrap gap-2 mb-4">
                <Badge variant="secondary">Agile</Badge>
                <Badge variant="secondary">Roadmap</Badge>
                <Badge variant="secondary">User Research</Badge>
                <Badge variant="secondary">Product Strategy</Badge>
              </div>
              <Button asChild variant="outline">
                <Link to="/categories/product-management">Explore</Link>
              </Button>
            </div>
            
            <div className="bg-muted/50 rounded-lg p-6">
              <h3 className="font-semibold text-lg mb-2">Data Science</h3>
              <p className="text-muted-foreground mb-4">Learn data analysis, machine learning and AI</p>
              <div className="flex flex-wrap gap-2 mb-4">
                <Badge variant="secondary">Machine Learning</Badge>
                <Badge variant="secondary">Python</Badge>
                <Badge variant="secondary">Data Visualization</Badge>
                <Badge variant="secondary">AI</Badge>
              </div>
              <Button asChild variant="outline">
                <Link to="/categories/data-science">Explore</Link>
              </Button>
            </div>
          </div>
        </div>

        {/* Banner */}
        <div className="mt-12 bg-gradient-to-r from-primary/20 to-primary/5 rounded-lg p-8 text-center">
          <h2 className="text-2xl font-bold mb-2">Can't find what you're looking for?</h2>
          <p className="text-muted-foreground mb-6 max-w-2xl mx-auto">
            Our platform is constantly growing with new mentors and categories. If you don't see what you need, let us know!
          </p>
          <Button asChild variant="default">
            <Link to="/contact">Contact Us</Link>
          </Button>
        </div>
      </div>
    </MainLayout>
  );
}