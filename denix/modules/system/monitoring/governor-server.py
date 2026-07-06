#!/usr/bin/env python3
import json
import os
import subprocess
import sys
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import parse_qs, urlparse
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def load_governor_cache():
    """Load available governors for each core at startup"""
    governor_cache = {}
    try:
        cpu_count = os.cpu_count() or 1

        for core in range(cpu_count):
            cmd = ["/run/wrappers/bin/sudo", "@cpupowerPath@", "-c", str(core), "frequency-info", "--governors"]
            result = subprocess.run(cmd, capture_output=True, text=True, check=True, timeout=5)
            # Parse output like "analyzing CPU 0: performance powersave ondemand"
            governors = result.stdout.split(":")[-1].strip().split()
            governor_cache[core] = governors

    except Exception as e:
        logger.error(f"Failed to load governor cache: {e}")
        # Complete fallback
        governor_cache = {i: ["performance", "powersave", "ondemand", "conservative", "schedutil"]
                         for i in range(os.cpu_count() or 1)}

    return governor_cache

# Global cache loaded at startup
GOVERNOR_CACHE = load_governor_cache()
logger.info(f"Loaded governor cache: {GOVERNOR_CACHE}")

class GovernorHandler(BaseHTTPRequestHandler):
    def send_json_response(self, status_code, data):
        """Helper to send JSON response with CORS headers"""
        self.send_response(status_code)
        self.send_header("Content-type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(json.dumps(data).encode())

    def do_GET(self):
        if self.path == "/health":
            self.send_json_response(200, {"status": "ok"})
            return

        self.send_json_response(404, {"status": "error", "message": "Not found"})

    def do_POST(self):
        logger.info(f"Received POST request: {self.path}")

        if self.path != "/set-governor":
            self.send_json_response(404, {"status": "error", "message": "Not found"})
            return

        try:
            content_length = int(self.headers.get("Content-Length", 0))
            post_data = self.rfile.read(content_length)
            data = json.loads(post_data.decode("utf-8"))

            core = data.get("core")
            governor = data.get("governor")
        except (json.JSONDecodeError, ValueError) as e:
            self.send_json_response(400, {"status": "error", "message": f"Invalid JSON: {e}"})
            return

        if not core or not governor:
            self.send_json_response(400, {"status": "error", "message": "Missing core or governor parameter"})
            return

        try:
            core_num = int(core)

            if governor not in GOVERNOR_CACHE.get(core_num, []):
                raise ValueError(f"Invalid governor '{governor}' for core {core_num}")

            cmd = ["/run/wrappers/bin/sudo", "@cpupowerPath@", "-c", str(core_num), "frequency-set", "-g", governor]
            result = subprocess.run(cmd, capture_output=True, text=True, check=True)

            response = {
                "status": "success",
                "core": core_num,
                "governor": governor,
                "output": result.stdout
            }
            self.send_json_response(200, response)
            logger.info(f"Set CPU core {core_num} to {governor} governor")

        except (ValueError, KeyError) as e:
            logger.error(f"Invalid parameter: {e}")
            self.send_json_response(400, {"status": "error", "message": str(e)})
        except subprocess.CalledProcessError as e:
            logger.error(f"cpupower command failed: {e}")
            logger.error(f"stdout: {e.stdout}")
            logger.error(f"stderr: {e.stderr}")
            self.send_json_response(500, {"status": "error", "message": f"cpupower failed: {e.stderr}"})
        except Exception as e:
            logger.error(f"Unexpected error: {e}")
            self.send_json_response(500, {"status": "error", "message": str(e)})

    def do_OPTIONS(self):
        """Handle CORS preflight requests"""
        self.send_response(200)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "*")
        self.end_headers()

    def log_message(self, format, *args):
        """Custom logging to avoid spam"""
        logger.info(format % args)

if __name__ == "__main__":
    server = HTTPServer(("localhost", 8080), GovernorHandler)
    logger.info("CPU Governor API server starting on localhost:8080")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        logger.info("Server stopping...")
        server.shutdown()
