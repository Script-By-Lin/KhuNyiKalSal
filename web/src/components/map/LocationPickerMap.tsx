"use client";

import React from "react";
import dynamic from "next/dynamic";

const DynamicLocationPickerMap = dynamic(
  () => import("./LocationPickerMapInner"),
  {
    ssr: false,
    loading: () => (
      <div className="h-[260px] w-full rounded-xl glass-panel border border-[var(--border-main)] flex items-center justify-center bg-[var(--bg-subtle)]">
        <div className="flex flex-col items-center gap-2">
          <div className="w-6 h-6 border-2 border-red-500 border-t-transparent rounded-full animate-spin"></div>
          <p className="text-[11px] font-bold text-[var(--text-muted)] uppercase tracking-wider">
            Loading Interactive Map...
          </p>
        </div>
      </div>
    ),
  }
);

interface LocationPickerMapProps {
  lat: number;
  lng: number;
  radiusKm?: number;
  onChange: (lat: number, lng: number) => void;
}

export function LocationPickerMap({
  lat,
  lng,
  radiusKm,
  onChange,
}: LocationPickerMapProps) {
  return (
    <DynamicLocationPickerMap
      lat={lat}
      lng={lng}
      radiusKm={radiusKm}
      onChange={onChange}
    />
  );
}
