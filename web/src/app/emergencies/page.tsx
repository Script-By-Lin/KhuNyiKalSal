"use client";

import React, { useState, useMemo } from "react";
import useSWR from "swr";
import { AppLayout } from "@/components/layout/AppLayout";
import { api, fetcher } from "@/lib/api";
import { useTheme } from "@/lib/theme-context";
import {
  AlertTriangle,
  Flame,
  HeartPulse,
  Car,
  CloudLightning,
  Search,
  Filter,
  ShieldAlert,
  Clock,
  Building2,
  X,
  XCircle,
  Eye,
  CheckCircle2,
  Radio,
} from "lucide-react";

export default function EmergenciesPage() {
  const { t } = useTheme();
  const [search, setSearch] = useState("");
  const [statusFilter, setStatusFilter] = useState("all");
  const [typeFilter, setTypeFilter] = useState("all");
  const [abuseFilter, setAbuseFilter] = useState(false);
  const [selectedIncident, setSelectedIncident] = useState<any>(null);
  const [cancelLoading, setCancelLoading] = useState<string | null>(null);

  // Live SWR polling every 4 seconds
  const { data: emergencies, mutate } = useSWR(
    "/admin/emergencies?limit=150",
    fetcher,
    { refreshInterval: 4000 }
  );

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
        <span className="px-2.5 py-1 text-[10px] font-extrabold uppercase rounded-lg bg-red-500/15 text-red-600 border border-red-500/40 animate-pulse inline-flex items-center gap-1">
          <span className="w-1.5 h-1.5 rounded-full bg-red-600 animate-ping"></span>
          Pending SOS
        </span>
      );
    } else if (s === "accepted") {
      return (
        <span className="px-2.5 py-1 text-[10px] font-extrabold uppercase rounded-lg bg-blue-500/15 text-blue-600 border border-blue-500/40 inline-flex items-center gap-1">
          <Radio className="w-3 h-3 text-blue-600 animate-spin" />
          En Route
        </span>
      );
    } else if (s === "completed") {
      return (
        <span className="px-2.5 py-1 text-[10px] font-extrabold uppercase rounded-lg bg-emerald-500/15 text-emerald-600 border border-emerald-500/40 inline-flex items-center gap-1">
          <CheckCircle2 className="w-3 h-3 text-emerald-600" />
          Resolved
        </span>
      );
    } else if (s === "cancelled") {
      return (
        <span className="px-2.5 py-1 text-[10px] font-extrabold uppercase rounded-lg bg-[var(--bg-subtle)] text-[var(--text-muted)] border border-[var(--border-main)] inline-flex items-center gap-1">
          <XCircle className="w-3 h-3 text-[var(--text-subtle)]" />
          Cancelled
        </span>
      );
    }
    return (
      <span className="px-2.5 py-1 text-[10px] font-extrabold uppercase rounded-lg bg-[var(--bg-subtle)] text-[var(--text-muted)] border border-[var(--border-main)]">
        {status}
      </span>
    );
  };

  const handleCancelEmergency = async (id: string) => {
    if (!confirm("Are you sure you want to forcefully cancel this emergency alert?")) return;
    setCancelLoading(id);
    try {
      await api.post(`/admin/emergencies/${id}/cancel`);
      mutate();
      if (selectedIncident?.emergency_id === id) {
        setSelectedIncident(null);
      }
    } catch (err: any) {
      alert(err.message || "Failed to cancel emergency.");
    } finally {
      setCancelLoading(null);
    }
  };

  const filteredIncidents = useMemo(() => {
    return (emergencies || []).filter((e: any) => {
      // Status Filter
      if (statusFilter !== "all" && (e.status || "").toLowerCase() !== statusFilter.toLowerCase()) {
        return false;
      }
      // Type Filter
      if (typeFilter !== "all" && (e.type || "").toLowerCase() !== typeFilter.toLowerCase()) {
        return false;
      }
      // Abuse Filter
      if (abuseFilter && !e.is_suspected_abuse) {
        return false;
      }
      // Search Term
      if (search.trim()) {
        const q = search.toLowerCase();
        return (
          (e.user_name || "").toLowerCase().includes(q) ||
          (e.type || "").toLowerCase().includes(q) ||
          (e.assigned_org_name || "").toLowerCase().includes(q) ||
          (e.emergency_id || "").toLowerCase().includes(q)
        );
      }
      return true;
    });
  }, [emergencies, statusFilter, typeFilter, abuseFilter, search]);

  const pendingCount = (emergencies || []).filter((e: any) => (e.status || "").toLowerCase() === "pending").length;
  const activeCount = (emergencies || []).filter((e: any) => (e.status || "").toLowerCase() === "accepted").length;
  const completedCount = (emergencies || []).filter((e: any) => (e.status || "").toLowerCase() === "completed").length;
  const abuseCount = (emergencies || []).filter((e: any) => e.is_suspected_abuse).length;

  return (
    <AppLayout title={t("Emergency Cases & Dispatch Command", "အရေးပေါ်ဖြစ်စဉ်များနှင့် စေလွှတ်မှု စီမံခန့်ခွဲရေး")}>
      <div className="space-y-6">
        {/* KPI Counter Cards */}
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
          <div className="glass-panel bg-[var(--bg-surface)] p-5 rounded-2xl border border-red-500/30 flex items-center justify-between shadow-sm">
            <div>
              <p className="text-[11px] font-extrabold text-red-600 uppercase tracking-wider">
                {t("Pending SOS", "အရေးပေါ် စောင့်ဆိုင်းဆဲ")}
              </p>
              <h3 className="text-3xl font-black text-[var(--text-main)] mt-1">{pendingCount}</h3>
            </div>
            <div className="p-3 rounded-xl bg-red-500/15 text-red-600 border border-red-500/30">
              <AlertTriangle className="w-5 h-5 animate-pulse" />
            </div>
          </div>

          <div className="glass-panel bg-[var(--bg-surface)] p-5 rounded-2xl border border-blue-500/30 flex items-center justify-between shadow-sm">
            <div>
              <p className="text-[11px] font-extrabold text-blue-600 uppercase tracking-wider">
                {t("Dispatched / En Route", "ထွက်ခွာ ကယ်ဆယ်ဆဲ")}
              </p>
              <h3 className="text-3xl font-black text-[var(--text-main)] mt-1">{activeCount}</h3>
            </div>
            <div className="p-3 rounded-xl bg-blue-500/15 text-blue-600 border border-blue-500/30">
              <Radio className="w-5 h-5" />
            </div>
          </div>

          <div className="glass-panel bg-[var(--bg-surface)] p-5 rounded-2xl border border-emerald-500/30 flex items-center justify-between shadow-sm">
            <div>
              <p className="text-[11px] font-extrabold text-emerald-600 uppercase tracking-wider">
                {t("Resolved Rescues", "အောင်မြင်စွာ ကယ်ဆယ်ပြီး")}
              </p>
              <h3 className="text-3xl font-black text-[var(--text-main)] mt-1">{completedCount}</h3>
            </div>
            <div className="p-3 rounded-xl bg-emerald-500/15 text-emerald-600 border border-emerald-500/30">
              <CheckCircle2 className="w-5 h-5" />
            </div>
          </div>

          <div className="glass-panel bg-[var(--bg-surface)] p-5 rounded-2xl border border-amber-500/30 flex items-center justify-between shadow-sm">
            <div>
              <p className="text-[11px] font-extrabold text-amber-600 uppercase tracking-wider">
                {t("Abuse Suspicions", "မသင်္ကာဖွယ် ခေါ်ဆိုမှုများ")}
              </p>
              <h3 className="text-3xl font-black text-[var(--text-main)] mt-1">{abuseCount}</h3>
            </div>
            <div className="p-3 rounded-xl bg-amber-500/15 text-amber-600 border border-amber-500/30">
              <ShieldAlert className="w-5 h-5" />
            </div>
          </div>
        </div>

        {/* Multi-Dimensional Filter Bar */}
        <div className="p-5 glass-panel bg-[var(--bg-surface)] rounded-2xl border border-[var(--border-main)] space-y-4 shadow-sm">
          {/* Status Filter Tabs */}
          <div className="flex flex-wrap items-center justify-between gap-4">
            <div className="flex flex-wrap items-center gap-2">
              <span className="text-xs font-extrabold text-[var(--text-muted)] uppercase mr-1 flex items-center gap-1.5">
                <Filter className="w-3.5 h-3.5 text-red-500" />
                Status:
              </span>
              {[
                { id: "all", label: "All Cases" },
                { id: "pending", label: "Pending Only" },
                { id: "accepted", label: "En Route / Dispatched" },
                { id: "completed", label: "Resolved" },
                { id: "cancelled", label: "Cancelled" },
              ].map((tab) => (
                <button
                  key={tab.id}
                  onClick={() => setStatusFilter(tab.id)}
                  className={`px-3 py-1.5 rounded-xl text-xs font-bold border transition-all cursor-pointer ${
                    statusFilter === tab.id
                      ? "bg-red-600 text-white border-red-500 shadow-md shadow-red-600/30"
                      : "bg-[var(--bg-subtle)] text-[var(--text-muted)] border-[var(--border-main)] hover:text-[var(--text-main)]"
                  }`}
                >
                  {tab.label}
                </button>
              ))}
            </div>

            {/* Search Input */}
            <div className="w-full sm:w-72 relative">
              <Search className="w-4 h-4 text-[var(--text-subtle)] absolute left-3.5 top-1/2 -translate-y-1/2" />
              <input
                type="text"
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                placeholder={t("Search by caller or ID...", "ခေါ်ဆိုသူ သို့မဟုတ် နံပါတ်ဖြင့်ရှာပါ...")}
                className="w-full panel-input rounded-xl py-2 pl-10 pr-4 text-xs placeholder:text-[var(--text-subtle)] transition-colors"
              />
            </div>
          </div>

          {/* Type Filter & Abuse Toggle */}
          <div className="flex flex-wrap items-center justify-between gap-4 pt-3 border-t border-[var(--border-main)]">
            <div className="flex items-center gap-3">
              <label htmlFor="emergencyTypeSelect" className="text-xs font-extrabold text-[var(--text-muted)] uppercase flex items-center gap-1.5">
                <span>Incident Type:</span>
              </label>
              <div className="relative">
                <select
                  id="emergencyTypeSelect"
                  value={typeFilter}
                  onChange={(e) => setTypeFilter(e.target.value)}
                  className="panel-input font-bold text-xs rounded-xl py-2 pl-3 pr-8 appearance-none bg-[var(--bg-subtle)] border border-[var(--border-main)] text-[var(--text-main)] cursor-pointer focus:outline-none focus:border-red-500 transition-colors shadow-sm"
                >
                  <option value="all">🚨 All Incident Types (အားလုံး)</option>
                  <option value="medical">🩺 Medical / Health (ဆေးဝါး)</option>
                  <option value="fire">🔥 Fire & Rescue (မီးသတ်)</option>
                  <option value="accident">🚗 Traffic Accident (ယာဉ်မတော်တဆ)</option>
                  <option value="natural_disaster">🌊 Natural Disaster (သဘာဝဘေး)</option>
                </select>
                <div className="pointer-events-none absolute right-2.5 top-1/2 -translate-y-1/2 text-[var(--text-subtle)]">
                  ▼
                </div>
              </div>
            </div>

            <button
              onClick={() => setAbuseFilter(!abuseFilter)}
              className={`px-3.5 py-1.5 rounded-xl text-xs font-extrabold border transition-all flex items-center gap-1.5 cursor-pointer ${
                abuseFilter
                  ? "bg-amber-500 text-white border-amber-600 shadow-md shadow-amber-500/30"
                  : "bg-[var(--bg-subtle)] text-amber-600 border-[var(--border-main)] hover:bg-amber-500/10"
              }`}
            >
              <ShieldAlert className="w-3.5 h-3.5" />
              <span>{abuseFilter ? "Showing Abuse Flagged Only" : "Filter Abuse Suspicions"}</span>
            </button>
          </div>
        </div>

        {/* Emergency Cases Table */}
        <div className="glass-panel bg-[var(--bg-surface)] rounded-2xl border border-[var(--border-main)] overflow-hidden shadow-sm">
          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs text-[var(--text-main)]">
              <thead className="bg-[var(--bg-subtle)] text-[var(--text-muted)] font-extrabold uppercase tracking-wider border-b border-[var(--border-main)] text-[11px]">
                <tr>
                  <th className="py-3 px-4 w-[22%]">Incident & Type</th>
                  <th className="py-3 px-4 w-[18%]">Caller / Patient</th>
                  <th className="py-3 px-4 w-[18%]">Assigned Station</th>
                  <th className="py-3 px-3 w-[12%]">Status</th>
                  <th className="py-3 px-3 w-[13%]">24h Frequency</th>
                  <th className="py-3 px-3 w-[8%]">Time</th>
                  <th className="py-3 px-4 w-[9%] text-right">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-[var(--border-main)]">
                {filteredIncidents.length === 0 ? (
                  <tr>
                    <td colSpan={7} className="py-10 text-center text-[var(--text-muted)]">
                      No emergency cases matched the filter criteria.
                    </td>
                  </tr>
                ) : (
                  filteredIncidents.map((e: any) => {
                    const isPending = (e.status || "").toLowerCase() === "pending";

                    return (
                      <tr key={e.emergency_id} className="hover:bg-[var(--table-hover)] transition-colors">
                        <td className="py-2.5 px-4">
                          <div className="flex items-center gap-2.5">
                            <div className="p-2 rounded-xl bg-[var(--bg-subtle)] border border-[var(--border-main)] shrink-0">
                              {getTypeIcon(e.type)}
                            </div>
                            <div className="min-w-0">
                              <p className="font-extrabold text-[var(--text-main)] text-xs uppercase tracking-wide truncate">
                                {e.type || "Emergency"}
                              </p>
                              <p className="text-[10px] text-[var(--text-subtle)] font-mono">
                                #{e.emergency_id.substring(0, 8)}
                              </p>
                            </div>
                          </div>
                        </td>
                        <td className="py-2.5 px-4">
                          <div className="min-w-0">
                            <p className="font-bold text-[var(--text-main)] text-xs truncate">
                              {e.user_name || "Citizen Caller"}
                            </p>
                            {e.blood_type && e.blood_type !== "Unknown" ? (
                              <span className="text-[10px] text-red-600 font-extrabold">
                                Blood: {e.blood_type}
                              </span>
                            ) : (
                              <span className="text-[10px] text-[var(--text-subtle)]">Citizen</span>
                            )}
                          </div>
                        </td>
                        <td className="py-2.5 px-4">
                          <span className="inline-flex items-center gap-1.5 font-semibold text-[var(--text-muted)] text-xs truncate max-w-[170px]">
                            <Building2 className="w-3.5 h-3.5 text-[var(--text-subtle)] shrink-0" />
                            <span className="truncate">{e.assigned_org_name || "Unassigned"}</span>
                          </span>
                        </td>
                        <td className="py-2.5 px-3">{getStatusBadge(e.status)}</td>
                        <td className="py-2.5 px-3">
                          {e.is_suspected_abuse ? (
                            <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-extrabold bg-amber-500/15 text-amber-600 border border-amber-500/30 whitespace-nowrap">
                              <ShieldAlert className="w-3 h-3 shrink-0" />
                              {e.sos_count_24h} calls (Abuse)
                            </span>
                          ) : (
                            <span className="text-[var(--text-muted)] font-mono text-[11px]">
                              {e.sos_count_24h || 1} call(s)
                            </span>
                          )}
                        </td>
                        <td className="py-2.5 px-3 text-[var(--text-muted)] font-mono text-[11px] whitespace-nowrap">
                          {e.created_at ? new Date(e.created_at).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" }) : "—"}
                        </td>
                        <td className="py-2.5 px-4 text-right">
                          <div className="flex items-center justify-end gap-1.5">
                            <button
                              onClick={() => setSelectedIncident(e)}
                              className="px-2 py-1 rounded-lg bg-[var(--bg-subtle)] hover:bg-[var(--bg-card)] border border-[var(--border-main)] text-[var(--text-main)] text-[11px] font-bold transition-all inline-flex items-center gap-1 cursor-pointer whitespace-nowrap"
                            >
                              <Eye className="w-3 h-3" />
                              <span>Details</span>
                            </button>

                            {isPending && (
                              <button
                                onClick={() => handleCancelEmergency(e.emergency_id)}
                                disabled={cancelLoading === e.emergency_id}
                                className="px-2 py-1 rounded-lg bg-red-500/15 hover:bg-red-600 text-red-600 hover:text-white border border-red-500/30 text-[11px] font-bold transition-all inline-flex items-center gap-1 cursor-pointer disabled:opacity-50 whitespace-nowrap"
                              >
                                <XCircle className="w-3 h-3" />
                                <span>{cancelLoading === e.emergency_id ? "..." : "Cancel SOS"}</span>
                              </button>
                            )}
                          </div>
                        </td>
                      </tr>
                    );
                  })
                )}
              </tbody>
            </table>
          </div>
        </div>

        {/* Incident Details Modal */}
        {selectedIncident && (
          <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm p-4">
            <div className="w-full max-w-lg glass-panel bg-[var(--bg-surface)] border border-[var(--border-main)] rounded-2xl p-6 shadow-2xl text-[var(--text-main)]">
              <div className="flex items-center justify-between pb-4 border-b border-[var(--border-main)]">
                <div className="flex items-center gap-3">
                  <div className="p-2 rounded-xl bg-red-500/15 text-red-600 border border-red-500/30">
                    {getTypeIcon(selectedIncident.type)}
                  </div>
                  <div>
                    <h3 className="font-extrabold text-base text-[var(--text-main)] uppercase">
                      {selectedIncident.type} Emergency Details
                    </h3>
                    <p className="text-[10px] text-[var(--text-subtle)] font-mono">
                      #{selectedIncident.emergency_id}
                    </p>
                  </div>
                </div>
                <button
                  onClick={() => setSelectedIncident(null)}
                  className="text-[var(--text-muted)] hover:text-[var(--text-main)] p-1 rounded-lg"
                >
                  <X className="w-5 h-5" />
                </button>
              </div>

              <div className="mt-4 space-y-3 text-xs">
                <div className="grid grid-cols-2 gap-3 p-3 rounded-xl bg-[var(--bg-subtle)] border border-[var(--border-main)]">
                  <div>
                    <p className="text-[10px] font-bold text-[var(--text-subtle)] uppercase">Caller Name</p>
                    <p className="font-extrabold text-sm text-[var(--text-main)] mt-0.5">{selectedIncident.user_name}</p>
                  </div>
                  <div>
                    <p className="text-[10px] font-bold text-[var(--text-subtle)] uppercase">Blood Group</p>
                    <p className="font-extrabold text-sm text-red-600 mt-0.5">{selectedIncident.blood_type || "None"}</p>
                  </div>
                </div>

                <div className="p-3 rounded-xl bg-[var(--bg-subtle)] border border-[var(--border-main)]">
                  <p className="text-[10px] font-bold text-[var(--text-subtle)] uppercase">Medical Conditions</p>
                  <p className="font-medium text-[var(--text-main)] mt-1">{selectedIncident.medical_conditions || "None declared"}</p>
                </div>

                <div className="grid grid-cols-2 gap-3 p-3 rounded-xl bg-[var(--bg-subtle)] border border-[var(--border-main)]">
                  <div>
                    <p className="text-[10px] font-bold text-[var(--text-subtle)] uppercase">Assigned Unit</p>
                    <p className="font-extrabold text-[var(--text-main)] mt-0.5">{selectedIncident.assigned_org_name || "Unassigned"}</p>
                  </div>
                  <div>
                    <p className="text-[10px] font-bold text-[var(--text-subtle)] uppercase">24h SOS Frequency</p>
                    <p className="font-extrabold text-amber-600 mt-0.5">{selectedIncident.sos_count_24h} alert(s)</p>
                  </div>
                </div>

                {selectedIncident.is_suspected_abuse && (
                  <div className="p-3 rounded-xl bg-amber-500/15 border border-amber-500/40 text-amber-600 font-bold">
                    ⚠️ {selectedIncident.abuse_flag_reason || "Suspected spam/abuse call."}
                  </div>
                )}
              </div>

              <div className="flex items-center gap-3 pt-4 border-t border-[var(--border-main)] mt-5">
                <button
                  type="button"
                  onClick={() => setSelectedIncident(null)}
                  className="flex-1 py-2.5 font-bold text-[var(--text-muted)] bg-[var(--bg-subtle)] border border-[var(--border-main)] rounded-xl"
                >
                  Close
                </button>
                {(selectedIncident.status || "").toLowerCase() === "pending" && (
                  <button
                    type="button"
                    onClick={() => handleCancelEmergency(selectedIncident.emergency_id)}
                    className="flex-1 py-2.5 font-bold text-white bg-red-600 hover:bg-red-500 rounded-xl shadow-lg shadow-red-600/30"
                  >
                    Force Cancel SOS
                  </button>
                )}
              </div>
            </div>
          </div>
        )}
      </div>
    </AppLayout>
  );
}
