"""
Data Privacy & Security Module — Salted encryption and hashing for PII (Phone numbers, location coordinates).
"""

import base64
import os
import secrets
from typing import Optional, Tuple
from cryptography.fernet import Fernet
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC

from app.config import settings


def generate_salt() -> str:
    """Generate a cryptographically secure 16-byte random hex salt."""
    return secrets.token_hex(16)


def _derive_fernet_key(salt_hex: str) -> bytes:
    """Derive a 32-byte URL-safe base64-encoded Fernet key using master SECRET_KEY and salt."""
    salt_bytes = bytes.fromhex(salt_hex)
    kdf = PBKDF2HMAC(
        algorithm=hashes.SHA256(),
        length=32,
        salt=salt_bytes,
        iterations=100000,
    )
    key = kdf.derive(settings.SECRET_KEY.encode())
    return base64.urlsafe_b64encode(key)


def encrypt_field(plaintext: Optional[str], salt: Optional[str] = None) -> Tuple[Optional[str], str]:
    """
    Encrypt a text field (e.g., phone number) with a cryptographic salt.
    Returns (ciphertext_str, salt_hex).
    """
    if not plaintext:
        return None, salt or generate_salt()
    
    used_salt = salt or generate_salt()
    fernet_key = _derive_fernet_key(used_salt)
    f = Fernet(fernet_key)
    ciphertext = f.encrypt(plaintext.encode("utf-8")).decode("utf-8")
    return ciphertext, used_salt


def decrypt_field(ciphertext: Optional[str], salt: Optional[str]) -> Optional[str]:
    """
    Decrypt a text field using its associated salt.
    Returns plaintext string. If input is legacy plaintext returns raw string;
    if encrypted Fernet token fails decryption, returns None for security.
    """
    if not ciphertext or not salt:
        return ciphertext
    
    try:
        fernet_key = _derive_fernet_key(salt)
        f = Fernet(fernet_key)
        return f.decrypt(ciphertext.encode("utf-8")).decode("utf-8")
    except Exception:
        # If it is an encrypted Fernet payload that failed decryption, do not leak raw ciphertext
        if isinstance(ciphertext, str) and ciphertext.startswith("gAAAAA"):
            return None
        return ciphertext


def encrypt_location(
    lat: Optional[float], lng: Optional[float], salt: Optional[str] = None
) -> Tuple[Optional[str], Optional[str], str]:
    """
    Encrypt base persistent location coordinates (lat, lng) with a salt.
    Returns (encrypted_lat, encrypted_lng, salt_hex).
    """
    used_salt = salt or generate_salt()
    if lat is None or lng is None:
        return None, None, used_salt

    enc_lat, _ = encrypt_field(str(lat), used_salt)
    enc_lng, _ = encrypt_field(str(lng), used_salt)
    return enc_lat, enc_lng, used_salt


def decrypt_location(
    encrypted_lat: Optional[str], encrypted_lng: Optional[str], salt: Optional[str]
) -> Tuple[Optional[float], Optional[float]]:
    """
    Decrypt base persistent location coordinates (lat, lng) using salt.
    Returns (lat_float, lng_float).
    """
    if not encrypted_lat or not encrypted_lng or not salt:
        try:
            return (
                float(encrypted_lat) if encrypted_lat else None,
                float(encrypted_lng) if encrypted_lng else None,
            )
        except (ValueError, TypeError):
            return None, None

    try:
        lat_str = decrypt_field(encrypted_lat, salt)
        lng_str = decrypt_field(encrypted_lng, salt)
        return (
            float(lat_str) if lat_str is not None else None,
            float(lng_str) if lng_str is not None else None,
        )
    except Exception:
        return None, None
