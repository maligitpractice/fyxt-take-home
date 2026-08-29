from flask import Flask
import os

app = Flask(__name__)

@app.get("/")
def hello():
    app_secret_configured = bool(os.getenv("APP_SECRET"))

    return {
        "application": "fyxt-demo",
        "environment": os.getenv("ENVIRONMENT", "unknown"),
        "log_level": os.getenv("LOG_LEVEL", "info"),
        "secret_configured": app_secret_configured,
        "message": "Hello from Fyxt GitOps"
    }

@app.get("/health")
def health():
    return {"status": "healthy"}

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
