"use client";

import React, { useState } from "react";
import { AppLayout } from "@/components/layout/AppLayout";
import { api } from "@/lib/api";
import { useTheme } from "@/lib/theme-context";
import { useAuth } from "@/lib/auth-context";
import {
  Settings,
  Sun,
  Moon,
  Globe,
  KeyRound,
  Server,
  Database,
  Radio,
} from "lucide-react";

export default function SettingsPage() {
  const { theme, toggleTheme, language, setLanguage, t } = useTheme();
  const { user } = useAuth();

  const [currentPassword, setCurrentPassword] = useState("");
  const [newPassword, setNewPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [passwordLoading, setPasswordLoading] = useState(false);
  const [passwordMsg, setPasswordMsg] = useState<{ type: "success" | "error"; text: string } | null>(null);

  const handlePasswordChange = async (e: React.FormEvent) => {
    e.preventDefault();
    if (newPassword !== confirmPassword) {
      setPasswordMsg({ type: "error", text: "New passwords do not match." });
      return;
    }
    setPasswordLoading(true);
    setPasswordMsg(null);

    try {
      await api.post("/auth/change-password", {
        current_password: currentPassword,
        new_password: newPassword,
      });
      setPasswordMsg({ type: "success", text: "Admin password successfully updated!" });
      setCurrentPassword("");
      setNewPassword("");
      setConfirmPassword("");
    } catch (err: any) {
      setPasswordMsg({ type: "error", text: err.message || "Failed to update password." });
    } finally {
      setPasswordLoading(false);
    }
  };

  return (
    <AppLayout title={t("Settings & System Health", "ဆက်တင်နှင့် စနစ်ကျန်းမာရေး")}>
      <div className="space-y-8 max-w-4xl">
        {/* System Health Diagnostics */}
        <div className="glass-panel bg-[var(--bg-surface)] p-6 rounded-2xl border border-[var(--border-main)] shadow-sm">
          <h3 className="font-extrabold text-base text-[var(--text-main)] mb-4 flex items-center gap-2">
            <Server className="w-5 h-5 text-emerald-500" />
            <span>Infrastructure Health & Services</span>
          </h3>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div className="p-4 rounded-xl bg-[var(--bg-subtle)] border border-[var(--border-main)] flex items-center gap-3">
              <div className="p-2.5 rounded-lg bg-emerald-500/15 text-emerald-600 border border-emerald-500/30">
                <Database className="w-5 h-5" />
              </div>
              <div>
                <p className="text-[11px] text-[var(--text-muted)] font-extrabold uppercase">PostgreSQL</p>
                <p className="text-sm font-bold text-[var(--text-main)] flex items-center gap-1.5 mt-0.5">
                  <span className="w-2 h-2 rounded-full bg-emerald-500 animate-pulse"></span>
                  Operational
                </p>
              </div>
            </div>

            <div className="p-4 rounded-xl bg-[var(--bg-subtle)] border border-[var(--border-main)] flex items-center gap-3">
              <div className="p-2.5 rounded-lg bg-emerald-500/15 text-emerald-600 border border-emerald-500/30">
                <Server className="w-5 h-5" />
              </div>
              <div>
                <p className="text-[11px] text-[var(--text-muted)] font-extrabold uppercase">Redis Cache</p>
                <p className="text-sm font-bold text-[var(--text-main)] flex items-center gap-1.5 mt-0.5">
                  <span className="w-2 h-2 rounded-full bg-emerald-500 animate-pulse"></span>
                  Active
                </p>
              </div>
            </div>

            <div className="p-4 rounded-xl bg-[var(--bg-subtle)] border border-[var(--border-main)] flex items-center gap-3">
              <div className="p-2.5 rounded-lg bg-emerald-500/15 text-emerald-600 border border-emerald-500/30">
                <Radio className="w-5 h-5" />
              </div>
              <div>
                <p className="text-[11px] text-[var(--text-muted)] font-extrabold uppercase">WebSocket Engine</p>
                <p className="text-sm font-bold text-[var(--text-main)] flex items-center gap-1.5 mt-0.5">
                  <span className="w-2 h-2 rounded-full bg-emerald-500 animate-pulse"></span>
                  Real-time Stream
                </p>
              </div>
            </div>
          </div>
        </div>

        {/* Appearance & Themes */}
        <div className="glass-panel bg-[var(--bg-surface)] p-6 rounded-2xl border border-[var(--border-main)] shadow-sm">
          <h3 className="font-extrabold text-base text-[var(--text-main)] mb-4 flex items-center gap-2">
            <Sun className="w-5 h-5 text-amber-500" />
            <span>Appearance & Language</span>
          </h3>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div>
              <label className="block text-xs font-bold text-[var(--text-muted)] uppercase mb-2">
                Color Mode
              </label>
              <button
                onClick={toggleTheme}
                className="w-full flex items-center justify-between p-3.5 rounded-xl bg-[var(--bg-subtle)] border border-[var(--border-main)] text-sm font-semibold hover:border-red-500/40 transition-colors cursor-pointer"
              >
                <span className="flex items-center gap-2 text-[var(--text-main)]">
                  {theme === "dark" ? <Moon className="w-4 h-4 text-blue-400" /> : <Sun className="w-4 h-4 text-amber-500" />}
                  <span>{theme === "dark" ? "Command Dark Mode" : "Light Studio Mode"}</span>
                </span>
                <span className="text-xs px-2.5 py-1 rounded-lg bg-[var(--bg-card)] text-[var(--text-main)] border border-[var(--border-main)] font-bold">
                  Toggle
                </span>
              </button>
            </div>

            <div>
              <label className="block text-xs font-bold text-[var(--text-muted)] uppercase mb-2">
                Language (ဘာသာစကား)
              </label>
              <button
                onClick={() => setLanguage(language === "en" ? "my" : "en")}
                className="w-full flex items-center justify-between p-3.5 rounded-xl bg-[var(--bg-subtle)] border border-[var(--border-main)] text-sm font-semibold hover:border-red-500/40 transition-colors cursor-pointer"
              >
                <span className="flex items-center gap-2 text-[var(--text-main)]">
                  <Globe className="w-4 h-4 text-red-500" />
                  <span>{language === "en" ? "English (US)" : "မြန်မာစာ (Myanmar)"}</span>
                </span>
                <span className="text-xs px-2.5 py-1 rounded-lg bg-[var(--bg-card)] text-[var(--text-main)] border border-[var(--border-main)] font-bold">
                  Switch
                </span>
              </button>
            </div>
          </div>
        </div>

        {/* Change Admin Password */}
        <div className="glass-panel bg-[var(--bg-surface)] p-6 rounded-2xl border border-[var(--border-main)] shadow-sm">
          <h3 className="font-extrabold text-base text-[var(--text-main)] mb-4 flex items-center gap-2">
            <KeyRound className="w-5 h-5 text-red-500" />
            <span>Administrator Security</span>
          </h3>

          {passwordMsg && (
            <div
              className={`mb-4 p-3 rounded-xl text-xs font-bold ${
                passwordMsg.type === "success"
                  ? "bg-emerald-500/15 text-emerald-600 border border-emerald-500/30"
                  : "bg-red-500/15 text-red-600 border border-red-500/30"
              }`}
            >
              {passwordMsg.text}
            </div>
          )}

          <form onSubmit={handlePasswordChange} className="space-y-4 max-w-md">
            <div>
              <label className="block text-xs font-bold text-[var(--text-muted)] uppercase mb-1">
                Current Password
              </label>
              <input
                type="password"
                required
                value={currentPassword}
                onChange={(e) => setCurrentPassword(e.target.value)}
                className="w-full panel-input rounded-xl p-2.5 text-sm"
              />
            </div>

            <div>
              <label className="block text-xs font-bold text-[var(--text-muted)] uppercase mb-1">
                New Password
              </label>
              <input
                type="password"
                required
                value={newPassword}
                onChange={(e) => setNewPassword(e.target.value)}
                className="w-full panel-input rounded-xl p-2.5 text-sm"
              />
            </div>

            <div>
              <label className="block text-xs font-bold text-[var(--text-muted)] uppercase mb-1">
                Confirm New Password
              </label>
              <input
                type="password"
                required
                value={confirmPassword}
                onChange={(e) => setConfirmPassword(e.target.value)}
                className="w-full panel-input rounded-xl p-2.5 text-sm"
              />
            </div>

            <button
              type="submit"
              disabled={passwordLoading}
              className="px-6 py-2.5 rounded-xl bg-red-600 hover:bg-red-500 text-white font-bold text-xs shadow-lg shadow-red-600/30 transition-all disabled:opacity-50 cursor-pointer"
            >
              {passwordLoading ? "Updating..." : "Update Password"}
            </button>
          </form>
        </div>
      </div>
    </AppLayout>
  );
}
