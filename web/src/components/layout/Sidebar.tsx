"use client";

import React from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { motion } from "framer-motion";
import {
  LayoutDashboard,
  Radar,
  Users,
  Building2,
  HeartHandshake,
  Megaphone,
  Settings,
  ShieldAlert,
  LogOut,
} from "lucide-react";
import { useAuth } from "@/lib/auth-context";
import { useTheme } from "@/lib/theme-context";

export function Sidebar() {
  const pathname = usePathname();
  const { user, logout } = useAuth();
  const { t } = useTheme();

  const navItems = [
    {
      href: "/",
      label: t("Dashboard", "ဒက်ရှ်ဘုတ်"),
      icon: LayoutDashboard,
    },
    {
      href: "/radar",
      label: t("Live GPS Radar", "တိုက်ရိုက် GPS ရေဒါ"),
      icon: Radar,
      badge: "LIVE",
    },
    {
      href: "/users",
      label: t("User & Bans", "သုံးစွဲသူနှင့် ပိတ်ပင်မှုများ"),
      icon: Users,
    },
    {
      href: "/organizations",
      label: t("Rescue Orgs", "ကယ်ဆယ်ရေး အဖွဲ့များ"),
      icon: Building2,
    },
    {
      href: "/blood-donations",
      label: t("Blood Donation", "သွေးလှူဒါန်းမှု"),
      icon: HeartHandshake,
    },
    {
      href: "/announcements",
      label: t("Announcements", "အရေးပေါ် ကြေညာချက်များ"),
      icon: Megaphone,
    },
    {
      href: "/settings",
      label: t("Settings & Health", "ဆက်တင်နှင့် စနစ်ကျန်းမာရေး"),
      icon: Settings,
    },
  ];

  return (
    <aside className="w-64 h-screen fixed left-0 top-0 z-40 flex flex-col justify-between glass-panel border-r border-[var(--border-main)] bg-[var(--bg-surface)] text-[var(--text-main)] select-none">
      {/* Brand Header */}
      <div>
        <div className="p-6 flex items-center gap-3 border-b border-[var(--border-main)]">
          <div className="w-10 h-10 rounded-xl bg-red-600/20 border border-red-500 flex items-center justify-center shadow-lg shadow-red-600/30">
            <ShieldAlert className="w-6 h-6 text-red-500 animate-pulse" />
          </div>
          <div>
            <h1 className="font-black text-sm tracking-wider text-[var(--text-main)]">
              KHU NYI KAL SAL
            </h1>
            <p className="text-[11px] text-red-500 font-bold tracking-widest uppercase">
              Command Center
            </p>
          </div>
        </div>

        {/* Navigation Items */}
        <nav className="p-4 space-y-1.5">
          {navItems.map((item) => {
            const isActive = pathname === item.href;
            const Icon = item.icon;

            return (
              <Link
                key={item.href}
                href={item.href}
                className={`relative flex items-center justify-between px-4 py-3 rounded-xl text-xs font-bold transition-all duration-200 ${
                  isActive
                    ? "text-white bg-red-600 shadow-md shadow-red-600/30"
                    : "text-[var(--text-muted)] hover:text-[var(--text-main)] hover:bg-[var(--bg-subtle)]"
                }`}
              >
                <div className="flex items-center gap-3">
                  <Icon className={`w-4 h-4 ${isActive ? "text-white" : "text-[var(--text-muted)]"}`} />
                  <span>{item.label}</span>
                </div>
                {item.badge && (
                  <span className="px-2 py-0.5 text-[9px] font-extrabold bg-red-500/20 border border-red-400 text-red-500 rounded-full animate-pulse">
                    {item.badge}
                  </span>
                )}
                {isActive && (
                  <motion.div
                    layoutId="activeIndicator"
                    className="absolute right-0 w-1.5 h-6 bg-white rounded-l-full"
                    transition={{ type: "spring", stiffness: 350, damping: 30 }}
                  />
                )}
              </Link>
            );
          })}
        </nav>
      </div>

      {/* User Info & Quick Logout */}
      <div className="p-4 border-t border-[var(--border-main)] bg-[var(--bg-subtle)]">
        <div className="flex items-center justify-between p-2 rounded-lg">
          <div className="flex items-center gap-2.5 overflow-hidden">
            <div className="w-8 h-8 rounded-full bg-red-600 text-white font-bold flex items-center justify-center text-xs shadow-sm shadow-red-600/40">
              {(user?.email || "A").substring(0, 1).toUpperCase()}
            </div>
            <div className="truncate text-left">
              <p className="text-xs font-bold text-[var(--text-main)] truncate">
                {user?.email || "Admin"}
              </p>
              <span className="text-[9px] px-1.5 py-0.5 rounded bg-red-500/15 text-red-600 font-extrabold uppercase">
                {user?.role || "ADMIN"}
              </span>
            </div>
          </div>
          <button
            onClick={logout}
            title={t("Logout", "ထွက်ရန်")}
            className="p-1.5 text-[var(--text-muted)] hover:text-red-500 hover:bg-red-500/10 rounded-lg transition-colors cursor-pointer"
          >
            <LogOut className="w-4 h-4" />
          </button>
        </div>
      </div>
    </aside>
  );
}
