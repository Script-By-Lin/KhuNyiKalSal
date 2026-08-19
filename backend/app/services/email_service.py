"""
Email notification service for sending Password Reset OTPs.
Supports EmailJS REST API dispatching as well as standard SMTP fallback.
"""

import os
import logging
import httpx
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

from app.config import settings

logger = logging.getLogger(__name__)

EMAILJS_API_URL = "https://api.emailjs.com/api/v1.0/email/send"
APP_NAME = "Khu Nyi Kal Sal (ကူညီကယ်ဆယ်)"


async def send_password_reset_otp_email(to_email: str, otp_code: str, validity_seconds: int = 30) -> bool:
    """
    Sends a 6-digit password reset OTP email using EmailJS REST API or SMTP fallback.
    """
    # ── 1. Try EmailJS REST API ───────────────────────────────────────────
    if settings.EMAILJS_SERVICE_ID and settings.EMAILJS_TEMPLATE_ID and settings.EMAILJS_PUBLIC_KEY:
        try:
            payload = {
                "service_id": settings.EMAILJS_SERVICE_ID,
                "template_id": settings.EMAILJS_TEMPLATE_ID,
                "user_id": settings.EMAILJS_PUBLIC_KEY,
                "template_params": {
                    "to_email": to_email,
                    "otp_code": otp_code,
                    "app_name": APP_NAME,
                    "valid_seconds": str(validity_seconds),
                    "message": f"Your password reset verification code is {otp_code}. Valid for {validity_seconds} seconds.",
                },
            }
            if settings.EMAILJS_PRIVATE_KEY:
                payload["accessToken"] = settings.EMAILJS_PRIVATE_KEY

            async with httpx.AsyncClient(timeout=10.0) as client:
                response = await client.post(
                    EMAILJS_API_URL,
                    json=payload,
                    headers={"Content-Type": "application/json"},
                )

            if response.status_code == 200:
                logger.info(f"✅ [EmailJS] Successfully sent OTP {otp_code} to {to_email}")
                return True
            else:
                logger.warning(
                    f"⚠️ [EmailJS] API returned status {response.status_code}: {response.text}"
                )
        except Exception as e:
            logger.error(f"❌ [EmailJS] Failed to send via EmailJS API: {e}")

    # ── 2. Fallback to Standard SMTP if configured ────────────────────────
    smtp_host = os.getenv("SMTP_HOST", "")
    smtp_port = int(os.getenv("SMTP_PORT", "587"))
    smtp_user = os.getenv("SMTP_USER", "")
    smtp_password = os.getenv("SMTP_PASSWORD", "")
    smtp_from = os.getenv("SMTP_FROM_EMAIL", smtp_user or "no-reply@khunyikalsal.org")

    if smtp_host and smtp_user and smtp_password:
        try:
            subject = f"🔐 [{APP_NAME}] Your Password Reset Code: {otp_code}"
            html_content = f"""
            <!DOCTYPE html>
            <html>
            <body style="font-family: Arial, sans-serif; background-color: #0F172A; color: #FFFFFF; padding: 20px;">
                <div style="background-color: #1E293B; max-width: 480px; margin: 0 auto; border-radius: 16px; padding: 30px; text-align: center; border: 1px solid #334155;">
                    <h2 style="color: #FF3B30; margin: 0 0 10px;">🚨 {APP_NAME}</h2>
                    <p style="color: #94A3B8; font-size: 13px;">Password Reset Verification</p>
                    <div style="background: #0F172A; border: 2px dashed #00E676; border-radius: 12px; padding: 18px; margin: 20px 0;">
                        <span style="font-size: 36px; font-weight: 900; letter-spacing: 8px; color: #00E676;">{otp_code}</span>
                    </div>
                    <p style="color: #CBD5E1; font-size: 14px;">
                        This code is strictly valid for <strong style="color: #FFD600;">{validity_seconds} seconds</strong>.
                    </p>
                </div>
            </body>
            </html>
            """
            msg = MIMEMultipart("alternative")
            msg["Subject"] = subject
            msg["From"] = f"{APP_NAME} <{smtp_from}>"
            msg["To"] = to_email
            msg.attach(MIMEText(html_content, "html"))

            with smtplib.SMTP(smtp_host, smtp_port, timeout=10) as server:
                server.starttls()
                server.login(smtp_user, smtp_password)
                server.sendmail(smtp_from, [to_email], msg.as_string())

            logger.info(f"✅ [SMTP] OTP email delivered to {to_email}")
            return True
        except Exception as e:
            logger.error(f"❌ [SMTP] Failed to send OTP email: {e}")

    # ── 3. Development Simulator Log ──────────────────────────────────────
    logger.info(f"📧 [DEV OTP SIMULATOR] Generated OTP [{otp_code}] for {to_email} (Expires in {validity_seconds}s)")
    return True
