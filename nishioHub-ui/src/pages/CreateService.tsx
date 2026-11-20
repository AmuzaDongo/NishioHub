import { useState } from "react";
import { useNavigate, Navigate } from "react-router-dom";
import { z } from "zod";
import { zodResolver } from "@hookform/resolvers/zod";
import { useForm } from "react-hook-form";
import { Button } from "@/components/ui/button";
import {
  Form,
  FormControl,
  FormDescription,
  FormField,
  FormItem,
  FormLabel,
  FormMessage,
} from "@/components/ui/form";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { MainLayout } from "@/components/layout/main-layout";
import { hasRole, roleName } from "@/lib/utils";
import { useAuth } from "@/lib/auth-context";
import { useServices } from "@/lib/services-context";
import { Service } from "@/types";
import { CheckCircle } from "lucide-react";

const serviceFormSchema = z.object({
  title: z.string().min(5, {
    message: "Title must be at least 5 characters.",
  }).max(100, {
    message: "Title cannot exceed 100 characters.",
  }),
  description: z.string().min(20, {
    message: "Description must be at least 20 characters.",
  }).max(2000, {
    message: "Description cannot exceed 2000 characters.",
  }),
  categoryId: z.string({
    required_error: "Please select a category.",
  }),
  price: z.coerce.number().min(5, {
    message: "Price must be at least $5.",
  }).max(1000, {
    message: "Price cannot exceed $1000.",
  }),
  duration: z.coerce.number().min(15, {
    message: "Duration must be at least 15 minutes.",
  }).max(240, {
    message: "Duration cannot exceed 240 minutes (4 hours).",
  }),
  tags: z.string().optional(),
});

export default function CreateServicePage() {
  const { user } = useAuth();
  const { categories, createService } = useServices();
  const navigate = useNavigate();
  const [success, setSuccess] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  
  const form = useForm<z.infer<typeof serviceFormSchema>>({
    resolver: zodResolver(serviceFormSchema),
    defaultValues: {
      title: "",
      description: "",
      categoryId: "",
      price: 50,
      duration: 60,
      tags: "",
    },
  });
  
  // If not logged in or not a mentor, redirect
  if (!user) {
    return <Navigate to="/login" />;
  } else if (!hasRole(user, "mentor")) {
    return <Navigate to="/" />;
  }
  
  const onSubmit = async (values: z.infer<typeof serviceFormSchema>) => {
    setSuccess(false);
    setError(null);
    setIsLoading(true);
    
    try {
      // Convert comma-separated tags to array
      const tags = values.tags 
        ? values.tags.split(",").map(tag => tag.trim()).filter(Boolean)
        : [];
      
      // Create the service
      const serviceId = await createService({
        ...values,
        tags,
        mentorId: user.id,
      } as Omit<Service, "id" | "createdAt" | "updatedAt" | "rating" | "reviewCount">);
      
      setSuccess(true);
      
      // Clear success message and navigate after delay
      setTimeout(() => {
        navigate(`/services/${serviceId}`);
      }, 1500);
    } catch (error) {
      setError("Failed to create service. Please try again.");
      console.error(error);
    } finally {
      setIsLoading(false);
    }
  };
  
  return (
    <MainLayout>
      <div className="container py-8 max-w-3xl">
        <div className="mb-6">
          <h1 className="text-2xl font-bold mb-1">Create a New Service</h1>
          <p className="text-muted-foreground">
            Share your expertise with mentees by creating a mentorship service.
          </p>
        </div>
        
        {success && (
          <Alert className="mb-6 bg-green-50 text-green-700 border-green-200">
            <CheckCircle className="h-4 w-4" />
            <AlertTitle>Success!</AlertTitle>
            <AlertDescription>Your service has been created successfully. Redirecting...</AlertDescription>
          </Alert>
        )}
        
        {error && (
          <Alert variant="destructive" className="mb-6">
            <AlertTitle>Error</AlertTitle>
            <AlertDescription>{error}</AlertDescription>
          </Alert>
        )}
        
        <Form {...form}>
          <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-6">
            <FormField
              control={form.control}
              name="title"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Service Title</FormLabel>
                  <FormControl>
                    <Input
                      placeholder="e.g. Career Coaching for Tech Professionals"
                      {...field}
                    />
                  </FormControl>
                  <FormDescription>
                    Create a compelling title that clearly describes what you offer.
                  </FormDescription>
                  <FormMessage />
                </FormItem>
              )}
            />
            
            <FormField
              control={form.control}
              name="description"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Service Description</FormLabel>
                  <FormControl>
                    <Textarea
                      placeholder="Describe what mentees will get from your service, your experience, and how you can help them achieve their goals."
                      className="min-h-[200px]"
                      {...field}
                    />
                  </FormControl>
                  <FormDescription>
                    Be detailed about what you offer, your qualifications, and expected outcomes.
                  </FormDescription>
                  <FormMessage />
                </FormItem>
              )}
            />
            
            <FormField
              control={form.control}
              name="categoryId"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Category</FormLabel>
                  <Select 
                    onValueChange={field.onChange} 
                    defaultValue={field.value}
                  >
                    <FormControl>
                      <SelectTrigger>
                        <SelectValue placeholder="Select a category" />
                      </SelectTrigger>
                    </FormControl>
                    <SelectContent>
                      {categories.map(category => (
                        <SelectItem key={category.id} value={String(category.id)}>
                          {category.name}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                  <FormDescription>
                    Choose the category that best represents your service.
                  </FormDescription>
                  <FormMessage />
                </FormItem>
              )}
            />
            
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-6">
              <FormField
                control={form.control}
                name="price"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Price (USD)</FormLabel>
                    <FormControl>
                      <div className="relative">
                        <span className="absolute left-3 top-2.5 text-muted-foreground">$</span>
                        <Input
                          type="number"
                          min={5}
                          max={1000}
                          className="pl-7"
                          {...field}
                        />
                      </div>
                    </FormControl>
                    <FormDescription>
                      Price per session (between $5 and $1000).
                    </FormDescription>
                    <FormMessage />
                  </FormItem>
                )}
              />
              
              <FormField
                control={form.control}
                name="duration"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Duration (minutes)</FormLabel>
                    <FormControl>
                      <Input
                        type="number"
                        min={15}
                        max={240}
                        step={15}
                        {...field}
                      />
                    </FormControl>
                    <FormDescription>
                      Session length in minutes (between 15 and 240).
                    </FormDescription>
                    <FormMessage />
                  </FormItem>
                )}
              />
            </div>
            
            <FormField
              control={form.control}
              name="tags"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Tags</FormLabel>
                  <FormControl>
                    <Input
                      placeholder="e.g. Career Advice, Resume Review, Interview Preparation"
                      {...field}
                    />
                  </FormControl>
                  <FormDescription>
                    Add comma-separated tags to help mentees find your service.
                  </FormDescription>
                  <FormMessage />
                </FormItem>
              )}
            />
            
            <div className="flex gap-4 pt-2">
              <Button type="submit" disabled={isLoading}>
                {isLoading ? "Creating..." : "Create Service"}
              </Button>
              <Button 
                type="button" 
                variant="outline" 
                onClick={() => navigate("/dashboard")}
              >
                Cancel
              </Button>
            </div>
          </form>
        </Form>
      </div>
    </MainLayout>
  );
}