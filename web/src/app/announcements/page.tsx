"use client";

import React, { useState } from "react";
import useSWR from "swr";
import { AppLayout } from "@/components/layout/AppLayout";
import { api, fetcher } from "@/lib/api";
import { useTheme } from "@/lib/theme-context";
import { Megaphone, Plus, Trash2, Pin, X } from "lucide-react";

export default function AnnouncementsPage() {
  const { t } = useTheme();
  const [isCreateOpen, setIsCreateOpen] = useState(false);
  const [title, setTitle] = useState("");
  const [content, setContent] = useState("");
  const [isPinned, setIsPinned] = useState(false);
  const [loading, setLoading] = useState(false);

  const { data: announcements, mutate } = useSWR("/announcements", fetcher, {
    refreshInterval: 15000,
  });

  const handleCreate = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    try {
      await api.post("/announcements", {
        title,
        content,
        is_pinned: isPinned,
      });
      setIsCreateOpen(false);
      setTitle("");
      setContent("");
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

  return (
    <AppLayout title={t("Emergency Public Broadcasts", "အရေးပေါ် လူထု ကြေညာချက်များ")}>
      <div className="space-y-6">
        <div className="flex items-center justify-between p-4 glass-panel bg-[var(--bg-surface)] rounded-2xl border border-[var(--border-main)]">
          <div className="flex items-center gap-3">
            <div className="p-2 rounded-xl bg-red-600/20 text-red-500 border border-red-500/30">
              <Megaphone className="w-5 h-5" />
            </div>
            <div>
              <h3 className="font-extrabold text-sm text-[var(--text-main)]">
                {t("Public Siren & System Warnings", "အရေးပေါ် ကြေညာချက်များနှင့် သတိပေးချက်များ")}
              </h3>
              <p className="text-xs text-[var(--text-muted)]">
                {t("Push broadcast alerts directly to mobile app users", "မိုဘိုင်းလ် အက်ပ် အသုံးပြုသူများထံ သတင်းထုတ်ပြန်ခြင်း")}
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

        {/* Announcements List */}
        <div className="space-y-4">
          {(announcements || []).map((a: any) => (
            <div
              key={a.id}
              className={`glass-panel bg-[var(--bg-surface)] p-6 rounded-2xl border transition-all ${
                a.is_pinned
                  ? "border-red-500/50 shadow-lg shadow-red-600/10"
                  : "border-[var(--border-main)]"
              }`}
            >
              <div className="flex items-start justify-between">
                <div className="flex items-center gap-2.5">
                  {a.is_pinned && (
                    <span className="p-1 rounded-md bg-red-600/20 text-red-500 border border-red-500/40">
                      <Pin className="w-3.5 h-3.5" />
                    </span>
                  )}
                  <h4 className="font-extrabold text-base text-[var(--text-main)]">{a.title}</h4>
                </div>
                <button
                  onClick={() => handleDelete(a.id)}
                  className="p-1.5 text-[var(--text-muted)] hover:text-red-500 transition-colors cursor-pointer"
                >
                  <Trash2 className="w-4 h-4" />
                </button>
              </div>

              <p className="mt-3 text-sm text-[var(--text-muted)] leading-relaxed whitespace-pre-wrap">
                {a.content}
              </p>

              <div className="mt-4 pt-3 border-t border-[var(--border-main)] flex items-center justify-between text-xs text-[var(--text-subtle)] font-mono">
                <span>By System Administrator</span>
                <span>{new Date(a.created_at || Date.now()).toLocaleDateString()}</span>
              </div>
            </div>
          ))}
        </div>

        {/* Create Modal */}
        {isCreateOpen && (
          <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm p-4">
            <div className="w-full max-w-lg glass-panel bg-[var(--bg-surface)] border border-[var(--border-main)] rounded-2xl p-6 shadow-2xl text-[var(--text-main)]">
              <div className="flex items-center justify-between pb-4 border-b border-[var(--border-main)]">
                <h3 className="font-extrabold text-base text-[var(--text-main)]">
                  Publish Emergency Broadcast
                </h3>
                <button
                  onClick={() => setIsCreateOpen(false)}
                  className="text-[var(--text-muted)] hover:text-[var(--text-main)] p-1 rounded-lg"
                >
                  <X className="w-5 h-5" />
                </button>
              </div>

              <form onSubmit={handleCreate} className="mt-4 space-y-4 text-xs">
                <div>
                  <label className="block font-bold text-[var(--text-muted)] uppercase mb-1">
                    Announcement Title
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
                    Detailed Message
                  </label>
                  <textarea
                    required
                    rows={5}
                    value={content}
                    onChange={(e) => setContent(e.target.value)}
                    placeholder="Enter full public advisory message..."
                    className="w-full panel-input rounded-xl p-3 text-sm"
                  />
                </div>

                <div className="flex items-center gap-2">
                  <input
                    type="checkbox"
                    id="pinCheckbox"
                    checked={isPinned}
                    onChange={(e) => setIsPinned(e.target.checked)}
                    className="w-4 h-4 rounded border-slate-700 text-red-600 focus:ring-0 cursor-pointer"
                  />
                  <label htmlFor="pinCheckbox" className="text-sm font-semibold text-[var(--text-main)] cursor-pointer">
                    Pin to top of Citizen mobile apps
                  </label>
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
                    {loading ? "Publishing..." : "Broadcast Alert"}
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
