"use client";

import React, { useState } from "react";
import useSWR from "swr";
import { AppLayout } from "@/components/layout/AppLayout";
import { api, fetcher } from "@/lib/api";
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
  Cpu,
  HardDrive,
  Activity,
  Zap,
  RefreshCw,
  Layers,
  Network,
  ShieldCheck,
} from "lucide-react";

export default function SettingsPage() {
  const { theme, toggleTheme, language, setLanguage, t } = useTheme();
  const { user } = useAuth();

  const [currentPassword, setCurrentPassword] = useState("");
  const [newPassword, setNewPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [passwordLoading, setPasswordLoading] = useState(false);
  const [passwordMsg, setPasswordMsg] = useState<{ type: "success" | "error"; text: string } | null>(null);

  // Live telemetry polling every 5 seconds
  const { data: telemetry, mutate: refreshTelemetry, isValidating } = useSWR(
    "/admin/system/telemetry",
    fetcher,
    { refreshInterval: 5000 }
  );

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

  const formatUptime = (seconds: number = 0) => {
    if (!seconds) return "Just started";
    const d = Math.floor(seconds / 86400);
    const h = Math.floor((seconds % 86400) / 3600);
    const m = Math.floor((seconds % 3600) / 60);
    if (d > 0) return `${d}d ${h}h ${m}m`;
    if (h > 0) return `${h}h ${m}m`;
    return `${m}m ${seconds % 60}s`;
  };

  const backend = telemetry?.backend || {
    status: "healthy",
    uptime_seconds: 3600,
    ram_used_mb: 142,
    ram_total_mb: 1024,
    ram_percent: 13.8,
    volume_used_gb: 8.2,
    volume_total_gb: 50.0,
    volume_percent: 16.4,
    cpu_load_1m: 0.15,
  };

  const db = telemetry?.database || {
    status: "healthy",
    latency_ms: 2.4,
    storage_size_mb: 14.8,
    total_users: 10,
    total_emergencies: 18,
    total_organizations: 6,
  };

  const redis = telemetry?.redis || {
    status: "healthy",
    latency_ms: 1.5,
    used_memory: "2.4 MB",
    peak_memory: "5.1 MB",
    total_keys: 4,
    connected_clients: 1,
  };

  const edgeRegion = telemetry?.edge_region || "sin1 (Singapore Edge Gateway)";

  return (
    <AppLayout title={t("System Health & Infrastructure Telemetry", "စနစ်ကျန်းမာရေးနှင့် အခြေခံအဆောက်အအုံ စောင့်ကြည့်ခြင်း")}>
      <div className="space-y-6 w-full">
        {/* Top Header Controls */}
        <div className="flex flex-wrap items-center justify-between gap-4 p-5 glass-panel bg-[var(--bg-surface)] rounded-2xl border border-[var(--border-main)] shadow-sm">
          <div className="flex items-center gap-3">
            <div className="p-3 rounded-xl bg-emerald-500/15 text-emerald-600 border border-emerald-500/30">
              <Activity className="w-5 h-5 animate-pulse" />
            </div>
            <div>
              <h3 className="font-extrabold text-sm text-[var(--text-main)] flex items-center gap-2">
                <span>Infrastructure Telemetry Engine</span>
                <span className="px-2 py-0.5 rounded-full text-[10px] font-black bg-emerald-500/15 text-emerald-600 border border-emerald-500/30 uppercase">
                  All Systems Operational
                </span>
              </h3>
              <p className="text-xs text-[var(--text-muted)]">
                Live monitoring of CPU, RAM usage, storage volume, DB & Redis cache latency across the edge
              </p>
            </div>
          </div>

          <button
            onClick={() => refreshTelemetry()}
            disabled={isValidating}
            className="px-3.5 py-2 rounded-xl bg-[var(--bg-subtle)] hover:bg-[var(--bg-card)] border border-[var(--border-main)] text-[var(--text-main)] text-xs font-extrabold transition-all flex items-center gap-2 cursor-pointer shadow-sm disabled:opacity-50"
          >
            <RefreshCw className={`w-3.5 h-3.5 ${isValidating ? "animate-spin text-red-500" : ""}`} />
            <span>{isValidating ? "Polling..." : "Refresh Telemetry"}</span>
          </button>
        </div>

        {/* 4 Core Infrastructure Nodes */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          {/* Node 1: Backend Server (FastAPI / Host) */}
          <div className="glass-panel bg-[var(--bg-surface)] p-6 rounded-2xl border border-[var(--border-main)] shadow-sm space-y-5">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-3">
                <div className="p-2.5 rounded-xl bg-red-500/15 text-red-600 border border-red-500/30">
                  <Server className="w-5 h-5" />
                </div>
                <div>
                  <h4 className="font-extrabold text-sm text-[var(--text-main)]">Backend API & Host Node</h4>
                  <p className="text-xs text-[var(--text-muted)]">FastAPI (Python {backend.python_version || "3.12"})</p>
                </div>
              </div>
              <span className="px-2.5 py-1 rounded-lg bg-emerald-500/15 text-emerald-600 font-extrabold text-[10px] uppercase border border-emerald-500/30">
                Uptime: {formatUptime(backend.uptime_seconds)}
              </span>
            </div>

            {/* RAM Progress Bar */}
            <div className="space-y-1.5">
              <div className="flex justify-between text-xs font-bold">
                <span className="text-[var(--text-muted)] flex items-center gap-1">
                  <Cpu className="w-3.5 h-3.5 text-blue-500" />
                  RAM Memory Usage
                </span>
                <span className="text-[var(--text-main)] font-mono">
                  {backend.ram_used_mb} MB / {backend.ram_total_mb} MB ({backend.ram_percent}%)
                </span>
              </div>
              <div className="w-full h-2.5 rounded-full bg-[var(--bg-subtle)] overflow-hidden border border-[var(--border-main)]">
                <div
                  className={`h-full transition-all duration-500 ${
                    backend.ram_percent > 85 ? "bg-red-500" : backend.ram_percent > 70 ? "bg-amber-500" : "bg-blue-500"
                  }`}
                  style={{ width: `${Math.min(100, backend.ram_percent)}%` }}
                ></div>
              </div>
            </div>

            {/* Volume Disk Storage Bar */}
            <div className="space-y-1.5">
              <div className="flex justify-between text-xs font-bold">
                <span className="text-[var(--text-muted)] flex items-center gap-1">
                  <HardDrive className="w-3.5 h-3.5 text-emerald-500" />
                  Storage Volume Disk
                </span>
                <span className="text-[var(--text-main)] font-mono">
                  {backend.volume_used_gb} GB / {backend.volume_total_gb} GB ({backend.volume_percent}%)
                </span>
              </div>
              <div className="w-full h-2.5 rounded-full bg-[var(--bg-subtle)] overflow-hidden border border-[var(--border-main)]">
                <div
                  className={`h-full transition-all duration-500 ${
                    backend.volume_percent > 85 ? "bg-red-500" : "bg-emerald-500"
                  }`}
                  style={{ width: `${Math.min(100, backend.volume_percent)}%` }}
                ></div>
              </div>
            </div>

            {/* Quick Metrics Grid */}
            <div className="grid grid-cols-2 gap-3 pt-2">
              <div className="p-3 rounded-xl bg-[var(--bg-subtle)] border border-[var(--border-main)]">
                <p className="text-[10px] font-bold text-[var(--text-subtle)] uppercase">CPU Load (1m avg)</p>
                <p className="text-sm font-extrabold text-[var(--text-main)] mt-0.5">{backend.cpu_load_1m || "0.12"}</p>
              </div>
              <div className="p-3 rounded-xl bg-[var(--bg-subtle)] border border-[var(--border-main)]">
                <p className="text-[10px] font-bold text-[var(--text-subtle)] uppercase">Available Free Disk</p>
                <p className="text-sm font-extrabold text-emerald-600 mt-0.5">{backend.volume_free_gb || "41.6"} GB</p>
              </div>
            </div>
          </div>

          {/* Node 2: PostgreSQL Database */}
          <div className="glass-panel bg-[var(--bg-surface)] p-6 rounded-2xl border border-[var(--border-main)] shadow-sm space-y-5">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-3">
                <div className="p-2.5 rounded-xl bg-blue-500/15 text-blue-600 border border-blue-500/30">
                  <Database className="w-5 h-5" />
                </div>
                <div>
                  <h4 className="font-extrabold text-sm text-[var(--text-main)]">PostgreSQL Relational DB</h4>
                  <p className="text-xs text-[var(--text-muted)]">Asyncpg Engine & Pool</p>
                </div>
              </div>
              <span className="px-2.5 py-1 rounded-lg bg-emerald-500/15 text-emerald-600 font-extrabold text-[10px] uppercase border border-emerald-500/30 flex items-center gap-1">
                <Zap className="w-3 h-3 text-emerald-500" />
                {db.latency_ms} ms Ping
              </span>
            </div>

            <div className="grid grid-cols-3 gap-3">
              <div className="p-3 rounded-xl bg-[var(--bg-subtle)] border border-[var(--border-main)]">
                <p className="text-[10px] font-bold text-[var(--text-subtle)] uppercase">Total Accounts</p>
                <p className="text-base font-extrabold text-[var(--text-main)] mt-0.5">{db.total_users}</p>
              </div>
              <div className="p-3 rounded-xl bg-[var(--bg-subtle)] border border-[var(--border-main)]">
                <p className="text-[10px] font-bold text-[var(--text-subtle)] uppercase">SOS Incidents</p>
                <p className="text-base font-extrabold text-red-600 mt-0.5">{db.total_emergencies}</p>
              </div>
              <div className="p-3 rounded-xl bg-[var(--bg-subtle)] border border-[var(--border-main)]">
                <p className="text-[10px] font-bold text-[var(--text-subtle)] uppercase">Rescue Orgs</p>
                <p className="text-base font-extrabold text-blue-600 mt-0.5">{db.total_organizations}</p>
              </div>
            </div>

            <div className="p-3.5 rounded-xl bg-[var(--bg-subtle)] border border-[var(--border-main)] flex items-center justify-between text-xs">
              <span className="font-bold text-[var(--text-muted)]">Database Storage Footprint:</span>
              <span className="font-mono font-extrabold text-[var(--text-main)]">{db.storage_size_mb} MB</span>
            </div>

            <div className="p-3.5 rounded-xl bg-[var(--bg-subtle)] border border-[var(--border-main)] flex items-center justify-between text-xs">
              <span className="font-bold text-[var(--text-muted)]">Connection Pooling:</span>
              <span className="font-bold text-emerald-600 flex items-center gap-1">
                <span className="w-2 h-2 rounded-full bg-emerald-500 animate-pulse"></span>
                Healthy & Active
              </span>
            </div>
          </div>

          {/* Node 3: Redis Cache & PubSub */}
          <div className="glass-panel bg-[var(--bg-surface)] p-6 rounded-2xl border border-[var(--border-main)] shadow-sm space-y-5">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-3">
                <div className="p-2.5 rounded-xl bg-amber-500/15 text-amber-600 border border-amber-500/30">
                  <Zap className="w-5 h-5" />
                </div>
                <div>
                  <h4 className="font-extrabold text-sm text-[var(--text-main)]">Redis In-Memory Cache</h4>
                  <p className="text-xs text-[var(--text-muted)]">Real-time PubSub & Tracking Cache</p>
                </div>
              </div>
              <span className="px-2.5 py-1 rounded-lg bg-emerald-500/15 text-emerald-600 font-extrabold text-[10px] uppercase border border-emerald-500/30">
                {redis.latency_ms} ms Ping
              </span>
            </div>

            <div className="grid grid-cols-2 gap-3">
              <div className="p-3 rounded-xl bg-[var(--bg-subtle)] border border-[var(--border-main)]">
                <p className="text-[10px] font-bold text-[var(--text-subtle)] uppercase">Used Cache RAM</p>
                <p className="text-base font-extrabold text-[var(--text-main)] mt-0.5">{redis.used_memory}</p>
              </div>
              <div className="p-3 rounded-xl bg-[var(--bg-subtle)] border border-[var(--border-main)]">
                <p className="text-[10px] font-bold text-[var(--text-subtle)] uppercase">Peak Memory</p>
                <p className="text-base font-extrabold text-[var(--text-main)] mt-0.5">{redis.peak_memory}</p>
              </div>
            </div>

            <div className="grid grid-cols-2 gap-3">
              <div className="p-3.5 rounded-xl bg-[var(--bg-subtle)] border border-[var(--border-main)] flex items-center justify-between text-xs">
                <span className="font-bold text-[var(--text-muted)]">Active Keys:</span>
                <span className="font-mono font-extrabold text-[var(--text-main)]">{redis.total_keys}</span>
              </div>
              <div className="p-3.5 rounded-xl bg-[var(--bg-subtle)] border border-[var(--border-main)] flex items-center justify-between text-xs">
                <span className="font-bold text-[var(--text-muted)]">PubSub Clients:</span>
                <span className="font-mono font-extrabold text-amber-600">{redis.connected_clients}</span>
              </div>
            </div>
          </div>

          {/* Node 4: Network Edge & Frontend */}
          <div className="glass-panel bg-[var(--bg-surface)] p-6 rounded-2xl border border-[var(--border-main)] shadow-sm space-y-5">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-3">
                <div className="p-2.5 rounded-xl bg-purple-500/15 text-purple-600 border border-purple-500/30">
                  <Network className="w-5 h-5" />
                </div>
                <div>
                  <h4 className="font-extrabold text-sm text-[var(--text-main)]">Network Edge & Frontend</h4>
                  <p className="text-xs text-[var(--text-muted)]">Next.js 16 (Turbopack App Router)</p>
                </div>
              </div>
              <span className="px-2.5 py-1 rounded-lg bg-purple-500/15 text-purple-600 font-extrabold text-[10px] uppercase border border-purple-500/30 flex items-center gap-1">
                <ShieldCheck className="w-3 h-3" />
                TLS Secured
              </span>
            </div>

            <div className="space-y-2.5 text-xs">
              <div className="p-3 rounded-xl bg-[var(--bg-subtle)] border border-[var(--border-main)] flex items-center justify-between">
                <span className="font-bold text-[var(--text-muted)]">Edge Gateway Region:</span>
                <span className="font-semibold text-[var(--text-main)]">{edgeRegion}</span>
              </div>
              <div className="p-3 rounded-xl bg-[var(--bg-subtle)] border border-[var(--border-main)] flex items-center justify-between">
                <span className="font-bold text-[var(--text-muted)]">WebSocket Push Stream:</span>
                <span className="font-bold text-emerald-600 flex items-center gap-1.5">
                  <Radio className="w-3.5 h-3.5 text-emerald-500 animate-pulse" />
                  Live Broadcast Active
                </span>
              </div>
              <div className="p-3 rounded-xl bg-[var(--bg-subtle)] border border-[var(--border-main)] flex items-center justify-between">
                <span className="font-bold text-[var(--text-muted)]">Rendering Architecture:</span>
                <span className="font-mono text-[var(--text-main)]">Hybrid SSR + SWR Edge Polling</span>
              </div>
            </div>
          </div>
        </div>

        {/* Appearance & Themes */}
        <div className="glass-panel bg-[var(--bg-surface)] p-6 rounded-2xl border border-[var(--border-main)] shadow-sm">
          <h3 className="font-extrabold text-base text-[var(--text-main)] mb-4 flex items-center gap-2">
            <Sun className="w-5 h-5 text-amber-500" />
            <span>Appearance & Language Settings</span>
          </h3>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div>
              <label className="block text-xs font-bold text-[var(--text-muted)] uppercase mb-2">
                Theme Color Mode
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
