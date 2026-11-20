import { createContext, useContext, type ReactNode } from "react";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { createConversation, getUnreadMessageCount } from "@/lib/messages-api";
import { useAuth } from "@/lib/auth-context";
import { toast } from "sonner";

interface MessagingContextType {
  getOrCreateConversation: (otherUserId: string) => Promise<string | null>;
  hasUnreadMessages: boolean;
  unreadCount: number;
}
const MessagingContext = createContext<MessagingContextType | undefined>(undefined);
export function MessagingProvider({ children }: { children: ReactNode }) {
  const { user } = useAuth();
  const client = useQueryClient();
  const query = useQuery({ queryKey: ["message-unread-count", user?.id], queryFn: getUnreadMessageCount,
    enabled: !!user?.access_token, staleTime: 5000, refetchInterval: 10_000 });
  const getOrCreateConversation = async (otherUserId: string) => {
    if (!user) { toast.error("Sign in to start a conversation"); return null; }
    try {
      const conversation = await createConversation([Number(otherUserId)]);
      await client.invalidateQueries({ queryKey: ["conversations", user.id] });
      return String(conversation.id);
    } catch { toast.error("Could not start this conversation. Please try again."); return null; }
  };
  const unreadCount = query.data?.unread || 0;
  return <MessagingContext.Provider value={{ getOrCreateConversation, hasUnreadMessages: unreadCount > 0, unreadCount }}>{children}</MessagingContext.Provider>;
}
export function useMessaging() {
  const context = useContext(MessagingContext);
  if (!context) throw new Error("useMessaging must be used within a MessagingProvider");
  return context;
}
