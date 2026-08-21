"use client";

import React, { useState } from "react";
import useSWR from "swr";
import { AppLayout } from "@/components/layout/AppLayout";
import { fetcher } from "@/lib/api";
import { useTheme } from "@/lib/theme-context";

export default function BloodDonationsPage() {
  const { t } = useTheme();
  const [filterGroup, setFilterGroup] = useState("all");

  const { data: requests } = useSWR("/blood-donations/all", fetcher, {
    refreshInterval: 10000,
  });

  const bloodGroups = ["all", "A+", "A-", "B+", "B-", "O+", "O-", "AB+", "AB-"];

  const filteredRequests = (requests || []).filter((r: any) => {
    if (filterGroup === "all") return true;
    return (r.blood_type || "").toUpperCase() === filterGroup.toUpperCase();
  });

  const cleanPhone = (phone: string | null | undefined) => {
    if (!phone) return "—";
    const p = String(phone).trim();
    if (
      p.startsWith("gAAAAA") ||
      p.length > 20 ||
      p.includes("=") ||
      p.includes("_") ||
      p.includes("/")
    ) {
      return "—";
    }
    return p;
  };

  return (
    <AppLayout title={t("Blood Donation Registry", "သွေးလှူဒါန်းမှု မှတ်တမ်းများ")}>
      <div className="space-y-6">
        {/* Blood Group Chips */}
        <div className="flex flex-wrap items-center gap-2 p-4 glass-panel bg-[var(--bg-surface)] rounded-2xl border border-[var(--border-main)]">
          <span className="text-xs font-bold text-[var(--text-muted)] uppercase mr-2">
            Blood Type Filter:
          </span>
          {bloodGroups.map((group) => (
            <button
              key={group}
              onClick={() => setFilterGroup(group)}
              className={`px-3 py-1 rounded-xl text-xs font-bold border transition-all cursor-pointer ${
                filterGroup === group
                  ? "bg-red-600 text-white border-red-500 shadow-md shadow-red-600/30"
                  : "bg-[var(--bg-subtle)] text-[var(--text-muted)] border-[var(--border-main)] hover:text-[var(--text-main)]"
              }`}
            >
              {group === "all" ? "All Types" : group}
            </button>
          ))}
        </div>

        {/* Requests Table */}
        <div className="glass-panel bg-[var(--bg-surface)] rounded-2xl border border-[var(--border-main)] overflow-hidden shadow-sm">
          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs text-[var(--text-main)]">
              <thead className="bg-[var(--bg-subtle)] text-[var(--text-muted)] font-extrabold uppercase tracking-wider border-b border-[var(--border-main)]">
                <tr>
                  <th className="py-3.5 px-5">Blood Group</th>
                  <th className="py-3.5 px-4">Requester / Donor</th>
                  <th className="py-3.5 px-4">Contact</th>
                  <th className="py-3.5 px-4">Hospital / Location</th>
                  <th className="py-3.5 px-4">Units Needed</th>
                  <th className="py-3.5 px-5 text-right">Status</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-[var(--border-main)]">
                {filteredRequests.length === 0 ? (
                  <tr>
                    <td colSpan={6} className="py-12 text-center text-[var(--text-muted)]">
                      No blood requests or pledges found.
                    </td>
                  </tr>
                ) : (
                  filteredRequests.map((r: any) => (
                    <tr key={r.id} className="hover:bg-[var(--table-hover)] transition-colors">
                      <td className="py-4 px-5">
                        <div className="flex items-center gap-2">
                          <div className="w-8 h-8 rounded-lg bg-red-500/15 border border-red-500/30 flex items-center justify-center font-black text-red-600">
                            {r.blood_type}
                          </div>
                        </div>
                      </td>
                      <td className="py-4 px-4 font-bold text-[var(--text-main)]">
                        {r.patient_name || r.donor_name || "Emergency Patient"}
                      </td>
                      <td className="py-4 px-4 font-mono text-[var(--text-muted)]">
                        📞 {cleanPhone(r.donor_phone || r.contact_phone)}
                      </td>
                      <td className="py-4 px-4 text-[var(--text-muted)]">
                        {r.hospital_name || "General Hospital, Yangon"}
                      </td>
                      <td className="py-4 px-4 font-bold text-[var(--text-main)]">
                        {r.units_needed || 1} Unit(s)
                      </td>
                      <td className="py-4 px-5 text-right">
                        <span
                          className={`px-2.5 py-1 rounded-lg text-[10px] font-bold uppercase border ${
                            r.status === "completed"
                              ? "bg-emerald-500/15 text-emerald-600 border-emerald-500/40"
                              : r.status === "accepted"
                              ? "bg-blue-500/15 text-blue-600 border-blue-500/40"
                              : "bg-red-500/15 text-red-600 border-red-500/40 animate-pulse"
                          }`}
                        >
                          {r.status || "Pending"}
                        </span>
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </AppLayout>
  );
}
