"use client";

import React, { useState } from "react";
import { Sun, Moon, Globe, Radio } from "lucide-react";
import { useTheme } from "@/lib/theme-context";

export function Header({ title }: { title?: string }) {
  const { theme, toggleTheme, language, setLanguage, t } = useTheme();

  return (
    <header className="h-16 border-b border-[var(--border-main)] glass-panel bg-[var(--bg-surface)] sticky top-0 z-30 px-8 flex items-center justify-between">
      {/* Title */}
      <div>
        <h2 className="text-base font-extrabold text-[var(--text-main)] tracking-wide">
          {title || t("Command Dashboard", "ကွပ်ကဲရေး ဒက်ရှ်ဘုတ်")}
        </h2>
      </div>

      {/* Control Actions */}
      <div className="flex items-center gap-3">
        {/* Real-time Connection Badge */}
        <div className="flex items-center gap-2 px-3 py-1 rounded-full bg-[var(--bg-subtle)] border border-[var(--border-main)] text-xs text-[var(--text-muted)]">
          <span className="relative flex h-2 w-2">
            <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75"></span>
            <span className="relative inline-flex rounded-full h-2 w-2 bg-emerald-500"></span>
          </span>
          <span className="font-bold">{t("Live Feed Active", "တိုက်ရိုက်လိုင်း ချိတ်ဆက်ထားသည်")}</span>
        </div>

        {/* Language Switcher */}
        <button
          onClick={() => setLanguage(language === "en" ? "my" : "en")}
          className="flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-[var(--bg-subtle)] hover:bg-[var(--bg-card)] border border-[var(--border-main)] text-xs font-bold text-[var(--text-main)] transition-colors cursor-pointer"
        >
          <Globe className="w-3.5 h-3.5 text-red-500" />
          <span>{language === "en" ? "EN" : "မြန်မာ"}</span>
        </button>

        {/* Theme Toggle */}
        <button
          onClick={toggleTheme}
          className="p-2 rounded-xl bg-[var(--bg-subtle)] hover:bg-[var(--bg-card)] border border-[var(--border-main)] text-[var(--text-muted)] hover:text-[var(--text-main)] transition-colors cursor-pointer"
          title={theme === "dark" ? "Switch to Light Mode" : "Switch to Dark Mode"}
        >
          {theme === "dark" ? (
            <Sun className="w-4 h-4 text-amber-400" />
          ) : (
            <Moon className="w-4 h-4 text-slate-700" />
          )}
        </button>
      </div>
    </header>
  );
}
