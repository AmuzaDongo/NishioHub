import { safeAuthReturn } from "@/lib/auth-return";
import { useEffect, useState } from "react";
import { Link, useNavigate, useSearchParams } from "react-router-dom";
import { z } from "zod";
import { zodResolver } from "@hookform/resolvers/zod";
import { useForm } from "react-hook-form";
import { Button } from "@/components/ui/button";
import {
  Form,
  FormControl,
  FormField,
  FormItem,
  FormLabel,
  FormMessage,
  FormDescription,
} from "@/components/ui/form";
import { Input } from "@/components/ui/input";
import { Alert, AlertDescription } from "@/components/ui/alert";
import { RadioGroup, RadioGroupItem } from "@/components/ui/radio-group";
import { MainLayout } from "@/components/layout/main-layout";
import { usePlatform } from "@/lib/platform-context";
import { useAuth } from "@/lib/auth-context";
import { toast } from "@/components/ui/use-toast";
import { useRoles } from "@/lib/role-context";

const formSchema = z.object({
  full_name: z.string().min(2, { message: "Full name must be at least 2 characters long" }),
  email: z.string().email({ message: "Please enter a valid email address" }),
  phone_number: z.string().min(10, { message: "Phone number must be at least 10 digits long" }),
  password: z.string().min(6, { message: "Password must be at least 6 characters long" }),
  confirmPassword: z.string().min(6, { message: "Password must be at least 6 characters long" }),
  role_id: z.number({
    required_error: "Please select a role",
  }),
}).refine((data) => data.password === data.confirmPassword, {
  message: "Passwords do not match",
  path: ["confirmPassword"],
});

export default function Register() {
  const { register, authError } = useAuth();
  const platform = usePlatform();
  const navigate = useNavigate();
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const roles = useRoles();

  const [registrationParams] = useSearchParams();
  const requestedRole = registrationParams.get('role');
  const returnTo = safeAuthReturn(registrationParams.get('return_to'));
  const loginPath = returnTo ? `/login?return_to=${encodeURIComponent(returnTo)}` : '/login';
  const chosenRole = requestedRole === 'mentor' || requestedRole === 'mentee' ? requestedRole : platform.default_registration_role;
  const defaultRoleId = roles.find(role => role.name.toLowerCase().replace(/[ _-]/g, '') === chosenRole)?.id ?? roles[0]?.id ?? 0;

  const form = useForm<z.infer<typeof formSchema>>({
    resolver: zodResolver(formSchema.superRefine((values, context) => {
      if (values.password.length < platform.password_min_length) context.addIssue({ code: z.ZodIssueCode.custom, path: ['password'], message: `Use at least ${platform.password_min_length} characters.` });
    })),
    defaultValues: {
      full_name: "",
      email: "",
      phone_number: "",
      password: "",
      confirmPassword: "",
      role_id: defaultRoleId,
    },
  });

  useEffect(() => {
    if (roles.length > 0 && !form.getFieldState("role_id").isDirty) {
      form.setValue("role_id", defaultRoleId);
    }
  }, [roles, form, defaultRoleId]);

  async function onSubmit(values: z.infer<typeof formSchema>) {
    setError(null);
    setIsLoading(true);

    try {
      const success = await register(
        values.full_name,
        values.email,
        values.phone_number,
        values.password,
        values.role_id
      );

      if (success) {
        toast({
          title: "Success",
          description: platform.require_email_verification ? "Check your inbox to verify your email before signing in." : "Registration successful. Please sign in to continue.",
        });
        navigate(loginPath);
      } else {
        setError("Could not create your account. Please review the details and try again.");
      }
    } catch (err) {
      toast({
        title: "Error",
        description: "An unexpected error occurred. Please try again later.",
      });
      setError("An unexpected error occurred. Please try again later.");
      console.error(err);
    } finally {
      setIsLoading(false);
    }
  }

  if (!platform.registration_enabled) return <MainLayout><div className="container py-24 text-center"><h1 className="text-3xl font-bold">Registration is currently closed</h1><p className="mt-4">Existing members can still sign in.</p><Link to={loginPath} className="inline-block mt-6 text-violet-700 underline">Sign In</Link></div></MainLayout>;
  return (
    <MainLayout>
      <div className="container max-w-md py-12">
        <div className="space-y-6">
          <div className="space-y-2 text-center">
            <h1 className="text-3xl font-bold">Create an Account</h1>
            <p className="text-muted-foreground">Join nishioHub today</p>
          </div>

          {error && (
            <Alert variant="destructive">
              <AlertDescription>{authError || error}</AlertDescription>
            </Alert>
          )}

          <Form {...form}>
            <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-6">
              <FormField
                control={form.control}
                name="full_name"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Full Name</FormLabel>
                    <FormControl>
                      <Input placeholder="John Doe" {...field} />
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
                      <Input placeholder="your@email.com" {...field} />
                    </FormControl>
                    <FormMessage />
                  </FormItem>
                )}
              />
              <FormField
                control={form.control}
                name="phone_number"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Phone Number</FormLabel>
                    <FormControl>
                      <Input placeholder="your phone number" {...field} />
                    </FormControl>
                    <FormMessage />
                  </FormItem>
                )}
              />
              <FormField
                control={form.control}
                name="password"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Password</FormLabel>
                    <FormControl>
                      <Input type="password" placeholder="••••••" {...field} />
                    </FormControl>
                    <FormMessage />
                  </FormItem>
                )}
              />
              <FormField
                control={form.control}
                name="confirmPassword"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Confirm Password</FormLabel>
                    <FormControl>
                      <Input type="password" placeholder="••••••" {...field} />
                    </FormControl>
                    <FormMessage />
                  </FormItem>
                )}
              />

              <FormField
                control={form.control}
                name="role_id"
                render={({ field }) => (
                  <FormItem className="space-y-3">
                    <FormLabel>I want to</FormLabel>
                    <FormControl>
                      <RadioGroup
                        onValueChange={(val) => field.onChange(Number(val))}
                        value={String(field.value)}
                        className="flex flex-col space-y-1"
                      >
                        {roles.map((role) => (
                          <FormItem
                            key={role.id}
                            className="flex items-center space-x-3 space-y-0"
                          >
                            <FormControl>
                              <RadioGroupItem value={String(role.id)} />
                            </FormControl>
                            <FormLabel className="font-normal capitalize">
                              {role.name === "mentor"
                                ? "Become a Mentor"
                                : role.name === "founder"
                                ? "Founder"
                                : role.name === "organization"
                                ? "Organization Representative"
                                : "Find a Mentor (I'm a Mentee)"
                              }
                            </FormLabel>
                          </FormItem>
                        ))}
                      </RadioGroup>
                    </FormControl>
                    <FormMessage />
                    <FormDescription>
                      You can always change your role later.
                    </FormDescription>
                  </FormItem>
                )}
              />

              <Button type="submit" className="w-full" disabled={isLoading}>
                {isLoading ? "Creating account..." : "Sign Up"}
              </Button>
            </form>
          </Form>

          <div className="text-center text-sm">
            <p className="text-muted-foreground">
              Already have an account?{" "}
              <Link to={loginPath} className="text-primary hover:underline">
                Sign in
              </Link>
            </p>
          </div>

          <div className="text-center text-xs text-muted-foreground">
            <p>
              By signing up, you agree to our{" "}
              <Link to="/terms-of-service" className="underline">
                Terms of Service
              </Link>{" "}
              and{" "}
              <Link to="/privacy-policy" className="underline">
                Privacy Policy
              </Link>
            </p>
          </div>
        </div>
      </div>
    </MainLayout>
  );
}
