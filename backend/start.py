import os
import uvicorn

if __name__ == "__main__":
    port_env = os.environ.get("PORT", "8000")
    try:
        port = int(port_env)
    except ValueError:
        port = 8000
    print(f"Starting Khu Nyi Kal Sal API on 0.0.0.0:{port}...")
    uvicorn.run("app.main:app", host="0.0.0.0", port=port)
