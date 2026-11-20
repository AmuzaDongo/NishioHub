import { PageLoader } from '@/components/loaders/PageLoader';
import { useEffect, useRef, useState } from "react";
import { Link, Navigate } from "react-router-dom";
import { z } from "zod";
import { zodResolver } from "@hookform/resolvers/zod";
import { useForm } from "react-hook-form";
import { MainLayout } from "@/components/layout/main-layout";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
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
import { Label } from "@/components/ui/label";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Switch } from "@/components/ui/switch";
import { Textarea } from "@/components/ui/textarea";
import { useAuth } from "@/lib/auth-context";
import {
  createMyAvailabilitySlot,
  deleteMentorAvatar,
  deleteMyAvailabilitySlot,
  getMyMentorProfile,
  updateMyMentorProfile,
  uploadMyMentorAvatar,
} from "@/lib/mentor-profile-api";
import { hasRole, roleName } from "@/lib/utils";
import { MentorProfile, MentorProfileUpdate } from "@/types";
import { Camera, Loader2, Pencil, Plus, Star, Trash2 } from "lucide-react";

const CURRENCIES = ["USD", "EUR", "GBP", "CAD", "AUD"] as const;
type Currency = (typeof CURRENCIES)[number];

const TIMEZONES = [
  "Africa/Kampala",
  "Africa/Nairobi",
  "Africa/Kigali",
  "UTC",
  "America/Los_Angeles",
  "America/Denver",
  "America/Chicago",
  "America/New_York",
  "America/Sao_Paulo",
  "Europe/London",
  "Europe/Berlin",
  "Europe/Paris",
  "Europe/Madrid",
  "Africa/Lagos",
  "Asia/Dubai",
  "Asia/Kolkata",
  "Asia/Singapore",
  "Asia/Tokyo",
  "Australia/Sydney",
];

const profileSchema = z.object({
  name: z.string().min(2, "Name must be at least 2 characters.").max(100),
  headline: z.string().min(2, "Headline must be at least 2 characters.").max(150),
  bio: z.string().max(2000, "Bio cannot exceed 2000 characters.").optional().or(z.literal("")),
  hourly_rate: z.coerce.number().min(0, "Rate must be 0 or more.").max(10000),
  currency: z.enum(CURRENCIES),
  languages: z.string().min(1, "Add at least one language."),
  years_of_experience: z.coerce.number().int().min(0).max(80),
  timezone: z.string().min(1, "Choose a timezone."),
  skills: z.string().min(1, "Add at least one skill."),
  accepting_bookings: z.boolean(),
});

type ProfileFormValues = z.infer<typeof profileSchema>;

function splitList(value: string): string[] {
  return value
    .split(",")
    .map((item) => item.trim())
    .filter(Boolean);
}

function errorMessage(error: unknown): string {
  const detail = (error as { response?: { data?: { detail?: unknown } } })?.response
    ?.data?.detail;
  if (Array.isArray(detail)) return detail.join(", ");
  if (typeof detail === "string") return detail;
  return "Something went wrong. Please try again.";
}

export default function MentorSelfProfilePage() {
  const { user, isLoading: authLoading, updateUser } = useAuth();
  const [profile, setProfile] = useState<MentorProfile | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [isEditing, setIsEditing] = useState(false);
  const [isSaving, setIsSaving] = useState(false);
  const [formError, setFormError] = useState<string | null>(null);
  const [avatarError, setAvatarError] = useState<string | null>(null);
  const [isAvatarBusy, setIsAvatarBusy] = useState(false);
  const [avatarFile, setAvatarFile] = useState<File | null>(null);
  const [avatarPreview, setAvatarPreview] = useState<string | null>(null);
  const [slotDate, setSlotDate] = useState("");
  const [slotError, setSlotError] = useState<string | null>(null);
  const [isSlotBusy, setIsSlotBusy] = useState(false);
  const fileInputRef = useRef<HTMLInputElement>(null);

  const form = useForm<ProfileFormValues>({
    resolver: zodResolver(profileSchema),
    defaultValues: {
      name: "",
      headline: "",
      bio: "",
      hourly_rate: 0,
      currency: "USD",
      languages: "",
      years_of_experience: 0,
      timezone: "UTC",
      skills: "",
      accepting_bookings: true,
    },
  });

  useEffect(() => {
    if (authLoading || !user || !hasRole(user, "mentor")) return;

    let active = true;
    setIsLoading(true);
    getMyMentorProfile()
      .then((data) => {
        if (active) setProfile(data);
      })
      .catch((error) => {
        if (active) setLoadError(errorMessage(error));
      })
      .finally(() => {
        if (active) setIsLoading(false);
      });

    return () => {
      active = false;
    };
  }, [authLoading, user]);

  const resetForm = (data: MentorProfile) => {
    form.reset({
      name: data.name,
      headline: data.headline,
      bio: data.bio || "",
      hourly_rate: data.hourly_rate ?? 0,
      currency: (data.currency as Currency) || "USD",
      languages: data.languages.join(", "),
      years_of_experience: data.years_of_experience,
      timezone: data.timezone || "UTC",
      skills: data.skills.join(", "),
      accepting_bookings: data.accepting_bookings,
    });
  };

  useEffect(() => {
    if (profile) resetForm(profile);
  }, [profile]);

  if (authLoading) {
    return (
      <MainLayout>
        <div className="container py-12 text-center">
          <PageLoader label="Loading your account..."/>
        </div>
      </MainLayout>
    );
  }

  if (!user) return <Navigate to="/login" />;
  if (!hasRole(user, "mentor")) return <Navigate to="/" />;

  const onSubmit = async (values: ProfileFormValues) => {
    setIsSaving(true);
    setFormError(null);

    const payload: MentorProfileUpdate = {
      name: values.name.trim(),
      headline: values.headline.trim(),
      bio: values.bio?.trim() || "",
      hourly_rate: values.hourly_rate,
      currency: values.currency,
      languages: splitList(values.languages),
      years_of_experience: values.years_of_experience,
      timezone: values.timezone,
      skills: splitList(values.skills),
      accepting_bookings: values.accepting_bookings,
    };

    try {
      const updated = await updateMyMentorProfile(payload);
      setProfile(updated);
      updateUser({ full_name: updated.name, avatar: updated.avatar_url });
      setIsEditing(false);
    } catch (error) {
      setFormError(errorMessage(error));
    } finally {
      setIsSaving(false);
    }
  };

  const handleFileChange = (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (!file) return;

    setAvatarError(null);

    if (!["image/jpeg", "image/png", "image/webp"].includes(file.type)) {
      setAvatarError("Choose a JPEG, PNG, or WebP image.");
      return;
    }

    if (file.size > 5 * 1024 * 1024) {
      setAvatarError("The image must be smaller than 5 MB.");
      return;
    }

    setAvatarFile(file);
    setAvatarPreview(URL.createObjectURL(file));
  };

  const handleUploadAvatar = async () => {
    if (!avatarFile) return;

    setIsAvatarBusy(true);
    setAvatarError(null);

    try {
      const updated = await uploadMyMentorAvatar(avatarFile);
      setProfile(updated);
      updateUser({ avatar: updated.avatar_url });
      setAvatarFile(null);
      setAvatarPreview(null);
      if (fileInputRef.current) fileInputRef.current.value = "";
    } catch (error) {
      setAvatarError(errorMessage(error));
    } finally {
      setIsAvatarBusy(false);
    }
  };

  const handleRemoveAvatar = async () => {
    if (!window.confirm("Remove your profile photo?")) return;

    setIsAvatarBusy(true);
    setAvatarError(null);

    try {
      await deleteMentorAvatar();
      const refreshed = await getMyMentorProfile();
      setProfile(refreshed);
      updateUser({ avatar: null });
    } catch (error) {
      setAvatarError(errorMessage(error));
    } finally {
      setIsAvatarBusy(false);
    }
  };

  const handleAddSlot = async () => {
    if (!slotDate) {
      setSlotError("Choose a date and time.");
      return;
    }

    setIsSlotBusy(true);
    setSlotError(null);

    try {
      const startsAt = new Date(slotDate);
      const endsAt = new Date(startsAt.getTime() + 60 * 60 * 1000);
      await createMyAvailabilitySlot({
        starts_at: startsAt.toISOString(),
        ends_at: endsAt.toISOString(),
      });
      const refreshed = await getMyMentorProfile();
      setProfile(refreshed);
      setSlotDate("");
    } catch (error) {
      setSlotError(errorMessage(error));
    } finally {
      setIsSlotBusy(false);
    }
  };

  const handleDeleteSlot = async (slotId: number) => {
    setIsSlotBusy(true);
    setSlotError(null);

    try {
      await deleteMyAvailabilitySlot(slotId);
      const refreshed = await getMyMentorProfile();
      setProfile(refreshed);
    } catch (error) {
      setSlotError(errorMessage(error));
    } finally {
      setIsSlotBusy(false);
    }
  };

  const timezoneOptions = Array.from(
    new Set([...TIMEZONES, profile?.timezone].filter(Boolean) as string[])
  );

  return (
    <MainLayout>
      <div className="container py-8 max-w-5xl">
        <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 mb-8">
          <div>
            <h1 className="text-3xl font-bold">My Profile</h1>
            <p className="text-muted-foreground">
              This is how mentees see you, plus your private account details.
            </p>
          </div>
          {!isEditing && profile && (
            <Button
              onClick={() => {
                resetForm(profile);
                setIsEditing(true);
              }}
            >
              <Pencil className="h-4 w-4 mr-2" />
              Edit profile
            </Button>
          )}
        </div>

        {loadError && (
          <Alert variant="destructive" className="mb-6">
            <AlertTitle>Could not load your profile</AlertTitle>
            <AlertDescription>{loadError}</AlertDescription>
          </Alert>
        )}

        {isLoading ? (
          <div className="py-12 text-center text-muted-foreground">
            Loading your profile...
          </div>
        ) : profile ? (
          isEditing ? (
            <Form {...form}>
              <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-6">
                {formError && (
                  <Alert variant="destructive">
                    <AlertTitle>Could not save</AlertTitle>
                    <AlertDescription>{formError}</AlertDescription>
                  </Alert>
                )}

                <Card>
                  <CardHeader>
                    <CardTitle>Profile details</CardTitle>
                  </CardHeader>
                  <CardContent className="grid gap-4 sm:grid-cols-2">
                    <FormField
                      control={form.control}
                      name="name"
                      render={({ field }) => (
                        <FormItem>
                          <FormLabel>Name</FormLabel>
                          <FormControl>
                            <Input {...field} />
                          </FormControl>
                          <FormMessage />
                        </FormItem>
                      )}
                    />
                    <FormField
                      control={form.control}
                      name="headline"
                      render={({ field }) => (
                        <FormItem>
                          <FormLabel>Headline</FormLabel>
                          <FormControl>
                            <Input {...field} placeholder="Senior Software Engineer" />
                          </FormControl>
                          <FormMessage />
                        </FormItem>
                      )}
                    />
                    <FormField
                      control={form.control}
                      name="bio"
                      render={({ field }) => (
                        <FormItem className="sm:col-span-2">
                          <FormLabel>About</FormLabel>
                          <FormControl>
                            <Textarea rows={5} {...field} />
                          </FormControl>
                          <FormDescription>Up to 2000 characters.</FormDescription>
                          <FormMessage />
                        </FormItem>
                      )}
                    />
                    <FormField
                      control={form.control}
                      name="hourly_rate"
                      render={({ field }) => (
                        <FormItem>
                          <FormLabel>Hourly rate</FormLabel>
                          <FormControl>
                            <Input type="number" min={0} step="1" {...field} />
                          </FormControl>
                          <FormMessage />
                        </FormItem>
                      )}
                    />
                    <FormField
                      control={form.control}
                      name="currency"
                      render={({ field }) => (
                        <FormItem>
                          <FormLabel>Currency</FormLabel>
                          <Select value={field.value} onValueChange={field.onChange}>
                            <FormControl>
                              <SelectTrigger>
                                <SelectValue />
                              </SelectTrigger>
                            </FormControl>
                            <SelectContent>
                              {CURRENCIES.map((currency) => (
                                <SelectItem key={currency} value={currency}>
                                  {currency}
                                </SelectItem>
                              ))}
                            </SelectContent>
                          </Select>
                          <FormMessage />
                        </FormItem>
                      )}
                    />
                    <FormField
                      control={form.control}
                      name="years_of_experience"
                      render={({ field }) => (
                        <FormItem>
                          <FormLabel>Years of experience</FormLabel>
                          <FormControl>
                            <Input type="number" min={0} step="1" {...field} />
                          </FormControl>
                          <FormMessage />
                        </FormItem>
                      )}
                    />
                    <FormField
                      control={form.control}
                      name="timezone"
                      render={({ field }) => (
                        <FormItem>
                          <FormLabel>Timezone</FormLabel>
                          <Select value={field.value} onValueChange={field.onChange}>
                            <FormControl>
                              <SelectTrigger>
                                <SelectValue />
                              </SelectTrigger>
                            </FormControl>
                            <SelectContent>
                              {timezoneOptions.map((timezone) => (
                                <SelectItem key={timezone} value={timezone}>
                                  {timezone}
                                </SelectItem>
                              ))}
                            </SelectContent>
                          </Select>
                          <FormMessage />
                        </FormItem>
                      )}
                    />
                    <FormField
                      control={form.control}
                      name="languages"
                      render={({ field }) => (
                        <FormItem>
                          <FormLabel>Languages</FormLabel>
                          <FormControl>
                            <Input {...field} placeholder="English, Spanish" />
                          </FormControl>
                          <FormDescription>Separate with commas.</FormDescription>
                          <FormMessage />
                        </FormItem>
                      )}
                    />
                    <FormField
                      control={form.control}
                      name="skills"
                      render={({ field }) => (
                        <FormItem>
                          <FormLabel>Skills</FormLabel>
                          <FormControl>
                            <Input {...field} placeholder="React, Node.js" />
                          </FormControl>
                          <FormDescription>Separate with commas.</FormDescription>
                          <FormMessage />
                        </FormItem>
                      )}
                    />
                    <FormField
                      control={form.control}
                      name="accepting_bookings"
                      render={({ field }) => (
                        <FormItem className="sm:col-span-2 flex flex-row items-center justify-between rounded-lg border p-4">
                          <div className="space-y-0.5">
                            <FormLabel>Accepting bookings</FormLabel>
                            <FormDescription>
                              Let mentees book your services.
                            </FormDescription>
                          </div>
                          <FormControl>
                            <Switch
                              checked={field.value}
                              onCheckedChange={field.onChange}
                            />
                          </FormControl>
                        </FormItem>
                      )}
                    />
                  </CardContent>
                </Card>

                <div className="flex justify-end gap-2">
                  <Button
                    type="button"
                    variant="outline"
                    onClick={() => {
                      resetForm(profile);
                      setFormError(null);
                      setIsEditing(false);
                    }}
                    disabled={isSaving}
                  >
                    Cancel
                  </Button>
                  <Button type="submit" disabled={isSaving}>
                    {isSaving && <Loader2 className="h-4 w-4 mr-2 animate-spin" />}
                    Save changes
                  </Button>
                </div>
              </form>
            </Form>
          ) : (
            <div className="space-y-6">
              <Card>
                <CardContent className="p-6">
                  <div className="flex flex-col sm:flex-row items-center sm:items-start gap-6">
                    <Avatar className="h-28 w-28">
                      <AvatarImage
                        src={avatarPreview || profile.avatar_url || undefined}
                        alt={profile.name}
                      />
                      <AvatarFallback className="text-3xl">
                        {profile.name.charAt(0)}
                      </AvatarFallback>
                    </Avatar>

                    <div className="flex-1 text-center sm:text-left">
                      <div className="flex flex-wrap items-center justify-center sm:justify-start gap-2">
                        <h2 className="text-2xl font-bold">{profile.name}</h2>
                        {profile.is_verified && <Badge>Verified</Badge>}
                      </div>
                      <p className="text-lg text-primary">{profile.headline}</p>
                      <p className="text-sm text-muted-foreground">{profile.email}</p>
                      <div className="flex flex-wrap items-center justify-center sm:justify-start gap-4 mt-3 text-sm">
                        <span className="flex items-center">
                          <Star className="h-4 w-4 mr-1 text-yellow-500" />
                          {profile.rating != null ? profile.rating.toFixed(1) : "New"}
                          {profile.review_count > 0 && ` (${profile.review_count})`}
                        </span>
                        <span>
                          {profile.hourly_rate != null
                            ? `${profile.currency} ${profile.hourly_rate}/hr`
                            : "Rate not set"}
                        </span>
                        <span>{profile.years_of_experience} years experience</span>
                        <span>{profile.timezone}</span>
                      </div>

                      <div className="flex flex-wrap justify-center sm:justify-start gap-2 mt-4">
                        <Button
                          type="button"
                          variant="outline"
                          onClick={() => fileInputRef.current?.click()}
                          disabled={isAvatarBusy}
                        >
                          <Camera className="h-4 w-4 mr-2" />
                          {profile.avatar_url ? "Change photo" : "Upload photo"}
                        </Button>
                        {profile.avatar_url && !avatarPreview && (
                          <Button
                            type="button"
                            variant="outline"
                            onClick={handleRemoveAvatar}
                            disabled={isAvatarBusy}
                          >
                            <Trash2 className="h-4 w-4 mr-2" />
                            Remove photo
                          </Button>
                        )}
                        {avatarPreview && (
                          <>
                            <Button
                              type="button"
                              onClick={handleUploadAvatar}
                              disabled={isAvatarBusy}
                            >
                              {isAvatarBusy && (
                                <Loader2 className="h-4 w-4 mr-2 animate-spin" />
                              )}
                              Upload photo
                            </Button>
                            <Button
                              type="button"
                              variant="ghost"
                              onClick={() => {
                                setAvatarFile(null);
                                setAvatarPreview(null);
                                if (fileInputRef.current) fileInputRef.current.value = "";
                              }}
                              disabled={isAvatarBusy}
                            >
                              Cancel
                            </Button>
                          </>
                        )}
                      </div>
                      <input
                        ref={fileInputRef}
                        type="file"
                        accept="image/jpeg,image/png,image/webp"
                        className="hidden"
                        onChange={handleFileChange}
                      />
                      <p className="text-xs text-muted-foreground mt-2">
                        JPEG, PNG, or WebP. Max 5 MB.
                      </p>
                      {avatarError && (
                        <p className="text-sm text-destructive mt-2">{avatarError}</p>
                      )}
                    </div>
                  </div>
                </CardContent>
              </Card>

              <Card>
                <CardHeader>
                  <CardTitle>About</CardTitle>
                </CardHeader>
                <CardContent className="space-y-4">
                  <p className="text-muted-foreground whitespace-pre-line">
                    {profile.bio || "No bio yet."}
                  </p>
                  <div>
                    <Label>Languages</Label>
                    <div className="flex flex-wrap gap-2 mt-2">
                      {profile.languages.length > 0 ? (
                        profile.languages.map((language) => (
                          <Badge key={language} variant="outline">
                            {language}
                          </Badge>
                        ))
                      ) : (
                        <span className="text-sm text-muted-foreground">None added.</span>
                      )}
                    </div>
                  </div>
                  <div>
                    <Label>Skills</Label>
                    <div className="flex flex-wrap gap-2 mt-2">
                      {profile.skills.length > 0 ? (
                        profile.skills.map((skill) => (
                          <Badge key={skill} variant="secondary">
                            {skill}
                          </Badge>
                        ))
                      ) : (
                        <span className="text-sm text-muted-foreground">None added.</span>
                      )}
                    </div>
                  </div>
                  <div className="flex items-center gap-2 text-sm">
                    <span className="text-muted-foreground">Accepting bookings:</span>
                    <Badge variant={profile.accepting_bookings ? "success" : "secondary"}>
                      {profile.accepting_bookings ? "Yes" : "No"}
                    </Badge>
                  </div>
                </CardContent>
              </Card>

              <Card>
                <CardHeader className="flex flex-row items-center justify-between">
                  <CardTitle>Services</CardTitle>
                  <Button asChild size="sm" variant="outline">
                    <Link to="/services/create">Create service</Link>
                  </Button>
                </CardHeader>
                <CardContent>
                  {profile.services.length > 0 ? (
                    <div className="space-y-3">
                      {profile.services.map((service) => (
                        <div
                          key={service.id}
                          className="flex items-center justify-between border-b pb-3 last:border-0 last:pb-0"
                        >
                          <div>
                            <Link
                              to={`/services/${service.id}`}
                              className="font-medium hover:text-primary"
                            >
                              {service.title}
                            </Link>
                            <p className="text-sm text-muted-foreground">
                              {service.duration} minutes
                            </p>
                          </div>
                          <p className="font-semibold">
                            {profile.currency} {service.price}
                          </p>
                        </div>
                      ))}
                    </div>
                  ) : (
                    <p className="text-muted-foreground">
                      You have not created any services yet.
                    </p>
                  )}
                </CardContent>
              </Card>

              <Card>
                <CardHeader>
                  <CardTitle>Availability</CardTitle>
                </CardHeader>
                <CardContent className="space-y-4">
                  <div className="flex flex-col sm:flex-row gap-2">
                    <Input
                      type="datetime-local"
                      value={slotDate}
                      onChange={(event) => setSlotDate(event.target.value)}
                    />
                    <Button
                      type="button"
                      onClick={handleAddSlot}
                      disabled={isSlotBusy}
                    >
                      {isSlotBusy ? (
                        <Loader2 className="h-4 w-4 mr-2 animate-spin" />
                      ) : (
                        <Plus className="h-4 w-4 mr-2" />
                      )}
                      Add slot
                    </Button>
                  </div>
                  {slotError && <p className="text-sm text-destructive">{slotError}</p>}
                  {profile.availability.length > 0 ? (
                    <div className="space-y-2">
                      {profile.availability.map((slot) => (
                        <div
                          key={slot.id}
                          className="flex items-center justify-between border-b pb-2 last:border-0 last:pb-0"
                        >
                          <span className="text-sm">
                            {new Date(slot.startsAt).toLocaleString()}
                          </span>
                          <Button
                            type="button"
                            size="sm"
                            variant="ghost"
                            onClick={() => handleDeleteSlot(slot.id)}
                            disabled={isSlotBusy}
                          >
                            <Trash2 className="h-4 w-4" />
                          </Button>
                        </div>
                      ))}
                    </div>
                  ) : (
                    <p className="text-muted-foreground">No upcoming slots.</p>
                  )}
                </CardContent>
              </Card>
            </div>
          )
        ) : null}
      </div>
    </MainLayout>
  );
}
