"use client";

import React, { useState } from "react";
import useSWR from "swr";
import { AppLayout } from "@/components/layout/AppLayout";
import { api, fetcher } from "@/lib/api";
import { useTheme } from "@/lib/theme-context";
import { cleanDisplayPhone } from "@/lib/utils";
import {
  Building2,
  Plus,
  Trash2,
  Phone,
  MapPin,
  Shield,
  X,
} from "lucide-react";

export default function OrganizationsPage() {
  const { t } = useTheme();
  const [isCreateOpen, setIsCreateOpen] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Form State
  const [orgName, setOrgName] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [phone, setPhone] = useState("");
  const [category, setCategory] = useState("Medical");
  const [lat, setLat] = useState("16.8661");
  const [lng, setLng] = useState("96.1951");
  const [radius, setRadius] = useState("50");

  const { data: orgs, mutate } = useSWR("/admin/organizations?limit=100", fetcher, {
    refreshInterval: 10000,
  });

  const handleCreateOrg = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError(null);

    try {
      await api.post("/admin/organizations", {
        org_name: orgName,
        email,
        password,
        phone_number: phone,
        category,
        geo_lat: parseFloat(lat) || 16.8661,
        geo_lng: parseFloat(lng) || 96.1951,
        coverage_radius_km: parseFloat(radius) || 50.0,
      });
      setIsCreateOpen(false);
      setOrgName("");
      setEmail("");
      setPassword("");
      setPhone("");
      mutate();
    } catch (err: any) {
      setError(err.message || "Failed to create organization.");
    } finally {
      setLoading(false);
    }
  };

  const handleDeleteOrg = async (orgId: string, name: string) => {
    if (!confirm(`Are you sure you want to delete "${name}"?`)) return;
    try {
      await api.delete(`/admin/organizations/${orgId}`);
      mutate();
    } catch (err: any) {
      alert(err.message || "Failed to delete organization.");
    }
  };

  return (
    <AppLayout title={t("Rescue Organization Registry", "ကယ်ဆယ်ရေး အဖွဲ့အစည်းများ စာရင်း")}>
      <div className="space-y-6">
        {/* Top Action Bar */}
        <div className="flex items-center justify-between p-4 glass-panel bg-[var(--bg-surface)] rounded-2xl border border-[var(--border-main)]">
          <div className="flex items-center gap-3">
            <div className="p-2 rounded-xl bg-blue-600/20 text-blue-500 border border-blue-500/30">
              <Building2 className="w-5 h-5" />
            </div>
            <div>
              <h3 className="font-extrabold text-sm text-[var(--text-main)]">
                {t("Verified Command Stations", "အတည်ပြုပြီးသော ကယ်ဆယ်ရေး စခန်းများ")}
              </h3>
              <p className="text-xs text-[var(--text-muted)]">
                {(orgs || []).length} {t("Registered Rescue Units", "မှတ်ပုံတင်ထားသော အဖွဲ့များ")}
              </p>
            </div>
          </div>

          <button
            onClick={() => setIsCreateOpen(true)}
            className="px-4 py-2 rounded-xl bg-red-600 hover:bg-red-500 text-white font-bold text-xs shadow-lg shadow-red-600/30 transition-all flex items-center gap-1.5 cursor-pointer"
          >
            <Plus className="w-4 h-4" />
            <span>{t("Register New Organization", "အဖွဲ့အသစ် ထည့်သွင်းမည်")}</span>
          </button>
        </div>

        {/* Organizations Grid */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
          {(orgs || []).map((org: any) => (
            <div
              key={org.account_id || org.id}
              className="glass-panel bg-[var(--bg-surface)] p-5 rounded-xl border border-[var(--border-main)] hover:border-red-500/40 transition-all group relative flex flex-col justify-between shadow-sm"
            >
              <div>
                <div className="flex items-start justify-between">
                  <div className="flex items-center gap-3">
                    <div className="w-10 h-10 rounded-xl bg-blue-500/15 text-blue-600 border border-blue-500/30 flex items-center justify-center font-black text-sm">
                      {org.org_name?.substring(0, 1) || "O"}
                    </div>
                    <div>
                      <h4 className="font-bold text-sm text-[var(--text-main)] group-hover:text-red-500 transition-colors">
                        {org.org_name}
                      </h4>
                      <span className="px-2 py-0.5 rounded text-[10px] font-extrabold bg-blue-500/15 text-blue-600 border border-blue-500/30 uppercase">
                        {org.category || "Medical"}
                      </span>
                    </div>
                  </div>

                  <button
                    onClick={() => handleDeleteOrg(org.account_id || org.id, org.org_name)}
                    className="p-1.5 rounded-lg text-[var(--text-muted)] hover:text-red-500 hover:bg-red-500/10 transition-colors cursor-pointer"
                  >
                    <Trash2 className="w-4 h-4" />
                  </button>
                </div>

                <div className="mt-4 space-y-2 text-xs text-[var(--text-muted)]">
                  <p className="flex items-center gap-2">
                    <Phone className="w-3.5 h-3.5 text-[var(--text-subtle)]" />
                    <span className="font-medium text-[var(--text-main)]">{cleanDisplayPhone(org.phone_number)}</span>
                  </p>
                  <p className="flex items-center gap-2">
                    <MapPin className="w-3.5 h-3.5 text-[var(--text-subtle)]" />
                    <span>Sector: {org.operating_regions || "Yangon Region"}</span>
                  </p>
                  <p className="flex items-center gap-2">
                    <Shield className="w-3.5 h-3.5 text-[var(--text-subtle)]" />
                    <span>Coverage Radius: {org.coverage_radius_km || 50} km</span>
                  </p>
                </div>
              </div>

              <div className="mt-5 pt-3 border-t border-[var(--border-main)] flex items-center justify-between text-[11px]">
                <span className="text-emerald-600 font-bold">● Active Operational</span>
                <span className="text-[var(--text-subtle)] truncate max-w-[140px] font-mono">{org.account?.email}</span>
              </div>
            </div>
          ))}
        </div>

        {/* Create Modal */}
        {isCreateOpen && (
          <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm p-4">
            <div className="w-full max-w-lg glass-panel bg-[var(--bg-surface)] border border-[var(--border-main)] rounded-2xl p-6 shadow-2xl text-[var(--text-main)] max-h-[90vh] overflow-y-auto">
              <div className="flex items-center justify-between pb-4 border-b border-[var(--border-main)]">
                <h3 className="font-extrabold text-base text-[var(--text-main)]">
                  {t("Register Rescue Organization", "ကယ်ဆယ်ရေး အဖွဲ့အစည်း အသစ် မှတ်ပုံတင်ခြင်း")}
                </h3>
                <button
                  onClick={() => setIsCreateOpen(false)}
                  className="text-[var(--text-muted)] hover:text-[var(--text-main)] p-1 rounded-lg"
                >
                  <X className="w-5 h-5" />
                </button>
              </div>

              {error && (
                <div className="mt-4 p-3 rounded-xl bg-red-500/15 border border-red-500/50 text-red-600 text-xs font-bold">
                  {error}
                </div>
              )}

              <form onSubmit={handleCreateOrg} className="mt-4 space-y-4 text-xs">
                <div>
                  <label className="block font-bold text-[var(--text-muted)] uppercase mb-1">Organization Name</label>
                  <input
                    type="text"
                    required
                    value={orgName}
                    onChange={(e) => setOrgName(e.target.value)}
                    placeholder="e.g. Yangon Emergency Rescue Team"
                    className="w-full panel-input rounded-xl p-2.5"
                  />
                </div>

                <div className="grid grid-cols-2 gap-3">
                  <div>
                    <label className="block font-bold text-[var(--text-muted)] uppercase mb-1">Email</label>
                    <input
                      type="email"
                      required
                      value={email}
                      onChange={(e) => setEmail(e.target.value)}
                      placeholder="org@rescue.org"
                      className="w-full panel-input rounded-xl p-2.5"
                    />
                  </div>
                  <div>
                    <label className="block font-bold text-[var(--text-muted)] uppercase mb-1">Password</label>
                    <input
                      type="password"
                      required
                      value={password}
                      onChange={(e) => setPassword(e.target.value)}
                      placeholder="••••••••"
                      className="w-full panel-input rounded-xl p-2.5"
                    />
                  </div>
                </div>

                <div className="grid grid-cols-2 gap-3">
                  <div>
                    <label className="block font-bold text-[var(--text-muted)] uppercase mb-1">Phone Number</label>
                    <input
                      type="tel"
                      required
                      value={phone}
                      onChange={(e) => setPhone(e.target.value)}
                      placeholder="09123456789"
                      className="w-full panel-input rounded-xl p-2.5"
                    />
                  </div>
                  <div>
                    <label className="block font-bold text-[var(--text-muted)] uppercase mb-1">Category</label>
                    <select
                      value={category}
                      onChange={(e) => setCategory(e.target.value)}
                      className="w-full panel-input rounded-xl p-2.5"
                    >
                      <option value="Medical">Medical (ဆေးဝါး)</option>
                      <option value="Fire">Fire Rescue (မီးသတ်)</option>
                      <option value="Disaster">Disaster (သဘာဝဘေး)</option>
                      <option value="General">General (အထွေထွေ)</option>
                    </select>
                  </div>
                </div>

                <div className="grid grid-cols-3 gap-3">
                  <div>
                    <label className="block font-bold text-[var(--text-muted)] uppercase mb-1">Latitude</label>
                    <input
                      type="number"
                      step="any"
                      required
                      value={lat}
                      onChange={(e) => setLat(e.target.value)}
                      className="w-full panel-input rounded-xl p-2.5"
                    />
                  </div>
                  <div>
                    <label className="block font-bold text-[var(--text-muted)] uppercase mb-1">Longitude</label>
                    <input
                      type="number"
                      step="any"
                      required
                      value={lng}
                      onChange={(e) => setLng(e.target.value)}
                      className="w-full panel-input rounded-xl p-2.5"
                    />
                  </div>
                  <div>
                    <label className="block font-bold text-[var(--text-muted)] uppercase mb-1">Radius (km)</label>
                    <input
                      type="number"
                      required
                      value={radius}
                      onChange={(e) => setRadius(e.target.value)}
                      className="w-full panel-input rounded-xl p-2.5"
                    />
                  </div>
                </div>

                <div className="flex items-center gap-3 pt-3">
                  <button
                    type="button"
                    onClick={() => setIsCreateOpen(false)}
                    className="flex-1 py-2.5 font-bold text-[var(--text-muted)] bg-[var(--bg-subtle)] border border-[var(--border-main)] rounded-xl"
                  >
                    Cancel
                  </button>
                  <button
                    type="submit"
                    disabled={loading}
                    className="flex-1 py-2.5 font-bold text-white bg-red-600 hover:bg-red-500 rounded-xl shadow-lg shadow-red-600/30"
                  >
                    {loading ? "Registering..." : "Register Station"}
                  </button>
                </div>
              </form>
            </div>
          </div>
        )}
      </div>
    </AppLayout>
  );
}
