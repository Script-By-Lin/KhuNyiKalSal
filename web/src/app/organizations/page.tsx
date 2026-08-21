"use client";

import React, { useState } from "react";
import useSWR from "swr";
import { AppLayout } from "@/components/layout/AppLayout";
import { api, fetcher } from "@/lib/api";
import { useTheme } from "@/lib/theme-context";
import { cleanDisplayPhone } from "@/lib/utils";
import { LocationPickerMap } from "@/components/map/LocationPickerMap";
import {
  Building2,
  Plus,
  Phone,
  MapPin,
  Shield,
  ShieldCheck,
  X,
  Crosshair,
  Compass,
} from "lucide-react";

const CITY_PRESETS = [
  { name: "Yangon", mm: "ရန်ကုန်", lat: 16.8661, lng: 96.1951 },
  { name: "Mandalay", mm: "မန္တလေး", lat: 21.9588, lng: 96.0891 },
  { name: "Naypyidaw", mm: "နေပြည်တော်", lat: 19.7633, lng: 96.0785 },
  { name: "Bago", mm: "ပဲခူး", lat: 17.3353, lng: 96.4816 },
  { name: "Taunggyi", mm: "တောင်ကြီး", lat: 20.789, lng: 97.0378 },
  { name: "Mawlamyine", mm: "မော်လမြိုင်", lat: 16.4905, lng: 97.6283 },
];

export default function OrganizationsPage() {
  const { t } = useTheme();
  const [isCreateOpen, setIsCreateOpen] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [gpsLoading, setGpsLoading] = useState(false);

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

  const handleUseCurrentGps = () => {
    if (typeof window === "undefined" || !navigator.geolocation) {
      alert("Geolocation is not supported by your browser.");
      return;
    }
    setGpsLoading(true);
    navigator.geolocation.getCurrentPosition(
      (position) => {
        setLat(position.coords.latitude.toFixed(6));
        setLng(position.coords.longitude.toFixed(6));
        setGpsLoading(false);
      },
      (err) => {
        setGpsLoading(false);
        alert(`Failed to get GPS location: ${err.message}`);
      },
      { enableHighAccuracy: true, timeout: 10000 }
    );
  };

  const handleCreateOrg = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);

    // Pre-validation
    if (password.length < 6 || !/[A-Z]/.test(password) || !/[a-z]/.test(password) || !/\d/.test(password)) {
      setError("Password must be at least 6 characters long and contain at least one uppercase letter (A-Z), one lowercase letter (a-z), and one number (0-9). Example: Rescue123");
      return;
    }

    const cleanPhone = phone.trim().replace(/[\s-]/g, "");
    if (!/^(?:\+959|09)\d{7,10}$/.test(cleanPhone)) {
      setError("Phone number must start with 09 or +959 (e.g. 09123456789 or +959123456789).");
      return;
    }

    setLoading(true);

    try {
      await api.post("/admin/organizations", {
        org_name: orgName.trim(),
        email: email.trim(),
        password,
        phone_number: cleanPhone,
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

  return (
    <AppLayout title={t("Rescue Organization Registry", "ကယ်ဆယ်ရေး အဖွဲ့အစည်းများ စာရင်း")}>
      <div className="space-y-6">
        {/* Header Actions */}
        <div className="flex flex-wrap items-center justify-between gap-4 p-5 glass-panel bg-[var(--bg-surface)] rounded-2xl border border-[var(--border-main)] shadow-sm">
          <div className="flex items-center gap-3">
            <div className="p-3 rounded-xl bg-blue-500/15 text-blue-600 border border-blue-500/30">
              <Building2 className="w-5 h-5" />
            </div>
            <div>
              <h3 className="font-extrabold text-sm text-[var(--text-main)]">
                {t("Rescue Units & Stations Directory", "ကယ်ဆယ်ရေးစခန်းများ လမ်းညွှန်")}
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

                  <span className="p-1 rounded-lg text-emerald-600 bg-emerald-500/10 border border-emerald-500/20 text-[10px] font-bold flex items-center gap-1">
                    <ShieldCheck className="w-3.5 h-3.5" />
                    Verified
                  </span>
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

        {/* Create Organization Modal with Interactive Map Location Picker (Landscape Layout) */}
        {isCreateOpen && (
          <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm p-4 md:p-6 overflow-y-auto">
            <div className="w-full max-w-4xl lg:max-w-5xl glass-panel bg-[var(--bg-surface)] border border-[var(--border-main)] rounded-2xl p-6 shadow-2xl text-[var(--text-main)] my-auto max-h-[92vh] overflow-y-auto">
              {/* Modal Header */}
              <div className="flex items-center justify-between pb-4 border-b border-[var(--border-main)]">
                <div className="flex items-center gap-2.5">
                  <div className="p-2.5 rounded-xl bg-red-600/15 text-red-600 border border-red-500/30">
                    <Building2 className="w-5 h-5" />
                  </div>
                  <div>
                    <h3 className="font-extrabold text-base text-[var(--text-main)]">
                      {t("Register Rescue Organization", "ကယ်ဆယ်ရေး အဖွဲ့အစည်း အသစ် မှတ်ပုံတင်ခြင်း")}
                    </h3>
                    <p className="text-xs text-[var(--text-muted)]">
                      {t("Create operational command station & dispatch radius", "အရေးပေါ်ကူညီကယ်ဆယ်ရေး စခန်းနှင့် တည်နေရာ သတ်မှတ်ခြင်း")}
                    </p>
                  </div>
                </div>
                <button
                  onClick={() => setIsCreateOpen(false)}
                  className="text-[var(--text-muted)] hover:text-[var(--text-main)] p-1.5 rounded-lg hover:bg-[var(--bg-subtle)] transition-colors cursor-pointer"
                >
                  <X className="w-5 h-5" />
                </button>
              </div>

              {error && (
                <div className="mt-4 p-3 rounded-xl bg-red-500/15 border border-red-500/50 text-red-600 text-xs font-bold">
                  {error}
                </div>
              )}

              <form onSubmit={handleCreateOrg} className="mt-5">
                {/* 2-Column Landscape Grid */}
                <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                  {/* Left Column: Form Fields & Actions */}
                  <div className="space-y-4 text-xs">
                    <div>
                      <label className="block font-bold text-[var(--text-muted)] uppercase mb-1">
                        Organization Name
                      </label>
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
                        <label className="block font-bold text-[var(--text-muted)] uppercase mb-1">
                          Email
                        </label>
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
                        <label className="block font-bold text-[var(--text-muted)] uppercase mb-1">
                          Password <span className="text-[10px] text-red-500">*</span>
                        </label>
                        <input
                          type="password"
                          required
                          value={password}
                          onChange={(e) => setPassword(e.target.value)}
                          placeholder="e.g. Rescue123"
                          className="w-full panel-input rounded-xl p-2.5"
                        />
                        <span className="text-[10px] text-[var(--text-subtle)] block mt-0.5">
                          Min 6 chars with Uppercase, Lowercase & Number (e.g. Pass123)
                        </span>
                      </div>
                    </div>

                    <div className="grid grid-cols-2 gap-3">
                      <div>
                        <label className="block font-bold text-[var(--text-muted)] uppercase mb-1">
                          Phone Number
                        </label>
                        <input
                          type="tel"
                          required
                          value={phone}
                          onChange={(e) => setPhone(e.target.value)}
                          placeholder="09123456789"
                          className="w-full panel-input rounded-xl p-2.5"
                        />
                        <span className="text-[10px] text-[var(--text-subtle)] block mt-0.5">
                          Must start with 09 or +959
                        </span>
                      </div>
                      <div>
                        <label className="block font-bold text-[var(--text-muted)] uppercase mb-1">
                          Category
                        </label>
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

                    <div>
                      <label className="block font-bold text-[var(--text-muted)] uppercase mb-1">
                        Dispatch Coverage Radius (km)
                      </label>
                      <input
                        type="number"
                        min="1"
                        max="500"
                        required
                        value={radius}
                        onChange={(e) => setRadius(e.target.value)}
                        placeholder="50"
                        className="w-full panel-input rounded-xl p-2.5 font-mono text-xs"
                      />
                    </div>

                    {/* Action Buttons in Left Column */}
                    <div className="flex items-center gap-3 pt-2">
                      <button
                        type="button"
                        onClick={() => setIsCreateOpen(false)}
                        className="flex-1 py-2.5 font-bold text-[var(--text-muted)] bg-[var(--bg-subtle)] hover:bg-[var(--bg-card)] border border-[var(--border-main)] rounded-xl transition-colors cursor-pointer"
                      >
                        Cancel
                      </button>
                      <button
                        type="submit"
                        disabled={loading}
                        className="flex-1 py-2.5 font-bold text-white bg-red-600 hover:bg-red-500 rounded-xl shadow-lg shadow-red-600/30 transition-all cursor-pointer disabled:opacity-50"
                      >
                        {loading ? "Registering..." : "Register Station"}
                      </button>
                    </div>
                  </div>

                  {/* Right Column: Interactive Map Location Picker */}
                  <div className="p-4 rounded-xl bg-[var(--bg-subtle)] border border-[var(--border-main)] space-y-3 flex flex-col justify-between">
                    <div>
                      <div className="flex flex-wrap items-center justify-between gap-2 mb-2">
                        <div className="flex items-center gap-1.5">
                          <MapPin className="w-4 h-4 text-red-500" />
                          <span className="font-extrabold text-[var(--text-main)] text-xs">
                            {t("Station Location on Map", "မြေပုံပေါ်တွင် စခန်းတည်နေရာ ရွေးချယ်မည်")}
                          </span>
                        </div>

                        <button
                          type="button"
                          onClick={handleUseCurrentGps}
                          disabled={gpsLoading}
                          className="px-2.5 py-1 rounded-lg bg-[var(--bg-surface)] hover:bg-[var(--bg-card)] border border-[var(--border-main)] text-[11px] font-bold text-red-500 transition-colors flex items-center gap-1 cursor-pointer disabled:opacity-50 shadow-sm"
                        >
                          <Crosshair className={`w-3.5 h-3.5 ${gpsLoading ? "animate-spin" : ""}`} />
                          <span>{gpsLoading ? "Acquiring GPS..." : "Use My GPS"}</span>
                        </button>
                      </div>

                      {/* Quick City Presets */}
                      <div className="flex flex-wrap items-center gap-1 mb-2.5">
                        <span className="text-[10px] font-bold text-[var(--text-subtle)] uppercase mr-0.5 flex items-center gap-1">
                          <Compass className="w-3 h-3" /> Jump:
                        </span>
                        {CITY_PRESETS.map((city) => {
                          const isSelected =
                            Math.abs(parseFloat(lat) - city.lat) < 0.05 &&
                            Math.abs(parseFloat(lng) - city.lng) < 0.05;
                          return (
                            <button
                              key={city.name}
                              type="button"
                              onClick={() => {
                                setLat(city.lat.toString());
                                setLng(city.lng.toString());
                              }}
                              className={`px-2 py-0.5 rounded-md text-[10px] font-bold transition-colors cursor-pointer ${
                                isSelected
                                  ? "bg-red-600 text-white shadow-sm"
                                  : "bg-[var(--bg-surface)] text-[var(--text-muted)] hover:text-[var(--text-main)] border border-[var(--border-main)]"
                              }`}
                            >
                              {city.name}
                            </button>
                          );
                        })}
                      </div>

                      {/* Embedded Leaflet Map */}
                      <LocationPickerMap
                        lat={parseFloat(lat) || 16.8661}
                        lng={parseFloat(lng) || 96.1951}
                        radiusKm={parseFloat(radius) || 50}
                        onChange={(newLat, newLng) => {
                          setLat(newLat.toString());
                          setLng(newLng.toString());
                        }}
                      />
                    </div>

                    {/* Coordinate inputs synced with map */}
                    <div className="grid grid-cols-2 gap-3 pt-1">
                      <div>
                        <label className="block font-bold text-[var(--text-muted)] text-[10px] uppercase mb-1">
                          Latitude
                        </label>
                        <input
                          type="number"
                          step="any"
                          required
                          value={lat}
                          onChange={(e) => setLat(e.target.value)}
                          className="w-full panel-input rounded-xl p-2 font-mono text-xs"
                        />
                      </div>
                      <div>
                        <label className="block font-bold text-[var(--text-muted)] text-[10px] uppercase mb-1">
                          Longitude
                        </label>
                        <input
                          type="number"
                          step="any"
                          required
                          value={lng}
                          onChange={(e) => setLng(e.target.value)}
                          className="w-full panel-input rounded-xl p-2 font-mono text-xs"
                        />
                      </div>
                    </div>
                  </div>
                </div>
              </form>
            </div>
          </div>
        )}
      </div>
    </AppLayout>
  );
}
