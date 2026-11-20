import api from "@/lib/axios";
import { Category } from "@/types";

export interface CategoryPayload {
  name: string;
  slug?: string;
  description?: string;
  position?: number;
  is_active?: boolean;
  parent_id?: number | null;
  topics?: string[];
  image_alt?: string;
}

export async function listCategories(options?: {
  includeInactive?: boolean;
}): Promise<Category[]> {
  const response = await api.get<Category[]>("/categories", {
    params: options?.includeInactive ? { include_inactive: true } : undefined,
  });
  return response.data;
}

export async function getCategory(idOrSlug: string | number): Promise<Category> {
  const response = await api.get<Category>(`/categories/${idOrSlug}`);
  return response.data;
}

export async function createCategory(payload: CategoryPayload): Promise<Category> {
  const response = await api.post<Category>("/categories", { category: payload });
  return response.data;
}

export async function updateCategory(
  id: string | number,
  payload: Partial<CategoryPayload>
): Promise<Category> {
  const response = await api.patch<Category>(`/categories/${id}`, {
    category: payload,
  });
  return response.data;
}

export async function deleteCategory(id: string | number): Promise<void> {
  await api.delete(`/categories/${id}`);
}

export async function uploadCategoryImage(
  id: string | number,
  file: File
): Promise<Category> {
  const formData = new FormData();
  formData.append("image", file);
  const response = await api.patch<Category>(`/categories/${id}/image`, formData, {
    headers: { "Content-Type": "multipart/form-data" },
  });
  return response.data;
}

export async function deleteCategoryImage(id: string | number): Promise<void> {
  await api.delete(`/categories/${id}/image`);
}
