import os
import uvicorn
import multiprocessing
import subprocess

if __name__ == "__main__":
    # Auto-run database migrations on every deployment / git push
    try:
        from migrate import run_migrations
        print("🔄 Running automated database migrations before server start...")
        run_migrations()
    except Exception as e:
        print(f"⚠️ Startup migration notice: {e}")

    port_env = os.environ.get("PORT", "8000")
    try:
        port = int(port_env)
    except ValueError:
        port = 8000
        
    # Scale workers safely for Railway hosting (supports up to 3GB RAM container tier)
    # Async Uvicorn handles thousands of concurrent connections efficiently.
    default_workers = 2 if os.name != "nt" else 1
    workers = int(os.environ.get("WEB_CONCURRENCY", str(default_workers)))
    workers = min(max(workers, 1), 4)  # Cap at max 4 workers (well within 3GB RAM limit)
    
    print(f"Starting Khu Nyi Kal Sal API on 0.0.0.0:{port} with {workers} workers (Railway 3GB Scaled)...")
    
    # Run using Gunicorn with Uvicorn workers for production scaling and memory recycling
    cmd = [
        "gunicorn", 
        "app.main:app", 
        "--workers", str(workers), 
        "--worker-class", "uvicorn.workers.UvicornWorker", 
        "--bind", f"0.0.0.0:{port}",
        "--timeout", "120",
        "--max-requests", "1000",
        "--max-requests-jitter", "100",
    ]
    if os.path.exists("/dev/shm"):
        cmd.extend(["--worker-tmp-dir", "/dev/shm"])
    
    try:
        subprocess.run(cmd)
    except (FileNotFoundError, Exception):
        print("Gunicorn not found or running on local, falling back to basic Uvicorn...")
        uvicorn.run("app.main:app", host="0.0.0.0", port=port)
