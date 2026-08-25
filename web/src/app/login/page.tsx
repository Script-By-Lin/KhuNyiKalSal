"use client";

import React, { useState } from "react";
import { motion } from "framer-motion";
import {
  ShieldAlert,
  Lock,
  Mail,
  ArrowRight,
  Activity,
  Radio,
  Eye,
  EyeOff,
  Sun,
  Moon,
  Globe,
  CheckCircle2,
  AlertTriangle,
} from "lucide-react";
import { api } from "@/lib/api";
import { useAuth } from "@/lib/auth-context";
import { useTheme } from "@/lib/theme-context";

export default function LoginPage() {
  const { login } = useAuth();
  const { theme, toggleTheme, language, setLanguage, t } = useTheme();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [rememberMe, setRememberMe] = useState(true);
  const [showPassword, setShowPassword] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  React.useEffect(() => {
    try {
      const savedRemember = localStorage.getItem("admin_remember_me");
      if (savedRemember === "true" || savedRemember === null) {
        const savedEmail = localStorage.getItem("admin_saved_email");
        const savedPassword = localStorage.getItem("admin_saved_password");
        if (savedEmail) setEmail(savedEmail);
        if (savedPassword) setPassword(savedPassword);
        setRememberMe(true);
      } else {
        setRememberMe(false);
      }
    } catch (_) {}
  }, []);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError(null);

    try {
      const res = await api.post("/auth/login", {
        email: email.trim().toLowerCase(),
        password,
      });

      const role = (res.role || "").toUpperCase();
      if (role !== "ADMIN" && role !== "SUPERADMIN") {
        throw new Error(
          t(
            "Access Denied: This web command portal is strictly reserved for Super Administrators.",
            "ဝင်ရောက်ခွင့်မပြုပါ - ဤဝက်ဘ်ဆိုက်သည် စူပါအက်ဒမင်များအတွက်သာ သီးသန့်ဖြစ်ပါသည်။"
          )
        );
      }

      if (rememberMe) {
        localStorage.setItem("admin_remember_me", "true");
        localStorage.setItem("admin_saved_email", email.trim().toLowerCase());
        localStorage.setItem("admin_saved_password", password);
      } else {
        localStorage.setItem("admin_remember_me", "false");
        localStorage.removeItem("admin_saved_email");
        localStorage.removeItem("admin_saved_password");
      }

      login(res.access_token, {
        id: res.user_id,
        email: email.trim().toLowerCase(),
        role: res.role,
      });
    } catch (err: any) {
      setError(err.message || "Authentication failed. Please verify credentials.");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen w-screen flex flex-col lg:flex-row bg-[var(--bg-main)] text-[var(--text-main)] relative overflow-hidden select-none">
      {/* Top Floating Controls */}
      <div className="absolute top-6 right-6 z-50 flex items-center gap-3">
        <button
          onClick={() => setLanguage(language === "en" ? "my" : "en")}
          className="flex items-center gap-1.5 px-3 py-1.5 rounded-xl glass-panel bg-[var(--bg-surface)] border border-[var(--border-main)] text-xs font-bold text-[var(--text-main)] shadow-sm cursor-pointer"
        >
          <Globe className="w-3.5 h-3.5 text-red-500" />
          <span>{language === "en" ? "EN" : "မြန်မာ"}</span>
        </button>

        <button
          onClick={toggleTheme}
          className="p-2 rounded-xl glass-panel bg-[var(--bg-surface)] border border-[var(--border-main)] text-[var(--text-muted)] hover:text-[var(--text-main)] shadow-sm cursor-pointer"
          title={theme === "dark" ? "Switch to Light Mode" : "Switch to Dark Mode"}
        >
          {theme === "dark" ? (
            <Sun className="w-4 h-4 text-amber-400" />
          ) : (
            <Moon className="w-4 h-4 text-slate-700" />
          )}
        </button>
      </div>

      {/* ── Left Hero Panel (Tactical Brand Showcase) ── */}
      <div className="lg:w-7/12 relative flex flex-col justify-between p-8 lg:p-16 bg-gradient-to-br from-slate-950 via-slate-900 to-black text-white border-b lg:border-b-0 lg:border-r border-red-500/20 overflow-hidden">
        {/* Background Radar Circles & Glow */}
        <div className="absolute -top-32 -left-32 w-[650px] h-[650px] bg-red-600/15 rounded-full blur-[140px] pointer-events-none" />
        <div className="absolute bottom-0 right-0 w-[450px] h-[450px] bg-red-800/10 rounded-full blur-[120px] pointer-events-none" />

        {/* Ambient Radar Grid Lines */}
        <div className="absolute inset-0 bg-[linear-gradient(to_right,#1f293708_1px,transparent_1px),linear-gradient(to_bottom,#1f293708_1px,transparent_1px)] bg-[size:4rem_4rem] [mask-image:radial-gradient(ellipse_60%_50%_at_50%_0%,#000_70%,transparent_100%)] pointer-events-none" />

        {/* Top Header */}
        <div className="relative z-10">
          <div className="flex items-center gap-3.5">
            <div className="w-12 h-12 rounded-2xl bg-red-600/20 border-2 border-red-500 flex items-center justify-center shadow-lg shadow-red-600/30">
              <ShieldAlert className="w-7 h-7 text-red-500 animate-pulse" />
            </div>
            <div>
              <h2 className="text-xl font-black tracking-widest text-white">
                KHU NYI KAL SAL
              </h2>
              <p className="text-xs text-red-400 font-extrabold tracking-widest uppercase">
                National Emergency Dispatch & Command Portal
              </p>
            </div>
          </div>
        </div>

        {/* Middle Feature Highlights */}
        <div className="my-12 relative z-10 max-w-xl space-y-6">
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.5 }}
          >
            <span className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-red-500/20 border border-red-500/40 text-red-300 text-xs font-extrabold uppercase tracking-wider mb-4">
              <Radio className="w-3.5 h-3.5 text-red-400 animate-ping" />
              Unified Operations Center
            </span>
            <h1 className="text-3xl lg:text-5xl font-black text-white leading-tight tracking-tight">
              Rapid Emergency Response & Platform Command
            </h1>
            <p className="text-slate-400 text-sm mt-3 leading-relaxed">
              Real-time multi-agency coordination, tactical GPS radar tracking, 3-tier progressive abuse prevention, and automated civilian dispatch across Myanmar.
            </p>
          </motion.div>

          {/* Quick Metrics Grid */}
          <div className="grid grid-cols-2 gap-4 pt-4">
            <div className="p-4 rounded-2xl bg-slate-900/60 border border-slate-800 backdrop-blur-sm">
              <div className="flex items-center gap-2 text-emerald-400 text-xs font-bold mb-1">
                <CheckCircle2 className="w-4 h-4" />
                <span>256-Bit TLS Security</span>
              </div>
              <p className="text-slate-400 text-xs">
                Encrypted SOS transmission & salted privacy hashing
              </p>
            </div>

            <div className="p-4 rounded-2xl bg-slate-900/60 border border-slate-800 backdrop-blur-sm">
              <div className="flex items-center gap-2 text-red-400 text-xs font-bold mb-1">
                <Radio className="w-4 h-4" />
                <span>Sub-Second WebSocket</span>
              </div>
              <p className="text-slate-400 text-xs">
                Live radar telemetry & multi-station siren broadcast
              </p>
            </div>
          </div>
        </div>

        {/* Bottom Footer Notice */}
        <div className="relative z-10 pt-6 border-t border-slate-800/80 flex items-center justify-between text-xs text-slate-500">
          <span>Official Government & NGO Operations</span>
          <span>Build v2.4.0 Live</span>
        </div>
      </div>

      {/* ── Right Panel (Authentication Terminal) ── */}
      <div className="lg:w-5/12 flex items-center justify-center p-8 lg:p-16 bg-[var(--bg-main)]">
        <motion.div
          initial={{ opacity: 0, scale: 0.96 }}
          animate={{ opacity: 1, scale: 1 }}
          transition={{ duration: 0.4 }}
          className="w-full max-w-md glass-panel bg-[var(--bg-surface)] p-8 lg:p-10 rounded-3xl border border-[var(--border-main)] shadow-2xl"
        >
          <div>
            <span className="px-2.5 py-1 text-[10px] font-extrabold uppercase rounded bg-red-500/15 text-red-600 border border-red-500/30">
              Admin Access Terminal
            </span>
            <h3 className="text-2xl font-black text-[var(--text-main)] mt-3">
              {t("Administrator Sign In", "အက်ဒမင် အကောင့်ဝင်ရန်")}
            </h3>
            <p className="text-xs text-[var(--text-muted)] mt-1">
              {t("Enter your super admin credentials to access the platform.", "ကွပ်ကဲရေးစင်တာသို့ ဝင်ရောက်ရန် အချက်အလက်ဖြည့်ပါ။")}
            </p>
          </div>

          {error && (
            <motion.div
              initial={{ opacity: 0, y: -8 }}
              animate={{ opacity: 1, y: 0 }}
              className="mt-5 p-3.5 rounded-xl bg-red-500/15 border border-red-500/50 text-red-600 text-xs font-bold flex items-center gap-2"
            >
              <AlertTriangle className="w-4 h-4 shrink-0" />
              <span>{error}</span>
            </motion.div>
          )}

          <form onSubmit={handleSubmit} className="mt-6 space-y-4">
            <div>
              <label className="block text-xs font-bold text-[var(--text-muted)] uppercase tracking-wider mb-2">
                {t("Email Address", "အီးမေးလ် လိပ်စာ")}
              </label>
              <div className="relative">
                <Mail className="w-4 h-4 text-[var(--text-subtle)] absolute left-3.5 top-1/2 -translate-y-1/2" />
                <input
                  type="email"
                  required
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  placeholder="admin@test.com"
                  className="w-full panel-input rounded-xl py-3 pl-10 pr-4 text-sm font-medium transition-colors"
                />
              </div>
            </div>

            <div>
              <label className="block text-xs font-bold text-[var(--text-muted)] uppercase tracking-wider mb-2">
                {t("Password", "စကားဝှက်")}
              </label>
              <div className="relative">
                <Lock className="w-4 h-4 text-[var(--text-subtle)] absolute left-3.5 top-1/2 -translate-y-1/2" />
                <input
                  type={showPassword ? "text" : "password"}
                  required
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  placeholder="••••••••"
                  className="w-full panel-input rounded-xl py-3 pl-10 pr-10 text-sm font-medium transition-colors"
                />
                <button
                  type="button"
                  onClick={() => setShowPassword(!showPassword)}
                  className="absolute right-3.5 top-1/2 -translate-y-1/2 text-[var(--text-subtle)] hover:text-[var(--text-main)] cursor-pointer"
                >
                  {showPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                </button>
              </div>
            </div>

            <div className="flex items-center justify-between pt-1">
              <label className="flex items-center gap-2 cursor-pointer select-none">
                <input
                  type="checkbox"
                  checked={rememberMe}
                  onChange={(e) => setRememberMe(e.target.checked)}
                  className="w-4 h-4 rounded border-slate-700 text-red-600 focus:ring-0 cursor-pointer"
                />
                <span className="text-xs font-semibold text-[var(--text-muted)]">
                  {t("Remember credentials", "အကောင့်နှင့် လျှို့ဝှက်နံပါတ် မှတ်ထားမည်")}
                </span>
              </label>
            </div>

            <button
              type="submit"
              disabled={loading}
              className="w-full mt-2 py-3.5 rounded-xl bg-red-600 hover:bg-red-500 text-white font-extrabold text-xs tracking-wider uppercase shadow-lg shadow-red-600/30 transition-all flex items-center justify-center gap-2 cursor-pointer disabled:opacity-50"
            >
              <span>
                {loading ? t("Authenticating...", "စစ်ဆေးနေပါသည်...") : t("Sign In to Command Center", "ကွပ်ကဲရေးစင်တာသို့ ဝင်ရောက်မည်")}
              </span>
              <ArrowRight className="w-4 h-4" />
            </button>
          </form>

          <div className="mt-8 pt-6 border-t border-[var(--border-main)] flex items-center justify-between text-[11px] text-[var(--text-subtle)]">
            <span className="flex items-center gap-1.5">
              <Activity className="w-3.5 h-3.5 text-emerald-500" />
              Direct Railway Backend
            </span>
            <span>REST & WS Enabled</span>
          </div>
        </motion.div>
      </div>
    </div>
  );
}
