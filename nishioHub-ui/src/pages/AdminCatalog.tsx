import { PageLoader } from '@/components/loaders/PageLoader';
import { useState } from 'react';
import { Navigate } from 'react-router-dom';
import { AdminWorkspace } from '@/components/layout/admin-workspace';
import { useAuth } from '@/lib/auth-context';
import { isPlatformAdmin } from '@/lib/utils';
import { useServices } from '@/lib/services-context';
import { createCategory, updateCategory, deleteCategory, uploadCategoryImage, deleteCategoryImage, type CategoryPayload } from '@/lib/category-api';
import type { Category } from '@/types';
import { toast } from '@/components/ui/use-toast';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Textarea } from '@/components/ui/textarea';
import { Switch } from '@/components/ui/switch';
import { Badge } from '@/components/ui/badge';
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { PlusCircle, Edit, Trash2, Loader2 } from 'lucide-react';
function categoryErrorMessage(error: unknown): string {
  const detail = (error as { response?: { data?: { detail?: unknown } } })?.response?.data?.detail;
  if (Array.isArray(detail)) return detail.join(", ");
  if (typeof detail === "string") return detail;
  return "Something went wrong. Please try again.";
}

export default function AdminCatalog() {
  const { user, isLoading: authLoading } = useAuth();
  const { categories, refresh: refreshData, isLoading: categoriesLoading } = useServices();
  const [search, setSearch] = useState('');
  const [categoryDialogOpen, setCategoryDialogOpen] = useState(false);
  const [editingCategory, setEditingCategory] = useState<Category | null>(null);
  const [categoryName, setCategoryName] = useState("");
  const [categorySlug, setCategorySlug] = useState("");
  const [categoryDescription, setCategoryDescription] = useState("");
  const [categoryTopics, setCategoryTopics] = useState("");
  const [categoryPosition, setCategoryPosition] = useState(0);
  const [categoryActive, setCategoryActive] = useState(true);
  const [categoryImageFile, setCategoryImageFile] = useState<File | null>(null);
  const [categoryError, setCategoryError] = useState<string | null>(null);
  const [categorySaving, setCategorySaving] = useState(false);
  const resetCategoryForm = () => {
    setEditingCategory(null);
    setCategoryName("");
    setCategorySlug("");
    setCategoryDescription("");
    setCategoryTopics("");
    setCategoryPosition(0);
    setCategoryActive(true);
    setCategoryImageFile(null);
    setCategoryError(null);
  };

  const openCreateCategory = () => {
    resetCategoryForm();
    setCategoryDialogOpen(true);
  };

  const openEditCategory = (category: Category) => {
    setEditingCategory(category);
    setCategoryName(category.name);
    setCategorySlug(category.slug);
    setCategoryDescription(category.description || "");
    setCategoryTopics((category.topics || []).join(", "));
    setCategoryPosition(category.position ?? 0);
    setCategoryActive(category.is_active ?? true);
    setCategoryImageFile(null);
    setCategoryError(null);
    setCategoryDialogOpen(true);
  };

  const handleCategorySubmit = async () => {
    setCategorySaving(true);
    setCategoryError(null);

    const payload: CategoryPayload = {
      name: categoryName.trim(),
      slug: categorySlug.trim() || undefined,
      description: categoryDescription.trim(),
      position: Number(categoryPosition) || 0,
      is_active: categoryActive,
      topics: categoryTopics.split(",").map((topic) => topic.trim()).filter(Boolean),
    };

    try {
      let saved = editingCategory
        ? await updateCategory(editingCategory.id, payload)
        : await createCategory(payload);

      if (categoryImageFile) {
        saved = await uploadCategoryImage(saved.id, categoryImageFile);
      }

      await refreshData();
      setCategoryDialogOpen(false);
      resetCategoryForm();
      toast({ title: editingCategory ? "Category updated" : "Category created" });
    } catch (error) {
      setCategoryError(categoryErrorMessage(error));
    } finally {
      setCategorySaving(false);
    }
  };

  const handleDeleteCategory = async (category: Category) => {
    if (!window.confirm(`Delete "${category.name}"?`)) return;

    try {
      await deleteCategory(category.id);
      await refreshData();
      toast({ title: "Category deleted" });
    } catch (error) {
      toast({
        title: "Could not delete category",
        description: categoryErrorMessage(error),
        variant: "destructive",
      });
    }
  };

  const handleCategoryImageDelete = async (category: Category) => {
    if (!window.confirm("Remove this category image?")) return;

    try {
      await deleteCategoryImage(category.id);
      await refreshData();
      toast({ title: "Category image removed" });
    } catch (error) {
      toast({
        title: "Could not remove image",
        description: categoryErrorMessage(error),
        variant: "destructive",
      });
    }
  };
  
  if (authLoading) return <PageLoader label="Loading categories…"/>;
  if (!user) return <Navigate to="/login" replace />;
  if (!isPlatformAdmin(user)) return <Navigate to="/" replace />;
  return <AdminWorkspace active="dashboard" search={search} onSearch={setSearch} searchPlaceholder="Search learning categories…"><h1 className="text-2xl font-bold mb-5">Learning Categories</h1>
            <Card>
              <CardHeader>
                <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
                  <div>
                    <CardTitle>Categories</CardTitle>
                    <CardDescription>Manage service categories</CardDescription>
                  </div>
                  <Button size="sm" className="ml-auto" onClick={openCreateCategory}>
                    <PlusCircle className="h-4 w-4 mr-2" />
                    Add Category
                  </Button>
                </div>
              </CardHeader>
              <CardContent>
                {categoriesLoading ? (
                  <div className="py-10 text-center text-muted-foreground">
                    <Loader2 className="h-5 w-5 animate-spin mx-auto mb-2" />
                    Loading categories...
                  </div>
                ) : categories.length === 0 ? (
                  <div className="py-10 text-center text-muted-foreground">
                    No categories yet. Add your first category.
                  </div>
                ) : (
                  <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                    {categories.filter(item => `${item.name} ${item.description || ""}`.toLowerCase().includes(search.toLowerCase())).map((category) => {
                      const image = category.image_url || category.iconPath;
                      return (
                        <Card key={category.id}>
                          <CardHeader className="pb-3">
                            <div className="flex items-center gap-3">
                              {image ? (
                                <div className="w-12 h-12 rounded bg-muted flex items-center justify-center overflow-hidden">
                                  <img src={image} alt={category.name} className="w-10 h-10 object-contain" />
                                </div>
                              ) : (
                                <div className="w-12 h-12 rounded bg-muted flex items-center justify-center">
                                  <span className="text-lg font-bold text-muted-foreground">
                                    {category.name.charAt(0)}
                                  </span>
                                </div>
                              )}
                              <div>
                                <CardTitle className="text-lg">{category.name}</CardTitle>
                                <CardDescription>
                                  {category.service_count ?? 0} services
                                  {category.is_active === false && " · inactive"}
                                </CardDescription>
                              </div>
                            </div>
                          </CardHeader>
                          <CardContent>
                            <p className="text-sm text-muted-foreground mb-4">
                              {category.description || "No description provided"}
                            </p>
                            <div className="flex flex-wrap gap-2 mb-4">
                              {(category.topics || []).slice(0, 3).map((topic, index) => (
                                <Badge key={index} variant="secondary" className="text-xs">
                                  {topic}
                                </Badge>
                              ))}
                              {(category.topics || []).length > 3 && (
                                <Badge variant="outline" className="text-xs">
                                  +{(category.topics || []).length - 3} more
                                </Badge>
                              )}
                            </div>
                            <div className="flex items-center justify-between">
                              <p className="text-sm text-muted-foreground">
                                Slug: <code className="text-xs">{category.slug}</code>
                              </p>
                              <div className="flex gap-2">
                                <Button variant="ghost" size="sm" className="h-8 w-8 p-0" onClick={() => openEditCategory(category)}>
                                  <Edit className="h-4 w-4" />
                                </Button>
                                <Button variant="ghost" size="sm" className="h-8 w-8 p-0" onClick={() => handleDeleteCategory(category)}>
                                  <Trash2 className="h-4 w-4 text-destructive" />
                                </Button>
                              </div>
                            </div>
                          </CardContent>
                        </Card>
                      );
                    })}
                  </div>
                )}
              </CardContent>
            </Card>

            <Dialog open={categoryDialogOpen} onOpenChange={setCategoryDialogOpen}>
              <DialogContent>
                <DialogHeader>
                  <DialogTitle>{editingCategory ? "Edit Category" : "Add New Category"}</DialogTitle>
                  <DialogDescription>
                    {editingCategory ? "Update this category." : "Create a new category for mentoring services."}
                  </DialogDescription>
                </DialogHeader>
                <div className="grid gap-4 py-4">
                  {categoryError && (
                    <div className="rounded-md border border-destructive/30 bg-destructive/10 p-3 text-sm text-destructive">
                      {categoryError}
                    </div>
                  )}
                  <div className="grid gap-2">
                    <Label htmlFor="category-name">Category Name</Label>
                    <Input id="category-name" value={categoryName} onChange={(e) => setCategoryName(e.target.value)} placeholder="E.g. Web Development" />
                  </div>
                  <div className="grid gap-2">
                    <Label htmlFor="category-slug">URL Slug</Label>
                    <Input id="category-slug" value={categorySlug} onChange={(e) => setCategorySlug(e.target.value)} placeholder="Auto-generated if left blank" />
                  </div>
                  <div className="grid gap-2">
                    <Label htmlFor="category-description">Description</Label>
                    <Textarea id="category-description" value={categoryDescription} onChange={(e) => setCategoryDescription(e.target.value)} placeholder="Brief description of this category" />
                  </div>
                  <div className="grid gap-2">
                    <Label htmlFor="category-topics">Topics</Label>
                    <Input id="category-topics" value={categoryTopics} onChange={(e) => setCategoryTopics(e.target.value)} placeholder="React, Node.js, TypeScript" />
                    <p className="text-xs text-muted-foreground">Separate with commas.</p>
                  </div>
                  <div className="grid grid-cols-2 gap-4">
                    <div className="grid gap-2">
                      <Label htmlFor="category-position">Position</Label>
                      <Input id="category-position" type="number" min={0} value={categoryPosition} onChange={(e) => setCategoryPosition(Number(e.target.value))} />
                    </div>
                    <div className="flex items-center justify-between rounded-lg border p-3">
                      <Label htmlFor="category-active">Active</Label>
                      <Switch id="category-active" checked={categoryActive} onCheckedChange={setCategoryActive} />
                    </div>
                  </div>
                  <div className="grid gap-2">
                    <Label htmlFor="category-image">Image</Label>
                    <Input id="category-image" type="file" accept="image/png,image/jpeg,image/webp" onChange={(e) => setCategoryImageFile(e.target.files?.[0] || null)} />
                    <p className="text-xs text-muted-foreground">PNG, JPEG, or WebP. Max 5 MB.</p>
                    {editingCategory && (editingCategory.image_url || editingCategory.iconPath) && (
                      <Button type="button" variant="outline" size="sm" onClick={() => handleCategoryImageDelete(editingCategory)}>
                        <Trash2 className="h-4 w-4 mr-2" />
                        Remove current image
                      </Button>
                    )}
                  </div>
                </div>
                <div className="flex justify-end gap-2">
                  <Button variant="outline" onClick={() => setCategoryDialogOpen(false)} disabled={categorySaving}>
                    Cancel
                  </Button>
                  <Button onClick={handleCategorySubmit} disabled={categorySaving}>
                    {categorySaving && <Loader2 className="h-4 w-4 mr-2 animate-spin" />}
                    {editingCategory ? "Save Changes" : "Create Category"}
                  </Button>
                </div>
              </DialogContent>
            </Dialog>
</AdminWorkspace>;
}
