import { useState } from "react";
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
} from "@/components/ui/form";
import { Input } from "@/components/ui/input";
import { MainLayout } from "@/components/layout/main-layout";
import api from "@/lib/axios";
import { useAuth } from "@/lib/auth-context";
import { toast } from "@/components/ui/use-toast";

import { safeAuthReturn } from "@/lib/auth-return";

const formSchema = z.object({
  email: z.string().email({ message: "Please enter a valid email address" }),
  password: z.string().min(5, { message: "Password must be at least 5 characters long" }),
});

export default function Login() {
  const { login, authError } = useAuth();
  const navigate = useNavigate();
  const [params] = useSearchParams();
  const returnTo = safeAuthReturn(params.get("return_to"));
  const [isLoading, setIsLoading] = useState(false);

  const form = useForm<z.infer<typeof formSchema>>({
    resolver: zodResolver(formSchema),
    defaultValues: {
      email: "",
      password: "",
    },
  });

  async function onSubmit(values: z.infer<typeof formSchema>) {
    setIsLoading(true);

    try {
      const success = await login(values.email, values.password);

      if (success) {
        toast({
          title: "Welcome back!",
          description: "You’ve successfully signed in.",
        });
        navigate(returnTo || "/");
      } else {
        toast({
          title: "Sign-in unavailable",
          description: "Check the account notice on this page.",
          variant: "destructive",
        });
      }
    } catch (err) {
      console.error(err);
      toast({
        title: "Login failed",
        description: "Something went wrong. Please try again later.",
        variant: "destructive",
      });
    } finally {
      setIsLoading(false);
    }
  }

  return (
    <MainLayout>
      <div className="container max-w-md py-12 md:py-16">
        <div className="space-y-6">
          <div className="space-y-2 text-center">
            <h1 className="text-3xl font-bold">Welcome Back</h1>
            <p className="text-muted-foreground">
              Sign in to your nishioHub account
            </p>
          </div>

          {authError && <div className="mb-5 rounded-lg bg-red-50 p-4 text-sm text-red-800" role="alert"><p>{authError}</p>{/verify/i.test(authError) && <Button type="button" variant="outline" className="mt-3" onClick={async () => { try { const result = await api.post('/auth/resend-verification', { email: form.getValues('email'), password: form.getValues('password') }); toast({ title: result.data.detail }); } catch { toast({ title: 'Could not send verification email. Check your credentials and try again.', variant: 'destructive' }); } }}>Resend Verification Email</Button>}</div>}
          <Form {...form}>
            <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-6">
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
              <Button type="submit" className="w-full" disabled={isLoading}>
                {isLoading ? "Signing in..." : "Sign In"}
              </Button>
            </form>
          </Form>

          <div className="text-center text-sm">
            <p className="text-muted-foreground">
              Don&apos;t have an account?{" "}
              <Link to={returnTo ? `/register?role=${["/mentor/application", "/host-an-event"].includes(returnTo) ? "mentor" : "mentee"}&return_to=${encodeURIComponent(returnTo)}` : "/register"} className="text-primary hover:underline">
                Create an account
              </Link>
            </p>
            <p className="mt-4 text-muted-foreground">
              Forgot your password?{" "}
              <Link to="/forgot-password" className="text-primary hover:underline">
                Reset it here
              </Link>
            </p>
          </div>
        </div>
      </div>
    </MainLayout>
  );
}
