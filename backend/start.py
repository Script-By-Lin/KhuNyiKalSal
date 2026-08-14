import os
import uvicorn
import multiprocessing
import subprocess

if __name__ == "__main__":
    port_env = os.environ.get("PORT", "8000")
    try:
        port = int(port_env)
    except ValueError:
        port = 8000
        
    # Limit workers strictly for container memory limits (Railway 512MB RAM tier)
    # Async Uvicorn handles thousands of concurrent connections efficiently in 1-2 workers.
    default_workers = 2 if os.name != "nt" else 1
    workers = int(os.environ.get("WEB_CONCURRENCY", str(default_workers)))
    workers = min(workers, 2)  # Cap at max 2 workers to prevent Railway OOM crashes
    
    print(f"Starting Khu Nyi Kal Sal API on 0.0.0.0:{port} with {workers} workers (Memory-optimized)...")
    
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
