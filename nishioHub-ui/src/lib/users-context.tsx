import React, {
  createContext,
  useContext,
  useEffect,
  useState,
  ReactNode,
  useCallback,
} from 'react';
import api from '@/lib/axios';

// --- Types ---
export interface UserRole {
  id: number;
  name: string;
}

export interface UserProfile {
  phone_number: string;
  gender: string;
  birth_date: string;
  address: string;
  city: string;
  country: string;
  profile_picture?: string;
  bio?: string;
  id: number;
  user_id: number;
}

export interface User {
  id: number;
  is_active: boolean;
  full_name: string;
  email: string;
  role: UserRole | null;
  roles?: UserRole[];
  avatar?: string | null;
  school?: string | null;
  bio?: string | null;
  location?: string | null;
  website?: string | null;
  profile?: UserProfile | null;
  joinedAt?: string | Date;
}

interface AuthUser {
  access_token: string;
  refresh_token: string;
}

interface UsersContextType {
  users: User[];
  isLoading: boolean;
  error: Error | null;
  refetchUsers: () => Promise<void>;
  addUser: (user: User) => void;
  removeUser: (userId: number) => void;
}

// --- Context Creation ---
const UsersContext = createContext<UsersContextType | undefined>(undefined);

// --- Provider ---
interface UsersProviderProps {
  children: ReactNode;
}

export const UsersProvider: React.FC<UsersProviderProps> = ({ children }) => {
  const [user, setUser] = useState<AuthUser | null>(null);
  const [users, setUsers] = useState<User[]>([]);
  const [isLoading, setIsLoading] = useState<boolean>(true);
  const [error, setError] = useState<Error | null>(null);

  const isAuthenticated = !!user?.access_token;

  // Load AuthUser from LocalStorage
  useEffect(() => {
    const storedUser = localStorage.getItem("nishioHub_user");
    if (storedUser) {
      try {
        const parsedUser = JSON.parse(storedUser);
        setUser(parsedUser);
      } catch (error) {
        console.error("Failed to parse stored user:", error);
        localStorage.removeItem("nishioHub_user");
      }
    }
  }, []);

  // Fetch Users
  const fetchUsers = useCallback(async () => {
    if (!user?.access_token) return;  // <-- Token must exist

    setIsLoading(true);
    setError(null);

    try {
      const response = await api.get<User[]>('/users', {
        headers: {
          Authorization: `Bearer ${user.access_token}`,  // <-- Attach Token
        },
      });
      setUsers(response.data);
    } catch (err) {
      setError(err instanceof Error ? err : new Error('Failed to fetch users'));
      console.error('UsersProvider: fetchUsers error:', err);
    } finally {
      setIsLoading(false);
    }
  }, [user?.access_token]);

  // Trigger fetchUsers when authenticated
  useEffect(() => {
    if (user?.access_token) {
      fetchUsers();
    }
  }, [user?.access_token, fetchUsers]);

  // Add user
  const addUser = useCallback((user: User) => {
    setUsers(prev => [...prev, user]);
  }, []);

  // Remove user
  const removeUser = useCallback((userId: number) => {
    setUsers(prev => prev.filter(user => user.id !== userId));
  }, []);

  return (
    <UsersContext.Provider
      value={{ users, isLoading, error, refetchUsers: fetchUsers, addUser, removeUser }}
    >
      {children}
    </UsersContext.Provider>
  );
};

// --- Hook ---
export const useUsers = (): UsersContextType => {
  const context = useContext(UsersContext);
  if (!context) {
    throw new Error('useUsers must be used within a UsersProvider');
  }
  return context;
};
