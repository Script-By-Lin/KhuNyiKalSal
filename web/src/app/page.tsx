"use client";

import React from "react";
import useSWR from "swr";
import { AppLayout } from "@/components/layout/AppLayout";
import { StatCard } from "@/components/dashboard/StatCard";
import { EmergencyCharts } from "@/components/dashboard/EmergencyCharts";
import { LiveActivityFeed } from "@/components/dashboard/LiveActivityFeed";
import { fetcher } from "@/lib/api";
import { useTheme } from "@/lib/theme-context";
import {
  AlertCircle,
  ShieldCheck,
  Building2,
  Users,
  RefreshCw,
} from "lucide-react";

export default function DashboardPage() {
  const { t } = useTheme();

  // Live SWR polling every 5 seconds for high-performance cached updates
  const { data: emergencies, mutate: mutateEmergencies } = useSWR(
    "/admin/emergencies?limit=100",
    fetcher,
    { refreshInterval: 5000 }
  );

  const { data: orgs } = useSWR("/admin/organizations?limit=100", fetcher, {
    refreshInterval: 15000,
  });

  const { data: users } = useSWR("/admin/users?limit=100", fetcher, {
    refreshInterval: 15000,
  });

  const activeEmergencies = (emergencies || []).filter(
    (e: any) => e.status === "pending" || e.status === "accepted"
  );
  const resolvedEmergencies = (emergencies || []).filter(
    (e: any) => e.status === "completed"
  );
  const totalOrgs = (orgs || []).length;
  const totalUsers = (users || []).length;

  return (
    <AppLayout title={t("Tactical Command Overview", "အရေးပေါ် စစ်ဆင်ရေး ခြုံငုံသုံးသပ်ချက်")}>
      <div className="space-y-8">
        {/* KPI Stat Cards */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
          <StatCard
            title={t("Active SOS Alerts", "လက်ရှိ အရေးပေါ် ခေါ်ဆိုမှု")}
            value={activeEmergencies.length}
            subtitle={t("Awaiting / in progress", "တုံ့ပြန်ဆောင်ရွက်ဆဲ")}
            icon={AlertCircle}
            color="red"
            badge="LIVE RADAR"
          />
          <StatCard
            title={t("Resolved Missions", "အောင်မြင်စွာ ကယ်ဆယ်ပြီး")}
            value={resolvedEmergencies.length}
            subtitle={t("Completed rescues", "ကယ်ဆယ်ပြီးစီးမှု")}
            icon={ShieldCheck}
            color="emerald"
          />
          <StatCard
            title={t("Verified Rescue Units", "ကယ်ဆယ်ရေး အဖွဲ့အစည်းများ")}
            value={totalOrgs}
            subtitle={t("Active command stations", "စခန်းပေါင်း")}
            icon={Building2}
            color="blue"
          />
          <StatCard
            title={t("Citizens & Volunteers", "သုံးစွဲသူနှင့် စေတနာ့ဝန်ထမ်း")}
            value={totalUsers}
            subtitle={t("Registered community", "စုစုပေါင်း အကောင့်များ")}
            icon={Users}
            color="amber"
          />
        </div>

        {/* Data Visualization Charts */}
        <EmergencyCharts emergencies={emergencies || []} />

        {/* Live Incoming Incidents Stream */}
        <LiveActivityFeed emergencies={emergencies || []} />
      </div>
    </AppLayout>
  );
}
