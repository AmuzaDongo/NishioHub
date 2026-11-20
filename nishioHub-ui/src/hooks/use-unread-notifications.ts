import { useQuery } from "@tanstack/react-query";
import { useAuth } from "@/lib/auth-context";
import { getUnreadNotificationCount } from "@/lib/notifications-api";
export function useUnreadNotifications() {
  const { user } = useAuth();
  const query = useQuery({ queryKey: ["notification-unread-count", user?.id], queryFn: getUnreadNotificationCount,
    enabled: !!user?.access_token, staleTime: 30_000, refetchInterval: 60_000 });
  return query.data?.unread || 0;
}
