import api from "@/lib/axios";
export interface ChatPerson { id: number; name: string; role: string | null; avatar: string | null; last_active_at: string | null; online: boolean }
export interface ChatAttachment { filename: string; content_type: string; byte_size: number; download_path: string }
export interface ChatMessage { id: number; conversation_id: number; sender_id: number; sender_name: string; content: string | null; created_at: string; read_by: number[]; attachment: ChatAttachment | null }
export interface ChatConversation { id: number; kind: "direct" | "group"; title: string; last_message_at: string; unread_count: number; members: ChatPerson[]; last_message: ChatMessage | null }
export interface ConversationPage { conversations: ChatConversation[]; meta: { page: number; total: number; total_pages: number } }
export interface MessagePage { messages: ChatMessage[]; has_more: boolean; oldest_id: number | null }
export const getConversations = async (page = 1, q = "") => (await api.get<ConversationPage>("/conversations", { params: { page, q } })).data;
export const getConversation = async (id: string) => (await api.get<ChatConversation>(`/conversations/${id}`)).data;
export const createConversation = async (participant_ids: number[], kind: "direct" | "group" = "direct", title?: string) => (await api.post<ChatConversation>("/conversations", { participant_ids, kind, title })).data;
export const getMessageContacts = async (q = "") => (await api.get<ChatPerson[]>("/conversations/contacts", { params: { q } })).data;
export const getMessages = async (id: string, before_id: number | null = null) => (await api.get<MessagePage>(`/conversations/${id}/messages`, { params: before_id ? { before_id } : undefined })).data;
export async function sendChatMessage(payload: { id: string; content: string; attachment: File | null; nonce: string }) {
  const body = new FormData();
  body.append("message[content]", payload.content);
  body.append("message[client_nonce]", payload.nonce);
  if (payload.attachment) body.append("message[attachment]", payload.attachment);
  return (await api.post<ChatMessage>(`/conversations/${payload.id}/messages`, body)).data;
}
export const markConversationRead = async ({ id, messageId }: { id: string; messageId: number }) => (await api.patch(`/conversations/${id}/read`, { last_message_id: messageId })).data;
export const downloadChatAttachment = async (path: string) => (await api.get<Blob>(path, { responseType: "blob" })).data;
export const getUnreadMessageCount = async () => (await api.get<{ unread: number }>("/conversations/unread-count")).data;
