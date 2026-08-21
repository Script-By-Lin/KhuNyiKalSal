"use client";

import React, { useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { ShieldAlert, X } from "lucide-react";
import { api } from "@/lib/api";
import { useTheme } from "@/lib/theme-context";

interface SuspendUserModalProps {
  user: any;
  isOpen: boolean;
  onClose: () => void;
  onSuccess: () => void;
}

export function SuspendUserModal({
  user,
  isOpen,
  onClose,
  onSuccess,
}: SuspendUserModalProps) {
  const { t } = useTheme();
  const [durationDays, setDurationDays] = useState(1);
  const [reason, setReason] = useState("Administrative suspension for SOS abuse.");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  if (!isOpen || !user) return null;

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError(null);
    try {
      await api.post(`/admin/users/${user.account_id}/suspend`, {
        duration_days: durationDays,
        reason,
      });
      onSuccess();
      onClose();
    } catch (err: any) {
      setError(err.message || "Failed to suspend user.");
    } finally {
      setLoading(false);
    }
  };

  return (
    <AnimatePresence>
      <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm p-4">
        <motion.div
          initial={{ scale: 0.95, opacity: 0 }}
          animate={{ scale: 1, opacity: 1 }}
          exit={{ scale: 0.95, opacity: 0 }}
          className="w-full max-w-md glass-panel bg-[var(--bg-surface)] border border-[var(--border-main)] rounded-2xl p-6 shadow-2xl text-[var(--text-main)]"
        >
          <div className="flex items-center justify-between pb-4 border-b border-[var(--border-main)]">
            <div className="flex items-center gap-3">
              <div className="p-2 rounded-xl bg-red-600/20 text-red-500 border border-red-500/40">
                <ShieldAlert className="w-5 h-5" />
              </div>
              <div>
                <h3 className="font-bold text-base text-[var(--text-main)]">
                  {t("Suspend User Account", "အကောင့်ပိတ်ပင်ခြင်း")}
                </h3>
                <p className="text-xs text-[var(--text-muted)]">{user.email}</p>
              </div>
            </div>
            <button
              onClick={onClose}
              className="text-[var(--text-muted)] hover:text-[var(--text-main)] p-1 rounded-lg hover:bg-[var(--bg-subtle)]"
            >
              <X className="w-5 h-5" />
            </button>
          </div>

          <form onSubmit={handleSubmit} className="mt-5 space-y-4">
            {error && (
              <div className="p-3 text-xs bg-red-500/15 border border-red-500/50 text-red-600 rounded-xl font-bold">
                {error}
              </div>
            )}

            <div>
              <label className="block text-xs font-bold text-[var(--text-muted)] uppercase tracking-wider mb-2">
                {t("Penalty Tier / Duration", "ပိတ်ပင်မည့် ကာလ")}
              </label>
              <div className="grid grid-cols-3 gap-2">
                {[
                  { days: 1, label: t("1 Day (Tier 1)", "၁ ရက် (Tier 1)") },
                  { days: 10, label: t("10 Days (Tier 2)", "၁၀ ရက် (Tier 2)") },
                  { days: 36500, label: t("100 Yrs (Ban)", "နှစ် ၁၀၀ (Ban)") },
                ].map((tier) => (
                  <button
                    key={tier.days}
                    type="button"
                    onClick={() => setDurationDays(tier.days)}
                    className={`py-2.5 px-2 text-xs font-bold rounded-xl border transition-all cursor-pointer ${
                      durationDays === tier.days
                        ? "bg-red-600 text-white border-red-500 shadow-md shadow-red-600/30"
                        : "bg-[var(--bg-subtle)] text-[var(--text-muted)] border-[var(--border-main)] hover:text-[var(--text-main)]"
                    }`}
                  >
                    {tier.label}
                  </button>
                ))}
              </div>
            </div>

            <div>
              <label className="block text-xs font-bold text-[var(--text-muted)] uppercase tracking-wider mb-2">
                {t("Reason Note", "ပိတ်ပင်ရသည့် အကြောင်းအရင်း")}
              </label>
              <textarea
                value={reason}
                onChange={(e) => setReason(e.target.value)}
                rows={3}
                required
                className="w-full panel-input rounded-xl p-3 text-xs placeholder:text-[var(--text-subtle)] focus:outline-none focus:border-red-500"
                placeholder="Reason for suspension..."
              />
            </div>

            <div className="flex items-center gap-3 pt-3">
              <button
                type="button"
                onClick={onClose}
                className="flex-1 py-2.5 text-xs font-bold text-[var(--text-muted)] bg-[var(--bg-subtle)] hover:bg-[var(--bg-card)] rounded-xl border border-[var(--border-main)] transition-colors cursor-pointer"
              >
                {t("Cancel", "မလုပ်တော့ပါ")}
              </button>
              <button
                type="submit"
                disabled={loading}
                className="flex-1 py-2.5 text-xs font-bold text-white bg-red-600 hover:bg-red-500 rounded-xl shadow-lg shadow-red-600/30 transition-all flex items-center justify-center gap-2 cursor-pointer"
              >
                {loading ? "Processing..." : t("Confirm Suspension", "အတည်ပြု ပိတ်ပင်မည်")}
              </button>
            </div>
          </form>
        </motion.div>
      </div>
    </AnimatePresence>
  );
}
