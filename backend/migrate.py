"""
Database Migration Runner for Alembic
Runs 'alembic upgrade head'. If tables already exist without alembic_version, stamps head.
"""
import os
import sys
import subprocess


def run_migrations():
    print("Executing Alembic database migrations...")
    env = os.environ.copy()
    
    # 1. Try upgrading to head
    res = subprocess.run(
        [sys.executable, "-m", "alembic", "upgrade", "head"],
        capture_output=True,
        text=True,
        env=env,
    )

    if res.returncode == 0:
        print("[OK] Alembic database migrations applied successfully!")
        if res.stdout.strip():
            print(res.stdout)
    else:
        # If tables exist prior to Alembic tracking, stamp head
        if "already exists" in res.stderr:
            print("Database tables exist — stamping Alembic version to head...")
            stamp_res = subprocess.run(
                [sys.executable, "-m", "alembic", "stamp", "head"],
                capture_output=True,
                text=True,
                env=env,
            )
            if stamp_res.returncode == 0:
                print("[OK] Alembic database stamped to head revision successfully!")
            else:
                print(f"Stamp notice: {stamp_res.stderr}")
        else:
            print(f"Alembic Migration Notice: {res.stderr or res.stdout}")


if __name__ == "__main__":
    run_migrations()
