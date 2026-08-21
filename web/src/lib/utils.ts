/**
 * Shared Utilities for Khu Nyi Kal Sal Web Command Center
 */

import { clsx, type ClassValue } from "clsx";
import { twMerge } from "tailwind-merge";

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

/**
 * Sanitizes phone numbers so that encrypted ciphertexts (Fernet tokens starting with gAAAAA or containing base64)
 * are NEVER displayed in the UI. Returns a clean phone number or fallback string.
 */
export function cleanDisplayPhone(
  phone: string | null | undefined,
  fallback: string = "—"
): string {
  if (!phone) return fallback;
  const p = String(phone).trim();
  // Ciphertext tokens are >20 characters and contain Fernet/base64 patterns
  if (
    p.startsWith("gAAAAA") ||
    p.length > 20 ||
    p.includes("=") ||
    p.includes("_") ||
    p.includes("/")
  ) {
    return fallback;
  }
  return p;
}
