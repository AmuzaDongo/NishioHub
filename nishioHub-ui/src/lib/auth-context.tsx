"use client";

import { createContext, useContext, useEffect, useState } from "react";
import api from "@/lib/axios";

export type User = {
  id: string;
  full_name: string;
  email: string;
  avatar: string;
  role: {
    id: number;
    name: string;
  } | null;
  roles?: { id: number; name: string }[];
  management_permissions?: string[];
  bio?: string;
  school?: string | null;
  location?: string;
  website?: string;
  joinedAt?: string;
  access_token: string;
  refresh_token: string;
};

interface AuthContextType {
  user: User | null;
  isAuthenticated: boolean;
  isLoading: boolean;
  authError: string | null;
  login: (email: string, password: string) => Promise<boolean>;
  register: (
    full_name: string,
    email: string,
    phone_number: string,
    password: string,
    role_id: number
  ) => Promise<boolean>;
  logout: () => void;
  updateUser: (updates: Record<string, unknown>) => void;
  updateUserProfile: (updates: Record<string, unknown>) => Promise<void>;
  updatePassword: (currentPassword: string, newPassword: string) => Promise<void>;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export const AuthProvider = ({ children }: { children: React.ReactNode }) => {
  const [authError, setAuthError] = useState<string | null>(null);
  const [user, setUser] = useState<User | null>(null);
  const [isLoading, setIsLoading] = useState<boolean>(true);

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
    setIsLoading(false);
  }, []);

  const isAuthenticated = !!user?.access_token;

  const login = async (email: string, password: string): Promise<boolean> => {
    setIsLoading(true);
    setAuthError(null);
    try {
      const formData = new URLSearchParams();
      formData.append("username", email);
      formData.append("password", password);

      const res = await api.post("/auth/login", formData, {
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
        },
      });

      const { access_token, refresh_token } = res.data;

      const profileRes = await api.get("/users/me", {
        headers: {
          Authorization: `Bearer ${access_token}`,
        },
      });

      const userProfile = profileRes.data;

      const userWithTokens: User = {
        ...userProfile,
        access_token,
        refresh_token,
      };

      setUser(userWithTokens);
      localStorage.setItem("nishioHub_user", JSON.stringify(userWithTokens));

      return true;
    } catch (error) {
      const detail = (error as { response?: { data?: { detail?: string | string[] } } })?.response?.data?.detail;
      setAuthError(Array.isArray(detail) ? detail.join(', ') : detail || 'Could not sign in. Please try again.');
      return false;
    } finally {
      setIsLoading(false);
    }
  };

  const register = async (
    full_name: string,
    email: string,
    phone_number: string,
    password: string,
    role_id: number
  ): Promise<boolean> => {
    setIsLoading(true);
    setAuthError(null);
    try {
      await api.post("/auth/register", {
        full_name,
        email,
        phone_number,
        password,
        role_id,
      });

      // Registration successful, redirect user to login instead of auto-login
      return true;
    } catch (error) {
      const detail = (error as { response?: { data?: { detail?: string | string[] } } })?.response?.data?.detail;
      setAuthError(Array.isArray(detail) ? detail.join(', ') : detail || 'Could not create your account. Please try again.');
      return false;
    } finally {
      setIsLoading(false);
    }
  };

  const logout = () => {
    setUser(null);
    localStorage.removeItem("nishioHub_user");
    // Optional: await api.post("/auth/logout");
  };

  const updateUser = (updates: Record<string, unknown>) => {
    setUser((previous) => {
      if (!previous) return previous;
      const next = { ...previous, ...updates } as User;
      localStorage.setItem("nishioHub_user", JSON.stringify(next));
      return next;
    });
  };

  const updateUserProfile = async (updates: Record<string, unknown>) => {
    updateUser(updates);
  };

  const updatePassword = async (_currentPassword: string, _newPassword: string) => {
    throw new Error("Password changes are not available in this build.");
  };

  return (
    <AuthContext.Provider
      value={{
        user,
        isAuthenticated,
        isLoading,
        authError,
        login,
        register,
        logout,
        updateUser,
        updateUserProfile,
        updatePassword,
      }}
    >
      {children}
    </AuthContext.Provider>
  );
};

export const useAuth = (): AuthContextType => {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error("useAuth must be used within an AuthProvider");
  }
  return context;
};
