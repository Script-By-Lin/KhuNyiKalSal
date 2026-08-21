"use client";

import React, { useState } from "react";
import useSWR from "swr";
import { AppLayout } from "@/components/layout/AppLayout";
import { RadarMap } from "@/components/map/RadarMap";
import { fetcher } from "@/lib/api";
import { useTheme } from "@/lib/theme-context";
import { Radio, Flame, HeartPulse, Car, CloudLightning } from "lucide-react";

export default function RadarPage() {
  const { t } = useTheme();
  const [filterType, setFilterType] = useState<string>("all");

  const { data: emergencies } = useSWR("/admin/emergencies?limit=100", fetcher, {
    refreshInterval: 4000,
  });

  const { data: orgs } = useSWR("/admin/organizations?limit=100", fetcher, {
    refreshInterval: 15000,
  });

  const filteredEmergencies = (emergencies || []).filter((e: any) => {
    if (filterType === "all") return true;
    return (e.type || "").toLowerCase() === filterType;
  });

  return (
    <AppLayout title={t("Live GPS Tactical Radar", "တိုက်ရိုက် GPS အရေးပေါ် ရေဒါမြေပုံ")}>
      <div className="space-y-6">
        {/* Radar Controls & Type Filter Chips */}
        <div className="flex flex-wrap items-center justify-between gap-4 p-4 glass-panel bg-[var(--bg-surface)] rounded-2xl border border-[var(--border-main)] shadow-sm">
          <div className="flex items-center gap-3">
            <div className="p-2 rounded-xl bg-red-600/20 text-red-500 border border-red-500/30">
              <Radio className="w-5 h-5 animate-pulse" />
            </div>
            <div>
              <h3 className="font-extrabold text-sm text-[var(--text-main)]">
                {t("Real-Time Tracking Radar", "အချိန်နှင့်တပြေးညီ နေရာရှာဖွေရေး ရေဒါ")}
              </h3>
              <p className="text-xs text-[var(--text-muted)]">
                {t(
                  "Monitoring active emergencies, rescue stations & coverage perimeters",
                  "အရေးပေါ်ဖြစ်စဉ်များနှင့် ကယ်ဆယ်ရေးစခန်းများအား စောင့်ကြည့်ခြင်း"
                )}
              </p>
            </div>
          </div>

          <div className="flex items-center gap-2">
            {[
              { id: "all", label: t("All Incidents", "အားလုံး") },
              { id: "medical", label: t("Medical", "ဆေးဝါး"), icon: HeartPulse },
              { id: "fire", label: t("Fire", "မီးသတ်"), icon: Flame },
              { id: "accident", label: t("Accident", "ယာဉ်မတော်တဆ"), icon: Car },
              { id: "natural_disaster", label: t("Disaster", "သဘာဝဘေး"), icon: CloudLightning },
            ].map((chip) => {
              const isActive = filterType === chip.id;
              return (
                <button
                  key={chip.id}
                  onClick={() => setFilterType(chip.id)}
                  className={`px-3 py-1.5 rounded-xl text-xs font-bold border transition-all cursor-pointer ${
                    isActive
                      ? "bg-red-600 text-white border-red-500 shadow-md shadow-red-600/30"
                      : "bg-[var(--bg-subtle)] text-[var(--text-muted)] border-[var(--border-main)] hover:text-[var(--text-main)]"
                  }`}
                >
                  {chip.label}
                </button>
              );
            })}
          </div>
        </div>

        {/* Tactical Interactive Radar Map */}
        <RadarMap
          emergencies={filteredEmergencies}
          organizations={orgs || []}
        />
      </div>
    </AppLayout>
  );
}
