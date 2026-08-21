"use client";

import React from "react";
import {
  AreaChart,
  Area,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  PieChart,
  Pie,
  Cell,
} from "recharts";
import { useTheme } from "@/lib/theme-context";

interface EmergencyChartsProps {
  emergencies: any[];
}

export function EmergencyCharts({ emergencies }: EmergencyChartsProps) {
  const { theme, t } = useTheme();

  // Aggregate Type Breakdown
  const typeCounts: Record<string, number> = {
    medical: 0,
    fire: 0,
    accident: 0,
    natural_disaster: 0,
  };

  // Aggregate 24h Hourly Distribution
  const hourlyCounts: Record<string, number> = {};
  for (let i = 0; i < 24; i += 3) {
    const hourLabel = `${i.toString().padStart(2, "0")}:00`;
    hourlyCounts[hourLabel] = 0;
  }

  (emergencies || []).forEach((e) => {
    const rawType = (e.type || "medical").toLowerCase();
    if (typeCounts[rawType] !== undefined) {
      typeCounts[rawType]++;
    } else {
      typeCounts.medical++;
    }

    if (e.created_at) {
      const date = new Date(e.created_at);
      const hour = date.getHours();
      const roundedHour = Math.floor(hour / 3) * 3;
      const key = `${roundedHour.toString().padStart(2, "0")}:00`;
      if (hourlyCounts[key] !== undefined) {
        hourlyCounts[key]++;
      }
    }
  });

  const pieData = [
    { name: t("Medical", "ဆေးဝါး/ကျန်းမာရေး"), value: typeCounts.medical || 1, color: "#3B82F6" },
    { name: t("Fire Rescue", "မီးသတ်/ကယ်ဆယ်ရေး"), value: typeCounts.fire || 0, color: "#EF4444" },
    { name: t("Traffic Accident", "ယာဉ်မတော်တဆ"), value: typeCounts.accident || 0, color: "#F59E0B" },
    { name: t("Natural Disaster", "သဘာဝဘေးအန္တရာယ်"), value: typeCounts.natural_disaster || 0, color: "#10B981" },
  ].filter((d) => d.value > 0);

  const lineData = Object.entries(hourlyCounts).map(([time, count]) => ({
    time,
    emergencies: count,
  }));

  const tooltipBg = theme === "dark" ? "#0F172A" : "#FFFFFF";
  const tooltipText = theme === "dark" ? "#FFFFFF" : "#0F172A";
  const tooltipBorder = theme === "dark" ? "#DC2626" : "#E2E8F0";
  const gridStroke = theme === "dark" ? "#334155" : "#E2E8F0";
  const axisColor = theme === "dark" ? "#64748b" : "#94a3b8";

  return (
    <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
      {/* 24-Hour Emergency Dispatch Frequency */}
      <div className="lg:col-span-2 glass-panel bg-[var(--bg-surface)] p-6 rounded-2xl border border-[var(--border-main)]">
        <div className="flex items-center justify-between mb-6">
          <div>
            <h4 className="text-sm font-black text-[var(--text-main)] tracking-wide">
              {t("24-Hour Emergency Frequency", "၂၄ နာရီအတွင်း အရေးပေါ် ခေါ်ဆိုမှု ပုံစံ")}
            </h4>
            <p className="text-xs text-[var(--text-muted)] mt-0.5">
              {t("Real-time hourly dispatch pattern", "အချိန်နှင့်တပြေးညီ နာရီအလိုက် ခေါ်ဆိုမှု မှတ်တမ်း")}
            </p>
          </div>
          <span className="px-2.5 py-1 text-xs font-bold rounded-lg bg-red-500/10 text-red-500 border border-red-500/30">
            {t("Live Activity", "တိုက်ရိုက်လှုပ်ရှားမှု")}
          </span>
        </div>

        <div className="h-64 w-full">
          <ResponsiveContainer width="100%" height="100%">
            <AreaChart data={lineData} margin={{ top: 10, right: 10, left: -20, bottom: 0 }}>
              <defs>
                <linearGradient id="colorEmergency" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor="#DC2626" stopOpacity={0.5} />
                  <stop offset="95%" stopColor="#DC2626" stopOpacity={0.0} />
                </linearGradient>
              </defs>
              <CartesianGrid strokeDasharray="3 3" stroke={gridStroke} opacity={0.5} />
              <XAxis dataKey="time" stroke={axisColor} fontSize={11} />
              <YAxis stroke={axisColor} fontSize={11} allowDecimals={false} />
              <Tooltip
                contentStyle={{
                  backgroundColor: tooltipBg,
                  borderColor: tooltipBorder,
                  borderRadius: "12px",
                  color: tooltipText,
                  fontSize: "12px",
                  boxShadow: "0 10px 15px -3px rgba(0, 0, 0, 0.1)",
                }}
              />
              <Area
                type="monotone"
                dataKey="emergencies"
                stroke="#EF4444"
                strokeWidth={3}
                fillOpacity={1}
                fill="url(#colorEmergency)"
              />
            </AreaChart>
          </ResponsiveContainer>
        </div>
      </div>

      {/* Incident Types Breakdown */}
      <div className="glass-panel bg-[var(--bg-surface)] p-6 rounded-2xl border border-[var(--border-main)] flex flex-col justify-between">
        <div>
          <h4 className="text-sm font-black text-[var(--text-main)] tracking-wide">
            {t("Incident Categories", "အရေးပေါ် အမျိုးအစား ခွဲခြမ်းမှု")}
          </h4>
          <p className="text-xs text-[var(--text-muted)] mt-0.5">
            {t("Distribution by emergency type", "အရေးပေါ် အမျိုးအစားအလိုက် ရာခိုင်နှုန်း")}
          </p>
        </div>

        <div className="h-56 w-full flex items-center justify-center">
          <ResponsiveContainer width="100%" height="100%">
            <PieChart>
              <Pie
                data={pieData}
                innerRadius={55}
                outerRadius={80}
                paddingAngle={5}
                dataKey="value"
              >
                {pieData.map((entry, index) => (
                  <Cell key={`cell-${index}`} fill={entry.color} />
                ))}
              </Pie>
              <Tooltip
                contentStyle={{
                  backgroundColor: tooltipBg,
                  borderColor: tooltipBorder,
                  borderRadius: "8px",
                  color: tooltipText,
                  fontSize: "12px",
                }}
              />
            </PieChart>
          </ResponsiveContainer>
        </div>

        <div className="grid grid-cols-2 gap-2 mt-2">
          {pieData.map((item, idx) => (
            <div key={idx} className="flex items-center gap-2 text-xs">
              <span
                className="w-2.5 h-2.5 rounded-full"
                style={{ backgroundColor: item.color }}
              />
              <span className="text-[var(--text-main)] font-semibold truncate">{item.name}</span>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
