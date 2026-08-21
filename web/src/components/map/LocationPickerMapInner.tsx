"use client";

import React, { useEffect, useMemo } from "react";
import {
  MapContainer,
  TileLayer,
  Marker,
  Circle,
  useMap,
  useMapEvents,
} from "react-leaflet";
import L from "leaflet";

interface LocationPickerMapInnerProps {
  lat: number;
  lng: number;
  radiusKm?: number;
  onChange: (lat: number, lng: number) => void;
}

// Subcomponent to handle map clicks & pin dragging
function MapClickHandler({
  onChange,
}: {
  onChange: (lat: number, lng: number) => void;
}) {
  useMapEvents({
    click(e) {
      onChange(
        parseFloat(e.latlng.lat.toFixed(6)),
        parseFloat(e.latlng.lng.toFixed(6))
      );
    },
  });
  return null;
}

// Subcomponent to smoothly pan/recenter map when external lat/lng changes
function MapRecenter({ lat, lng }: { lat: number; lng: number }) {
  const map = useMap();
  useEffect(() => {
    if (!isNaN(lat) && !isNaN(lng)) {
      map.setView([lat, lng], map.getZoom(), { animate: true });
    }
  }, [lat, lng, map]);
  return null;
}

export default function LocationPickerMapInner({
  lat,
  lng,
  radiusKm = 50,
  onChange,
}: LocationPickerMapInnerProps) {
  const validLat = isNaN(lat) ? 16.8661 : lat;
  const validLng = isNaN(lng) ? 96.1951 : lng;

  const stationIcon = useMemo(
    () =>
      L.divIcon({
        className: "custom-station-picker-pin",
        html: `<div style="
          background: linear-gradient(135deg, #DC2626, #991B1B);
          width: 32px;
          height: 32px;
          border-radius: 50% 50% 50% 0;
          transform: rotate(-45deg);
          border: 2.5px solid #FFFFFF;
          box-shadow: 0 4px 14px rgba(220, 38, 38, 0.6);
          display: flex;
          align-items: center;
          justify-content: center;
          cursor: grab;
        ">
          <div style="
            width: 10px;
            height: 10px;
            background: #FFFFFF;
            border-radius: 50%;
            transform: rotate(45deg);
          "></div>
        </div>`,
        iconSize: [32, 32],
        iconAnchor: [16, 32],
      }),
    []
  );

  return (
    <div className="h-[260px] w-full rounded-xl overflow-hidden border border-[var(--border-main)] relative shadow-inner">
      <MapContainer
        center={[validLat, validLng]}
        zoom={12}
        scrollWheelZoom={true}
        style={{ height: "100%", width: "100%" }}
      >
        <TileLayer
          attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
          url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
        />

        <MapClickHandler onChange={onChange} />
        <MapRecenter lat={validLat} lng={validLng} />

        {/* Draggable Station Marker */}
        <Marker
          position={[validLat, validLng]}
          icon={stationIcon}
          draggable={true}
          eventHandlers={{
            dragend(e) {
              const marker = e.target;
              const pos = marker.getLatLng();
              onChange(
                parseFloat(pos.lat.toFixed(6)),
                parseFloat(pos.lng.toFixed(6))
              );
            },
          }}
        />

        {/* Coverage Radius Ring */}
        <Circle
          center={[validLat, validLng]}
          radius={(radiusKm || 50) * 1000}
          pathOptions={{
            color: "#DC2626",
            fillColor: "#DC2626",
            fillOpacity: 0.12,
            weight: 1.5,
            dashArray: "4, 6",
          }}
        />
      </MapContainer>

      {/* Helper overlay instruction */}
      <div className="absolute top-2 right-2 z-[1000] bg-slate-900/85 backdrop-blur-md px-2.5 py-1 rounded-lg border border-slate-700 text-[10px] font-bold text-white shadow-md pointer-events-none">
        📍 Tap anywhere or drag pin to choose location
      </div>
    </div>
  );
}
