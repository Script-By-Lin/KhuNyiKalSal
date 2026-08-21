"use client";

import React, { createContext, useContext, useState, useEffect } from "react";
import { useRouter, usePathname } from "next/navigation";
import { api } from "./api";

export interface AdminUser {
  id: string;
  email: string;
  role: string;
  full_name?: string;
}

interface AuthContextType {
  user: AdminUser | null;
  token: string | null;
  loading: boolean;
  login: (token: string, user: AdminUser) => void;
  logout: () => void;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<AdminUser | null>(null);
  const [token, setToken] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const router = useRouter();
  const pathname = usePathname();

  useEffect(() => {
    const storedToken = localStorage.getItem("admin_access_token");
    const storedUser = localStorage.getItem("admin_user");

    if (storedToken && storedUser) {
      try {
        const parsedUser = JSON.parse(storedUser);
        const role = (parsedUser.role || "").toUpperCase();
        if (role === "ADMIN" || role === "SUPERADMIN") {
          setToken(storedToken);
          setUser(parsedUser);
        } else {
          // Clear if not an admin role
          localStorage.removeItem("admin_access_token");
          localStorage.removeItem("admin_user");
        }
      } catch {
        localStorage.removeItem("admin_access_token");
        localStorage.removeItem("admin_user");
      }
    }
    setLoading(false);
  }, []);

  useEffect(() => {
    if (!loading) {
      const isPublicPath = pathname === "/login";
      if (!token && !isPublicPath) {
        router.push("/login");
      } else if (token && isPublicPath) {
        router.push("/");
      }
    }
  }, [token, loading, pathname, router]);

  const login = (newToken: string, newUser: AdminUser) => {
    localStorage.setItem("admin_access_token", newToken);
    localStorage.setItem("admin_user", JSON.stringify(newUser));
    setToken(newToken);
    setUser(newUser);
    router.push("/");
  };

  const logout = () => {
    localStorage.removeItem("admin_access_token");
    localStorage.removeItem("admin_user");
    setToken(null);
    setUser(null);
    router.push("/login");
  };

  return (
    <AuthContext.Provider value={{ user, token, loading, login, logout }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error("useAuth must be used within an AuthProvider");
  }
  return context;
}
