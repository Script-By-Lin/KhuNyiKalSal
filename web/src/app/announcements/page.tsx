"use client";

import React, { useState } from "react";
import useSWR from "swr";
import { AppLayout } from "@/components/layout/AppLayout";
import { api, fetcher } from "@/lib/api";
import { useTheme } from "@/lib/theme-context";
import {
  Megaphone,
  Plus,
  Trash2,
  Pin,
  X,
  AlertTriangle,
  CloudRain,
  HeartHandshake,
  Droplet,
  Info,
} from "lucide-react";

const ANNOUNCEMENT_CATEGORIES = [
  {
    id: "Urgent",
    label: "Urgent Alert",
    labelMm: "အရေးပေါ် သတိပေးချက်",
    icon: AlertTriangle,
    badgeColor: "bg-red-500/15 text-red-600 border-red-500/30",
    dotColor: "bg-red-500",
  },
  {
    id: "Weather/Disaster",
    label: "Weather / Disaster",
    labelMm: "ရာသီဥတု / သဘာဝဘေး",
    icon: CloudRain,
    badgeColor: "bg-blue-500/15 text-blue-600 border-blue-500/30",
    dotColor: "bg-blue-500",
  },
  {
    id: "Blood Drive",
    label: "Blood Drive",
    labelMm: "သွေးလှူဒါန်းပွဲ",
    icon: Droplet,
    badgeColor: "bg-rose-500/15 text-rose-600 border-rose-500/30",
    dotColor: "bg-rose-500",
  },
  {
    id: "Donation & Mission",
    label: "Donation & Our Mission",
    labelMm: "လှူဒါန်းမှုနှင့် ကယ်ဆယ်ရေး",
    icon: HeartHandshake,
    badgeColor: "bg-purple-500/15 text-purple-600 border-purple-500/30",
    dotColor: "bg-purple-500",
  },
  {
    id: "General",
    label: "General News",
    labelMm: "အထွေထွေ သတင်း",
    icon: Info,
    badgeColor: "bg-emerald-500/15 text-emerald-600 border-emerald-500/30",
    dotColor: "bg-emerald-500",
  },
];

export default function AnnouncementsPage() {
  const { t } = useTheme();
  const [isCreateOpen, setIsCreateOpen] = useState(false);
  const [title, setTitle] = useState("");
  const [content, setContent] = useState("");
  const [category, setCategory] = useState("Urgent");
  const [isPinned, setIsPinned] = useState(false);
  const [selectedCategoryFilter, setSelectedCategoryFilter] = useState("ALL");
  const [loading, setLoading] = useState(false);

  const { data: announcements, mutate } = useSWR(
    `/announcements${selectedCategoryFilter !== "ALL" ? `?category=${encodeURIComponent(selectedCategoryFilter)}` : ""}`,
    fetcher,
    {
      refreshInterval: 15000,
    }
  );

  const handleCreate = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    try {
      await api.post("/announcements", {
        title: title.trim(),
        content: content.trim(),
        category,
        is_pinned: isPinned,
      });
      setIsCreateOpen(false);
      setTitle("");
      setContent("");
      setCategory("Urgent");
      setIsPinned(false);
      mutate();
    } catch (err: any) {
      alert(err.message || "Failed to create announcement.");
    } finally {
      setLoading(false);
    }
  };

  const handleDelete = async (id: string) => {
    if (!confirm("Are you sure you want to delete this broadcast?")) return;
    try {
      await api.delete(`/announcements/${id}`);
      mutate();
    } catch (err: any) {
      alert(err.message || "Failed to delete broadcast.");
    }
  };

  const getCategoryMeta = (catId: string) => {
    const matched = ANNOUNCEMENT_CATEGORIES.find(
      (c) => c.id.toLowerCase() === (catId || "").toLowerCase()
    );
    return (
      matched || {
        id: catId,
        label: catId,
        labelMm: catId,
        icon: Info,
        badgeColor: "bg-slate-500/15 text-slate-600 border-slate-500/30",
        dotColor: "bg-slate-500",
      }
    );
  };

  return (
    <AppLayout title={t("Emergency Public Broadcasts", "အရေးပေါ် လူထု ကြေညာချက်များ")}>
      <div className="space-y-6">
        {/* Top Header Card */}
        <div className="flex flex-col md:flex-row items-start md:items-center justify-between gap-4 p-4 glass-panel bg-[var(--bg-surface)] rounded-2xl border border-[var(--border-main)]">
          <div className="flex items-center gap-3">
            <div className="p-2 rounded-xl bg-red-600/20 text-red-500 border border-red-500/30">
              <Megaphone className="w-5 h-5" />
            </div>
            <div>
              <h3 className="font-extrabold text-sm text-[var(--text-main)]">
                {t("Public Siren & System Warnings", "အရေးပေါ် ကြေညာချက်များနှင့် သတိပေးချက်များ")}
              </h3>
              <p className="text-xs text-[var(--text-muted)]">
                {t(
                  "Push broadcast alerts and disaster advisories directly to mobile app users",
                  "မိုဘိုင်းလ် အက်ပ် အသုံးပြုသူများထံ သတင်းထုတ်ပြန်ခြင်း"
                )}
              </p>
            </div>
          </div>

          <button
            onClick={() => setIsCreateOpen(true)}
            className="px-4 py-2 rounded-xl bg-red-600 hover:bg-red-500 text-white font-bold text-xs shadow-lg shadow-red-600/30 transition-all flex items-center gap-1.5 cursor-pointer"
          >
            <Plus className="w-4 h-4" />
            <span>{t("New Broadcast", "ကြေညာချက် အသစ်")}</span>
          </button>
        </div>

        {/* Category Filter Pills */}
        <div className="flex items-center gap-2 overflow-x-auto pb-1">
          <button
            onClick={() => setSelectedCategoryFilter("ALL")}
            className={`px-3.5 py-1.5 rounded-xl font-bold text-xs transition-all border cursor-pointer whitespace-nowrap ${
              selectedCategoryFilter === "ALL"
                ? "bg-red-600 text-white border-red-500 shadow-md shadow-red-600/30"
                : "bg-[var(--bg-surface)] text-[var(--text-muted)] border-[var(--border-main)] hover:text-[var(--text-main)]"
            }`}
          >
            {t("All Categories", "အားလုံး")}
          </button>
          {ANNOUNCEMENT_CATEGORIES.map((cat) => {
            const IconComp = cat.icon;
            const isActive = selectedCategoryFilter === cat.id;
            return (
              <button
                key={cat.id}
                onClick={() => setSelectedCategoryFilter(cat.id)}
                className={`px-3 py-1.5 rounded-xl font-bold text-xs transition-all border cursor-pointer inline-flex items-center gap-1.5 whitespace-nowrap ${
                  isActive
                    ? "bg-red-600 text-white border-red-500 shadow-md shadow-red-600/30"
                    : "bg-[var(--bg-surface)] text-[var(--text-muted)] border-[var(--border-main)] hover:text-[var(--text-main)]"
                }`}
              >
                <IconComp className="w-3.5 h-3.5" />
                <span>{t(cat.label, cat.labelMm)}</span>
              </button>
            );
          })}
        </div>

        {/* Announcements List */}
        <div className="space-y-4">
          {(!announcements || announcements.length === 0) && (
            <div className="glass-panel bg-[var(--bg-surface)] p-12 text-center rounded-2xl border border-[var(--border-main)] text-[var(--text-muted)]">
              <Megaphone className="w-8 h-8 mx-auto mb-2 opacity-40 text-red-500" />
              <p className="font-bold text-sm">No announcements published in this category.</p>
              <p className="text-xs text-[var(--text-subtle)] mt-1">
                Click &quot;New Broadcast&quot; above to issue a public bulletin.
              </p>
            </div>
          )}

          {(announcements || []).map((a: any) => {
            const meta = getCategoryMeta(a.category);
            const IconComp = meta.icon;
            return (
              <div
                key={a.id}
                className={`glass-panel bg-[var(--bg-surface)] p-6 rounded-2xl border transition-all ${
                  a.is_pinned
                    ? "border-red-500/50 shadow-lg shadow-red-600/10"
                    : "border-[var(--border-main)]"
                }`}
              >
                <div className="flex items-start justify-between gap-4">
                  <div className="flex flex-wrap items-center gap-2">
                    {a.is_pinned && (
                      <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-md bg-red-600/20 text-red-500 border border-red-500/40 text-[10px] font-bold uppercase">
                        <Pin className="w-3 h-3" />
                        PINNED
                      </span>
                    )}
                    <span
                      className={`inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-lg font-bold text-[11px] border ${meta.badgeColor}`}
                    >
                      <IconComp className="w-3 h-3" />
                      {t(meta.label, meta.labelMm)}
                    </span>
                    <h4 className="font-extrabold text-base text-[var(--text-main)] ml-1">
                      {a.title}
                    </h4>
                  </div>
                  <button
                    onClick={() => handleDelete(a.id)}
                    title="Delete Announcement"
                    className="p-1.5 text-[var(--text-muted)] hover:text-red-500 transition-colors cursor-pointer rounded-lg hover:bg-red-500/10"
                  >
                    <Trash2 className="w-4 h-4" />
                  </button>
                </div>

                <p className="mt-3 text-sm text-[var(--text-muted)] leading-relaxed whitespace-pre-wrap">
                  {a.content}
                </p>

                <div className="mt-4 pt-3 border-t border-[var(--border-main)] flex items-center justify-between text-xs text-[var(--text-subtle)] font-mono">
                  <span>{a.author_name || "Emergency Command Center"}</span>
                  <span>{new Date(a.created_at || Date.now()).toLocaleString()}</span>
                </div>
              </div>
            );
          })}
        </div>

        {/* Create Modal */}
        {isCreateOpen && (
          <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm p-4">
            <div className="w-full max-w-lg glass-panel bg-[var(--bg-surface)] border border-[var(--border-main)] rounded-2xl p-6 shadow-2xl text-[var(--text-main)]">
              <div className="flex items-center justify-between pb-4 border-b border-[var(--border-main)]">
                <div className="flex items-center gap-3">
                  <div className="p-2 rounded-xl bg-red-600/20 text-red-500 border border-red-500/40">
                    <Megaphone className="w-5 h-5" />
                  </div>
                  <div>
                    <h3 className="font-extrabold text-base text-[var(--text-main)]">
                      {t("Publish Emergency Broadcast", "အရေးပေါ် လူထု ကြေညာချက် ထုတ်ပြန်မည်")}
                    </h3>
                    <p className="text-xs text-[var(--text-muted)]">
                      {t("Broadcast directly to all mobile citizens", "ပြည်သူအားလုံးထံသို့ သတင်းထုတ်လွှင့်မည်")}
                    </p>
                  </div>
                </div>
                <button
                  onClick={() => setIsCreateOpen(false)}
                  className="text-[var(--text-muted)] hover:text-[var(--text-main)] p-1 rounded-lg hover:bg-[var(--bg-subtle)]"
                >
                  <X className="w-5 h-5" />
                </button>
              </div>

              <form onSubmit={handleCreate} className="mt-4 space-y-4 text-xs">
                {/* Category Selection Grid */}
                <div>
                  <label className="block font-bold text-[var(--text-muted)] uppercase mb-1.5">
                    {t("Broadcast Category", "သတင်း အမျိုးအစား")}
                  </label>
                  <div className="grid grid-cols-2 sm:grid-cols-3 gap-2">
                    {ANNOUNCEMENT_CATEGORIES.map((cat) => {
                      const IconComp = cat.icon;
                      const isSelected = category === cat.id;
                      return (
                        <button
                          key={cat.id}
                          type="button"
                          onClick={() => setCategory(cat.id)}
                          className={`p-2.5 rounded-xl border text-left flex items-center gap-2 transition-all cursor-pointer ${
                            isSelected
                              ? "bg-red-600 text-white border-red-500 shadow-md shadow-red-600/30"
                              : "bg-[var(--bg-subtle)] text-[var(--text-muted)] border-[var(--border-main)] hover:text-[var(--text-main)]"
                          }`}
                        >
                          <IconComp className="w-4 h-4 flex-shrink-0" />
                          <span className="font-bold text-[11px] truncate">
                            {t(cat.label, cat.labelMm)}
                          </span>
                        </button>
                      );
                    })}
                  </div>
                </div>

                <div>
                  <label className="block font-bold text-[var(--text-muted)] uppercase mb-1">
                    {t("Announcement Title", "ခေါင်းစဉ်")}
                  </label>
                  <input
                    type="text"
                    required
                    value={title}
                    onChange={(e) => setTitle(e.target.value)}
                    placeholder="e.g. 🚨 Heavy Monsoon Flood Advisory - Insein Township"
                    className="w-full panel-input rounded-xl p-3 text-sm"
                  />
                </div>

                <div>
                  <label className="block font-bold text-[var(--text-muted)] uppercase mb-1">
                    {t("Detailed Message", "အသေးစိတ် အကြောင်းအရာ")}
                  </label>
                  <textarea
                    required
                    rows={4}
                    value={content}
                    onChange={(e) => setContent(e.target.value)}
                    placeholder="Enter full public advisory message, safety instructions, or mission appeal..."
                    className="w-full panel-input rounded-xl p-3 text-sm"
                  />
                </div>

                <div className="flex items-center gap-2 pt-1">
                  <input
                    type="checkbox"
                    id="pinCheckbox"
                    checked={isPinned}
                    onChange={(e) => setIsPinned(e.target.checked)}
                    className="w-4 h-4 rounded border-slate-700 text-red-600 focus:ring-0 cursor-pointer"
                  />
                  <label
                    htmlFor="pinCheckbox"
                    className="text-xs font-bold text-[var(--text-main)] cursor-pointer"
                  >
                    {t(
                      "Pin to top of Citizen mobile apps",
                      "ပြည်သူ့ မိုဘိုင်းလ်အက်ပ်၏ ထိပ်ဆုံးတွင် အမြဲပြသထားမည် (Pin)"
                    )}
                  </label>
                </div>

                <div className="flex items-center gap-3 pt-3">
                  <button
                    type="button"
                    onClick={() => setIsCreateOpen(false)}
                    className="flex-1 py-2.5 font-bold text-[var(--text-muted)] bg-[var(--bg-subtle)] border border-[var(--border-main)] rounded-xl hover:bg-[var(--bg-card)] cursor-pointer transition-colors"
                  >
                    {t("Cancel", "မလုပ်တော့ပါ")}
                  </button>
                  <button
                    type="submit"
                    disabled={loading}
                    className="flex-1 py-2.5 font-bold text-white bg-red-600 hover:bg-red-500 rounded-xl shadow-lg shadow-red-600/30 cursor-pointer transition-all flex items-center justify-center gap-1.5"
                  >
                    {loading
                      ? t("Publishing...", "ထုတ်ပြန်နေသည်...")
                      : t("Broadcast Alert", "ချက်ချင်း ထုတ်ပြန်မည်")}
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
