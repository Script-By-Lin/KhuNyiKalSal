"use client";

import React, { useState, useEffect } from "react";
import { Sidebar } from "./Sidebar";
import { Header } from "./Header";
import { useAuth } from "@/lib/auth-context";

export function AppLayout({
  children,
  title,
}: {
  children: React.ReactNode;
  title?: string;
}) {
  const { user, loading } = useAuth();
  const [mounted, setMounted] = useState(false);

  useEffect(() => {
    setMounted(true);
  }, []);

  if (!mounted || loading) {
    return (
      <div
        suppressHydrationWarning
        className="h-screen w-screen flex items-center justify-center bg-[var(--bg-main)] text-[var(--text-main)]"
      >
        <div className="flex flex-col items-center gap-4">
          <div className="w-12 h-12 border-4 border-red-500 border-t-transparent rounded-full animate-spin"></div>
          <p className="text-sm font-semibold tracking-widest text-[var(--text-muted)] uppercase">
            Loading Command Center...
          </p>
        </div>
      </div>
    );
  }

  if (!user) {
    return null; // AuthContext handles redirect
  }

  return (
    <div className="min-h-screen bg-[var(--bg-main)] text-[var(--text-main)] flex">
      <Sidebar />
      <div className="flex-1 ml-64 flex flex-col min-w-0">
        <Header title={title} />
        <main className="flex-1 p-6 overflow-y-auto w-full">{children}</main>
      </div>
    </div>
  );
}
