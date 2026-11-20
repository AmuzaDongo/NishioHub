import api from "@/lib/axios";
import { AvailabilitySlot, MentorProfile, MentorProfileUpdate } from "@/types";

export async function getMyMentorProfile(): Promise<MentorProfile> {
  const response = await api.get<MentorProfile>("/me/mentor_profile");
  return response.data;
}

export async function updateMyMentorProfile(
  payload: MentorProfileUpdate
): Promise<MentorProfile> {
  const response = await api.patch<MentorProfile>("/me/mentor_profile", payload);
  return response.data;
}

export async function uploadMyMentorAvatar(file: File): Promise<MentorProfile> {
  const formData = new FormData();
  formData.append("avatar", file);
  const response = await api.post<MentorProfile>(
    "/me/mentor_profile/avatar",
    formData,
    { headers: { "Content-Type": "multipart/form-data" } }
  );
  return response.data;
}

export async function deleteMentorAvatar(): Promise<void> {
  await api.delete("/me/mentor_profile/avatar");
}

export async function createMyAvailabilitySlot(payload: {
  starts_at: string;
  ends_at: string;
}): Promise<AvailabilitySlot> {
  const response = await api.post<AvailabilitySlot>(
    "/mentors/me/availability",
    payload
  );
  return response.data;
}

export async function deleteMyAvailabilitySlot(slotId: number): Promise<void> {
  await api.delete(`/mentors/me/availability/${slotId}`);
}
