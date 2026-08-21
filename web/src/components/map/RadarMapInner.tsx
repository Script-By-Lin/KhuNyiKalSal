"use client";
import React, { useMemo } from "react";
import { MapContainer, TileLayer, Marker, Popup, Circle } from "react-leaflet";
import L from "leaflet";
import { cleanDisplayPhone } from "@/lib/utils";

interface RadarMapProps {
  emergencies: any[];
  organizations: any[];
}

export default function RadarMapInner({ emergencies, organizations }: RadarMapProps) {
  // Memoized custom Leaflet Icons
  const emergencyIcon = useMemo(
    () =>
      L.divIcon({
        className: "custom-emergency-pin",
        html: `<div style="
          background-color: #DC2626;
          width: 22px;
          height: 22px;
          border-radius: 50%;
          border: 2px solid #FFFFFF;
          box-shadow: 0 0 16px rgba(220, 38, 38, 0.9);
          display: flex;
          align-items: center;
          justify-content: center;
          animation: pulse 1.5s infinite;
        ">
          <div style="width: 8px; height: 8px; background-color: #FFFFFF; border-radius: 50%;"></div>
        </div>`,
        iconSize: [22, 22],
        iconAnchor: [11, 11],
      }),
    []
  );

  const orgIcon = useMemo(
    () =>
      L.divIcon({
        className: "custom-org-pin",
        html: `<div style="
          background-color: #2563EB;
          width: 20px;
          height: 20px;
          border-radius: 6px;
          border: 2px solid #FFFFFF;
          box-shadow: 0 0 12px rgba(37, 99, 235, 0.7);
        "></div>`,
        iconSize: [20, 20],
        iconAnchor: [10, 10],
      }),
    []
  );

  const center: [number, number] = [16.8661, 96.1951]; // Yangon center default

  return (
    <div className="h-[650px] w-full rounded-2xl overflow-hidden border border-[var(--border-main)] shadow-2xl relative bg-slate-950">
      <MapContainer
        center={center}
        zoom={12}
        style={{ height: "100%", width: "100%", background: "#090D16" }}
      >
        <TileLayer
          attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
          url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
        />

        {/* Rescue Organizations with Safe Coordinates */}
        {Array.isArray(organizations) &&
          organizations.map((org: any, idx: number) => {
            if (!org) return null;
            const lat =
              typeof org.geo_lat === "number"
                ? org.geo_lat
                : parseFloat(org.geo_lat);
            const lng =
              typeof org.geo_lng === "number"
                ? org.geo_lng
                : parseFloat(org.geo_lng);

            if (isNaN(lat) || isNaN(lng)) return null;

            const radiusMeters =
              ((typeof org.coverage_radius_km === "number"
                ? org.coverage_radius_km
                : parseFloat(org.coverage_radius_km)) || 10) * 1000;

            const uniqueKey = org.account_id || org.id || `org-${idx}`;

            return (
              <React.Fragment key={uniqueKey}>
                <Marker position={[lat, lng]} icon={orgIcon}>
                  <Popup>
                    <div className="text-slate-900 text-xs p-1">
                      <p className="font-bold text-sm text-blue-700">
                        {org.org_name || "Rescue Unit"}
                      </p>
                      <p className="mt-1">📞 {cleanDisplayPhone(org.phone_number)}</p>
                      <p>🏷️ {org.category || "General"} Unit</p>
                      <p>📡 Radius: {org.coverage_radius_km || 10} km</p>
                    </div>
                  </Popup>
                </Marker>
                <Circle
                  center={[lat, lng]}
                  radius={radiusMeters}
                  pathOptions={{
                    color: "#3B82F6",
                    fillColor: "#3B82F6",
                    fillOpacity: 0.08,
                    weight: 1.5,
                    dashArray: "4, 6",
                  }}
                />
              </React.Fragment>
            );
          })}

        {/* Active Emergencies with Safe Coordinates */}
        {Array.isArray(emergencies) &&
          emergencies.map((e: any, idx: number) => {
            if (!e) return null;
            const lat =
              typeof e.location_lat === "number"
                ? e.location_lat
                : parseFloat(e.location_lat);
            const lng =
              typeof e.location_lng === "number"
                ? e.location_lng
                : parseFloat(e.location_lng);

            if (isNaN(lat) || isNaN(lng)) return null;

            const uniqueKey = e.id || `emergency-${idx}`;

            return (
              <Marker key={uniqueKey} position={[lat, lng]} icon={emergencyIcon}>
                <Popup>
                  <div className="text-slate-900 text-xs p-1">
                    <p className="font-bold text-sm text-red-600 uppercase">
                      🚨 {e.type || "Emergency"} SOS
                    </p>
                    <p className="mt-1 font-semibold">Status: {e.status || "Pending"}</p>
                    <p>Caller: {e.user?.email || "Citizen User"}</p>
                    <p className="font-mono text-[10px] text-slate-500">
                      Coords: {lat.toFixed(4)}, {lng.toFixed(4)}
                    </p>
                  </div>
                </Popup>
              </Marker>
            );
          })}
      </MapContainer>
    </div>
  );
}
