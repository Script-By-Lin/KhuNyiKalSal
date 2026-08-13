"""
Test script for verifying Data Privacy (Salted Encryption) & Ephemeral Location Cache.
"""

import sys
import os

# Add backend directory to sys.path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app.core.privacy import (
    generate_salt,
    encrypt_field,
    decrypt_field,
    encrypt_location,
    decrypt_location,
)
from app.services.cache_service import location_cache


def test_salted_privacy():
    print("\n--- 1. Testing Salted Encryption Privacy ---")
    phone = "+959123456789"
    salt1 = generate_salt()
    salt2 = generate_salt()

    enc1, _ = encrypt_field(phone, salt1)
    enc2, _ = encrypt_field(phone, salt2)

    print(f"Original Phone: {phone}")
    print(f"Salt 1: {salt1}")
    print(f"Encrypted (Salt 1): {enc1}")
    print(f"Salt 2: {salt2}")
    print(f"Encrypted (Salt 2): {enc2}")

    assert enc1 != phone, "Ciphertext should not equal plaintext"
    assert enc1 != enc2, "Different salts must produce different ciphertexts"

    dec1 = decrypt_field(enc1, salt1)
    dec2 = decrypt_field(enc2, salt2)

    print(f"Decrypted 1: {dec1}")
    print(f"Decrypted 2: {dec2}")

    assert dec1 == phone, "Decrypted text must match original phone number"
    assert dec2 == phone, "Decrypted text must match original phone number"
    print("[PASS] Salted Encryption & Decryption passed!")

    print("\n--- 2. Testing Salted Location Privacy ---")
    lat, lng = 16.8661, 96.1951
    loc_salt = generate_salt()
    enc_lat, enc_lng, _ = encrypt_location(lat, lng, loc_salt)
    dec_lat, dec_lng = decrypt_location(enc_lat, enc_lng, loc_salt)

    print(f"Original Location: ({lat}, {lng})")
    print(f"Encrypted Location: ({enc_lat}, {enc_lng})")
    print(f"Decrypted Location: ({dec_lat}, {dec_lng})")

    assert dec_lat == lat and dec_lng == lng, "Decrypted location must match original"
    print("[PASS] Salted Location Privacy passed!")


def test_ephemeral_location_cache():
    print("\n--- 3. Testing Ephemeral Real-time Location Cache & Auto-Purging ---")
    user_id = "user-uuid-123"
    emergency_id = "em-uuid-456"
    lat, lng = 16.8000, 96.1500

    # Store in cache
    location_cache.set_realtime_location(
        entity_id=user_id,
        emergency_id=emergency_id,
        lat=lat,
        lng=lng,
        role="user",
        ttl_seconds=300,
    )

    cached = location_cache.get_realtime_location(user_id, emergency_id)
    print(f"Fetched cached real-time location: {cached}")
    assert cached is not None, "Real-time location should exist in cache"
    assert cached["lat"] == lat and cached["lng"] == lng, "Cached coordinates match"

    # Purge tracking for emergency
    print(f"Purging real-time tracking for emergency {emergency_id}...")
    location_cache.purge_realtime_tracking(emergency_id)

    purged = location_cache.get_realtime_location(user_id, emergency_id)
    print(f"After purge lookup: {purged}")
    assert purged is None, "Cache must be completely empty after purge!"
    print("[PASS] Ephemeral Location Cache & Auto-Purging passed!")


if __name__ == "__main__":
    test_salted_privacy()
    test_ephemeral_location_cache()
    print("\n=== ALL DATA PRIVACY & REAL-TIME CACHE TRACKING TESTS PASSED! ===")
