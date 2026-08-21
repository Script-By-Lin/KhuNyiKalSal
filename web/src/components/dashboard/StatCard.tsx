"use client";

import React from "react";
import { motion } from "framer-motion";
import { LucideIcon } from "lucide-react";

interface StatCardProps {
  title: string;
  value: string | number;
  subtitle?: string;
  icon: LucideIcon;
  color?: "red" | "emerald" | "blue" | "amber" | "purple";
  badge?: string;
}

export function StatCard({
  title,
  value,
  subtitle,
  icon: Icon,
  color = "red",
  badge,
}: StatCardProps) {
  const colorMap = {
    red: {
      bg: "bg-red-500/10",
      border: "border-red-500/30",
      icon: "text-red-500",
      glow: "hover:shadow-red-500/20",
    },
    emerald: {
      bg: "bg-emerald-500/10",
      border: "border-emerald-500/30",
      icon: "text-emerald-500",
      glow: "hover:shadow-emerald-500/20",
    },
    blue: {
      bg: "bg-blue-500/10",
      border: "border-blue-500/30",
      icon: "text-blue-500",
      glow: "hover:shadow-blue-500/20",
    },
    amber: {
      bg: "bg-amber-500/10",
      border: "border-amber-500/30",
      icon: "text-amber-500",
      glow: "hover:shadow-amber-500/20",
    },
    purple: {
      bg: "bg-purple-500/10",
      border: "border-purple-500/30",
      icon: "text-purple-500",
      glow: "hover:shadow-purple-500/20",
    },
  };

  const scheme = colorMap[color];

  return (
    <motion.div
      initial={{ opacity: 0, y: 15 }}
      animate={{ opacity: 1, y: 0 }}
      whileHover={{ y: -3, transition: { duration: 0.2 } }}
      className={`glass-panel p-6 rounded-2xl border border-[var(--border-main)] bg-[var(--bg-surface)] transition-all duration-300 hover:shadow-xl ${scheme.glow} relative overflow-hidden`}
    >
      <div className="flex items-start justify-between">
        <div>
          <p className="text-[11px] font-extrabold tracking-wider text-[var(--text-muted)] uppercase">
            {title}
          </p>
          <h3 className="text-3xl font-black text-[var(--text-main)] mt-2 tracking-tight">
            {value}
          </h3>
          {subtitle && (
            <p className="text-xs text-[var(--text-muted)] mt-1 font-medium">{subtitle}</p>
          )}
        </div>
        <div className={`p-3 rounded-xl ${scheme.bg} border ${scheme.border}`}>
          <Icon className={`w-6 h-6 ${scheme.icon}`} />
        </div>
      </div>
      {badge && (
        <span className="inline-block mt-3 text-[10px] font-extrabold px-2 py-0.5 rounded-full bg-[var(--bg-subtle)] text-[var(--text-muted)] border border-[var(--border-main)]">
          {badge}
        </span>
      )}
    </motion.div>
  );
}
