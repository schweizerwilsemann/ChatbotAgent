"""
run.py — Convenience script to start the FastAPI backend server.

Usage:
    python run.py              # Start with default settings (development, auto-reload)
    python run.py --no-reload  # Start without auto-reload (production-like)
    python run.py --port 9000  # Start on a custom port
"""

import argparse
import sys


def main() -> None:
    parser = argparse.ArgumentParser(description="Run the ChatbotAgent backend server.")
    parser.add_argument(
        "--host", default="0.0.0.0", help="Bind host (default: 0.0.0.0)"
    )
    parser.add_argument(
        "--port", type=int, default=8000, help="Bind port (default: 8000)"
    )
    parser.add_argument("--no-reload", action="store_true", help="Disable auto-reload")
    args = parser.parse_args()

    try:
        import uvicorn
    except ImportError:
        print(
            "uvicorn is not installed. Install it with:\n"
            "  pip install uvicorn[standard]\n"
            "Or install all dependencies:\n"
            "  pip install -r backend/requirements.txt"
        )
        sys.exit(1)

    uvicorn.run(
        "main:app",
        host=args.host,
        port=args.port,
        reload=not args.no_reload,
    )


if __name__ == "__main__":
    main()
