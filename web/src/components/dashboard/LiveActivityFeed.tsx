"use client";

import React from "react";
import { AlertTriangle, Flame, HeartPulse, Car, CloudLightning, Clock } from "lucide-react";
import { useTheme } from "@/lib/theme-context";

interface ActivityFeedProps {
  emergencies: any[];
}

export function LiveActivityFeed({ emergencies }: ActivityFeedProps) {
  const { t } = useTheme();

  const getTypeIcon = (type: string) => {
    switch ((type || "").toLowerCase()) {
      case "fire":
        return <Flame className="w-4 h-4 text-red-500" />;
      case "medical":
        return <HeartPulse className="w-4 h-4 text-blue-500" />;
      case "accident":
        return <Car className="w-4 h-4 text-amber-500" />;
      case "natural_disaster":
        return <CloudLightning className="w-4 h-4 text-emerald-500" />;
      default:
        return <AlertTriangle className="w-4 h-4 text-red-500" />;
    }
  };

  const getStatusBadge = (status: string) => {
    const s = (status || "").toLowerCase();
    if (s === "pending") {
      return (
        <span className="px-2 py-0.5 text-[10px] font-extrabold uppercase rounded bg-red-500/15 text-red-500 border border-red-500/40 animate-pulse">
          Pending
        </span>
      );
    } else if (s === "accepted") {
      return (
        <span className="px-2 py-0.5 text-[10px] font-extrabold uppercase rounded bg-emerald-500/15 text-emerald-600 border border-emerald-500/40">
          En Route
        </span>
      );
    } else if (s === "completed") {
      return (
        <span className="px-2 py-0.5 text-[10px] font-extrabold uppercase rounded bg-[var(--bg-subtle)] text-[var(--text-muted)] border border-[var(--border-main)]">
          Resolved
        </span>
      );
    }
    return (
      <span className="px-2 py-0.5 text-[10px] font-extrabold uppercase rounded bg-[var(--bg-subtle)] text-[var(--text-muted)] border border-[var(--border-main)]">
        {status}
      </span>
    );
  };

  const formatTime = (dateStr: string) => {
    if (!dateStr) return "";
    try {
      const d = new Date(dateStr);
      return d.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
    } catch {
      return dateStr;
    }
  };

  const items = (emergencies || []).slice(0, 7);

  return (
    <div className="glass-panel bg-[var(--bg-surface)] p-6 rounded-2xl border border-[var(--border-main)]">
      <div className="flex items-center justify-between mb-4">
        <div>
          <h4 className="text-sm font-black text-[var(--text-main)] tracking-wide">
            {t("Live Incident Stream", "တိုက်ရိုက် အရေးပေါ် လှုပ်ရှားမှု စာရင်း")}
          </h4>
          <p className="text-xs text-[var(--text-muted)] mt-0.5">
            {t("Real-time incoming SOS alerts", "အဝင် အရေးပေါ် ခေါ်ဆိုမှုများ")}
          </p>
        </div>
      </div>

      {items.length === 0 ? (
        <div className="py-12 text-center text-[var(--text-muted)] text-sm">
          {t("No recent emergency dispatches recorded.", "မကြာသေးမီက အရေးပေါ် မှတ်တမ်း မရှိပါ။")}
        </div>
      ) : (
        <div className="space-y-2.5">
          {items.map((e, idx) => (
            <div
              key={e.id || idx}
              className="flex items-center justify-between p-3.5 rounded-xl bg-[var(--bg-subtle)] border border-[var(--border-subtle)] hover:border-red-500/40 transition-colors"
            >
              <div className="flex items-center gap-3">
                <div className="p-2 rounded-lg bg-[var(--bg-card)] border border-[var(--border-main)]">
                  {getTypeIcon(e.type)}
                </div>
                <div>
                  <p className="text-xs font-bold text-[var(--text-main)] uppercase tracking-wider">
                    {e.type || "Emergency"}
                  </p>
                  <p className="text-[11px] text-[var(--text-muted)]">
                    {e.user?.email || "Citizen User"} • {e.location_address || e.operating_region || "Emergency Response Sector"}
                  </p>
                </div>
              </div>
              <div className="flex items-center gap-3">
                {getStatusBadge(e.status)}
                <span className="text-[11px] text-[var(--text-muted)] font-mono flex items-center gap-1">
                  <Clock className="w-3 h-3 text-[var(--text-subtle)]" />
                  {formatTime(e.created_at)}
                </span>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
