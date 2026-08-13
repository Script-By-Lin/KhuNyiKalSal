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
        
    # Calculate recommended workers: (2 x cores) + 1
    cores = multiprocessing.cpu_count()
    workers = int(os.environ.get("WEB_CONCURRENCY", max(2, cores * 2 + 1)))
    
    print(f"Starting Khu Nyi Kal Sal API on 0.0.0.0:{port} with {workers} workers...")
    
    # Run using Gunicorn with Uvicorn workers for production scaling
    cmd = [
        "gunicorn", 
        "app.main:app", 
        "--workers", str(workers), 
        "--worker-class", "uvicorn.workers.UvicornWorker", 
        "--bind", f"0.0.0.0:{port}",
        "--timeout", "120"
    ]
    
    try:
        subprocess.run(cmd)
    except FileNotFoundError:
        print("Gunicorn not found in PATH, falling back to basic Uvicorn...")
        uvicorn.run("app.main:app", host="0.0.0.0", port=port)
