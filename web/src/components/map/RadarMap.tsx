"use client";

import React from "react";
import dynamic from "next/dynamic";

const DynamicRadarMap = dynamic(() => import("./RadarMapInner"), {
  ssr: false,
  loading: () => (
    <div className="h-[650px] w-full rounded-2xl glass-panel border border-slate-800 flex items-center justify-center">
      <div className="flex flex-col items-center gap-3">
        <div className="w-10 h-10 border-3 border-red-500 border-t-transparent rounded-full animate-spin"></div>
        <p className="text-xs font-semibold text-slate-400 uppercase tracking-widest">
          Loading Tactical GPS Radar...
        </p>
      </div>
    </div>
  ),
});

export function RadarMap({
  emergencies,
  organizations,
}: {
  emergencies: any[];
  organizations: any[];
}) {
  return <DynamicRadarMap emergencies={emergencies} organizations={organizations} />;
}
