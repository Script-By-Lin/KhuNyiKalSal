"use client";

import React, { useState, useEffect } from "react";
import useSWR from "swr";
import { AppLayout } from "@/components/layout/AppLayout";
import { SuspendUserModal } from "@/components/users/SuspendUserModal";
import { api, fetcher } from "@/lib/api";
import { useTheme } from "@/lib/theme-context";
import {
  Users,
  Search,
  ShieldAlert,
  ShieldCheck,
  Ban,
  Clock,
  Unlock,
} from "lucide-react";

export default function UsersPage() {
  const { t } = useTheme();
  const [search, setSearch] = useState("");
  const [statusFilter, setStatusFilter] = useState("all");
  const [selectedUser, setSelectedUser] = useState<any>(null);
  const [isSuspendModalOpen, setIsSuspendModalOpen] = useState(false);
  const [actionLoading, setActionLoading] = useState<string | null>(null);

  // Live SWR polling
  const { data: users, mutate } = useSWR(
    `/admin/users?limit=100${statusFilter !== "all" ? `&status_filter=${statusFilter}` : ""}`,
    fetcher,
    { refreshInterval: 6000 }
  );

  // Live client-side seconds countdown ticker
  const [now, setNow] = useState<number | null>(null);
  useEffect(() => {
    setNow(Date.now());
    const timer = setInterval(() => setNow(Date.now()), 1000);
    return () => clearInterval(timer);
  }, []);

  const handleUnsuspend = async (userId: string) => {
    setActionLoading(userId);
    try {
      await api.post(`/admin/users/${userId}/unsuspend`);
      mutate();
    } catch (err: any) {
      alert(err.message || "Failed to unsuspend user.");
    } finally {
      setActionLoading(null);
    }
  };

  const formatCountdown = (suspendedUntilStr: string | null) => {
    if (!suspendedUntilStr || !now) return null;
    const target = new Date(suspendedUntilStr).getTime();
    const diffSeconds = Math.max(0, Math.floor((target - now) / 1000));
    if (diffSeconds <= 0) return "Expired (Reactivating)";

    const days = Math.floor(diffSeconds / 86400);
    const hours = Math.floor((diffSeconds % 86400) / 3600);
    const minutes = Math.floor((diffSeconds % 3600) / 60);
    const seconds = diffSeconds % 60;

    if (days > 365) return "Permanent (100 Years)";
    if (days > 0) return `${days}d ${hours.toString().padStart(2, "0")}h ${minutes.toString().padStart(2, "0")}m`;
    return `${hours.toString().padStart(2, "0")}:${minutes.toString().padStart(2, "0")}:${seconds.toString().padStart(2, "0")}`;
  };

  const cleanPhone = (phone: string | null | undefined) => {
    if (!phone) return null;
    const p = String(phone).trim();
    if (
      p.startsWith("gAAAAA") ||
      p.length > 20 ||
      p.includes("=") ||
      p.includes("_") ||
      p.includes("/")
    ) {
      return null;
    }
    return p;
  };

  const filteredUsers = (users || []).filter((u: any) => {
    if (!search.trim()) return true;
    const query = search.toLowerCase();
    const phone = cleanPhone(u.phone_number) || "";
    return (
      (u.email || "").toLowerCase().includes(query) ||
      (u.full_name || "").toLowerCase().includes(query) ||
      phone.toLowerCase().includes(query)
    );
  });

  return (
    <AppLayout title={t("User & Suspension Management", "သုံးစွဲသူနှင့် ပိတ်ပင်မှု စီမံခန့်ခွဲရေး")}>
      <div className="space-y-6">
        {/* Filter and Search Bar */}
        <div className="flex flex-col md:flex-row items-start md:items-center justify-between gap-4 p-4 glass-panel bg-[var(--bg-surface)] rounded-2xl border border-[var(--border-main)]">
          <div className="flex flex-wrap items-center gap-2">
            {[
              { id: "all", label: t("All Accounts", "အားလုံး") },
              { id: "active", label: t("Active Only", "အသုံးပြုနေဆဲ") },
              { id: "suspended", label: t("Suspended (1d / 10d)", "ယာယီပိတ်ပင်ထားသူ") },
              { id: "banned", label: t("Banned (100y)", "ရာသက်ပန်ပိတ်ပင်သူ") },
            ].map((tab) => (
              <button
                key={tab.id}
                onClick={() => setStatusFilter(tab.id)}
                className={`px-3.5 py-1.5 rounded-xl text-xs font-bold border transition-all cursor-pointer ${
                  statusFilter === tab.id
                    ? "bg-red-600 text-white border-red-500 shadow-md shadow-red-600/30"
                    : "bg-[var(--bg-subtle)] text-[var(--text-muted)] border-[var(--border-main)] hover:text-[var(--text-main)]"
                }`}
              >
                {tab.label}
              </button>
            ))}
          </div>

          <div className="w-full md:w-72 relative">
            <Search className="w-4 h-4 text-[var(--text-subtle)] absolute left-3.5 top-1/2 -translate-y-1/2" />
            <input
              type="text"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder={t("Search by email or phone...", "အီးမေးလ် သို့မဟုတ် ဖုန်းဖြင့်ရှာပါ...")}
              className="w-full panel-input rounded-xl py-2 pl-10 pr-4 text-xs placeholder:text-[var(--text-subtle)] transition-colors"
            />
          </div>
        </div>

        {/* Users & Suspension Table */}
        <div className="glass-panel bg-[var(--bg-surface)] rounded-2xl border border-[var(--border-main)] overflow-hidden shadow-sm">
          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs text-[var(--text-main)]">
              <thead className="bg-[var(--bg-subtle)] text-[var(--text-muted)] font-extrabold uppercase tracking-wider border-b border-[var(--border-main)]">
                <tr>
                  <th className="py-3.5 px-5">User</th>
                  <th className="py-3.5 px-4">Role</th>
                  <th className="py-3.5 px-4">Status & Penalty Tier</th>
                  <th className="py-3.5 px-4">Live Remaining Time</th>
                  <th className="py-3.5 px-4">Offense Reason</th>
                  <th className="py-3.5 px-5 text-right">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-[var(--border-main)]">
                {filteredUsers.length === 0 ? (
                  <tr>
                    <td colSpan={6} className="py-12 text-center text-[var(--text-muted)]">
                      No accounts matched the filter criteria.
                    </td>
                  </tr>
                ) : (
                  filteredUsers.map((u: any) => {
                    const isSuspended = u.is_suspended;
                    const countdown = isSuspended
                      ? formatCountdown(u.suspended_until)
                      : null;
                    const phone = cleanPhone(u.phone_number);

                    return (
                      <tr
                        key={u.account_id}
                        className="hover:bg-[var(--table-hover)] transition-colors"
                      >
                        <td className="py-4 px-5">
                          <div>
                            <p className="font-bold text-[var(--text-main)] text-sm">
                              {u.full_name || "User"}
                            </p>
                            <p className="text-[var(--text-muted)] font-mono text-[11px]">
                              {u.email}
                            </p>
                            {phone && (
                              <p className="text-[var(--text-muted)] text-[11px] mt-0.5">
                                📞 {phone}
                              </p>
                            )}
                          </div>
                        </td>
                        <td className="py-4 px-4">
                          <span className="px-2 py-0.5 rounded text-[10px] font-bold bg-[var(--bg-subtle)] border border-[var(--border-main)] text-[var(--text-muted)] uppercase">
                            {u.role}
                          </span>
                        </td>
                        <td className="py-4 px-4">
                          {isSuspended ? (
                            <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg bg-red-500/15 text-red-600 font-bold text-[11px] border border-red-500/30">
                              <ShieldAlert className="w-3.5 h-3.5 text-red-600" />
                              {u.status_label || "Suspended"}
                            </span>
                          ) : (
                            <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg bg-emerald-500/15 text-emerald-600 font-bold text-[11px] border border-emerald-500/30">
                              <ShieldCheck className="w-3.5 h-3.5 text-emerald-600" />
                              Active
                            </span>
                          )}
                        </td>
                        <td className="py-4 px-4">
                          {isSuspended && countdown ? (
                            <span className="inline-flex items-center gap-1.5 font-mono text-xs font-bold text-amber-600 bg-amber-500/10 px-2.5 py-1 rounded-lg border border-amber-500/30">
                              <Clock className="w-3 h-3 text-amber-600 animate-spin" />
                              {countdown}
                            </span>
                          ) : (
                            <span className="text-[var(--text-subtle)] text-[11px]">—</span>
                          )}
                        </td>
                        <td className="py-4 px-4 max-w-xs truncate text-[11px] text-[var(--text-muted)]">
                          {u.suspension_reason || "No penalty recorded"}
                        </td>
                        <td className="py-4 px-5 text-right space-x-2">
                          {isSuspended ? (
                            <button
                              onClick={() => handleUnsuspend(u.account_id)}
                              disabled={actionLoading === u.account_id}
                              className="px-3 py-1.5 rounded-lg bg-emerald-600 hover:bg-emerald-500 text-white font-bold text-xs shadow-md shadow-emerald-600/30 transition-all inline-flex items-center gap-1 cursor-pointer disabled:opacity-50"
                            >
                              <Unlock className="w-3.5 h-3.5" />
                              <span>
                                {actionLoading === u.account_id
                                  ? "Lifting..."
                                  : t("Deactivate", "ပယ်ဖျက်မည်")}
                              </span>
                            </button>
                          ) : (
                            <button
                              onClick={() => {
                                setSelectedUser(u);
                                setIsSuspendModalOpen(true);
                              }}
                              className="px-3 py-1.5 rounded-lg bg-red-500/10 hover:bg-red-600 text-red-600 hover:text-white border border-red-500/30 font-bold text-xs transition-all inline-flex items-center gap-1 cursor-pointer"
                            >
                              <Ban className="w-3.5 h-3.5" />
                              <span>{t("Suspend", "ပိတ်ပင်မည်")}</span>
                            </button>
                          )}
                        </td>
                      </tr>
                    );
                  })
                )}
              </tbody>
            </table>
          </div>
        </div>

        {/* Suspend Modal */}
        <SuspendUserModal
          user={selectedUser}
          isOpen={isSuspendModalOpen}
          onClose={() => {
            setIsSuspendModalOpen(false);
            setSelectedUser(null);
          }}
          onSuccess={() => mutate()}
        />
      </div>
    </AppLayout>
  );
}
