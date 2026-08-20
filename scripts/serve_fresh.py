import os
import sys
import time
import socket
import subprocess
import webbrowser
import http.server
import socketserver
import argparse
import shutil

PID_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".server.pid")
WEB_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "build", "web")

class EatsBitsHTTPRequestHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=WEB_DIR, **kwargs)

    def end_headers(self):
        # HTML and ServiceWorker revalidate to pick up changes immediately
        if self.path == "/" or self.path.endswith(".html") or "flutter_service_worker.js" in self.path:
            self.send_header("Cache-Control", "no-cache, must-revalidate")
            self.send_header("Pragma", "no-cache")
            self.send_header("Expires", "0")
        else:
            # Allow static resources (.wasm, .js, .png, etc.) to be cached by browser & ServiceWorker
            self.send_header("Cache-Control", "public, max-age=3600")
        super().end_headers()

    def handle_one_request(self):
        try:
            super().handle_one_request()
        except (ConnectionAbortedError, ConnectionResetError, BrokenPipeError, OSError):
            pass

    def log_message(self, format, *args):
        # Keep terminal log clean
        sys.stdout.write(f"[{self.log_date_time_string()}] {format % args}\n")

def stop_existing_server():
    if os.path.exists(PID_FILE):
        try:
            with open(PID_FILE, "r") as f:
                pid = int(f.read().strip())
            print(f"[+] Stopping existing server process (PID: {pid})...")
            if os.name == 'nt':
                subprocess.run(["taskkill", "/F", "/PID", str(pid)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            else:
                os.kill(pid, 9)
            time.sleep(0.5)
        except Exception as e:
            pass
        finally:
            if os.path.exists(PID_FILE):
                os.remove(PID_FILE)

def find_random_port():
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind(('127.0.0.1', 0))
        return s.getsockname()[1]

def format_file_size(size_bytes):
    if size_bytes >= 1024 * 1024 * 1024:
        return f"{size_bytes / (1024 * 1024 * 1024):.2f} GB ({size_bytes:,} bytes)"
    elif size_bytes >= 1024 * 1024:
        return f"{size_bytes / (1024 * 1024):.2f} MB ({size_bytes:,} bytes)"
    elif size_bytes >= 1024:
        return f"{size_bytes / 1024:.2f} KB ({size_bytes:,} bytes)"
    else:
        return f"{size_bytes} bytes"

def print_build_sizes():
    if not os.path.exists(WEB_DIR):
        return
    print("\n" + "=" * 60)
    print("  Web Build Artifact & Package Sizes")
    print("=" * 60)

    print("  Binaries / Compiled Scripts:")
    key_files = [
        "main.dart.js",
        "main.dart.wasm",
        "main.dart.mjs",
        "flutter.js",
        "flutter_bootstrap.js",
        "flutter_service_worker.js"
    ]
    for kf in key_files:
        fp = os.path.join(WEB_DIR, kf)
        if os.path.isfile(fp):
            print(f"    - {kf:<26} : {format_file_size(os.path.getsize(fp))}")

    ck_dir = os.path.join(WEB_DIR, "canvaskit")
    if os.path.isdir(ck_dir):
        ck_size = sum(os.path.getsize(os.path.join(root, f)) for root, _, files in os.walk(ck_dir) for f in files)
        print(f"    - {'canvaskit/ (wasm engines)':<26} : {format_file_size(ck_size)}")

    print("\n  Assets & Bundles:")
    assets_dir = os.path.join(WEB_DIR, "assets")
    if os.path.isdir(assets_dir):
        assets_size = sum(os.path.getsize(os.path.join(root, f)) for root, _, files in os.walk(assets_dir) for f in files)
        print(f"    - {'assets/':<26} : {format_file_size(assets_size)}")

    audio_dir = os.path.join(WEB_DIR, "audio")
    if os.path.isdir(audio_dir):
        audio_size = sum(os.path.getsize(os.path.join(root, f)) for root, _, files in os.walk(audio_dir) for f in files)
        print(f"    - {'audio/':<26} : {format_file_size(audio_size)}")

    total_bytes = sum(os.path.getsize(os.path.join(root, f)) for root, _, files in os.walk(WEB_DIR) for f in files)
    print("  ----------------------------------------------------------")
    print(f"  Total Package Size         : {format_file_size(total_bytes)}")
    print(f"  Output Location            : {WEB_DIR}")
    print("=" * 60 + "\n")

def build_flutter_web(wasm=False, profile=False):
    print("=" * 60)
    print("[+] Building Flutter Web application...")
    print("=" * 60)
    
    flutter_bin = shutil.which("flutter") or shutil.which("flutter.bat") or ("flutter.bat" if os.name == 'nt' else "flutter")
    cmd = [flutter_bin, "build", "web", "--no-tree-shake-icons", "--pwa-strategy=none"]
    if wasm:
        cmd.append("--wasm")
    if profile:
        cmd.append("--profile")
        
    res = subprocess.run(cmd, cwd=os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."), shell=(os.name == 'nt'))
    if res.returncode != 0:
        print("[!] Flutter build failed. Exiting.")
        sys.exit(res.returncode)
    patch_service_worker()
    print_build_sizes()

def patch_service_worker():
    sw_path = os.path.join(WEB_DIR, "flutter_service_worker.js")
    if not os.path.exists(sw_path):
        return
    try:
        with open(sw_path, "r", encoding="utf-8") as f:
            content = f.read()

        # Prevent onlineFirst from throwing uncaught errors on fetch failure
        content = content.replace("throw error;", "return new Response('', {status: 404, statusText: 'Not Found'});")

        # Add fallback fetch for resource loading failures
        old_fetch = "return response || fetch(event.request).then((response) => {\n          if (response && Boolean(response.ok)) {\n            cache.put(event.request, response.clone());\n          }\n          return response;\n        });"
        new_fetch = "return response || fetch(event.request).then((response) => {\n          if (response && Boolean(response.ok)) {\n            cache.put(event.request, response.clone());\n          }\n          return response;\n        }).catch(() => fetch(event.request));"
        content = content.replace(old_fetch, new_fetch)

        # Add unhandled rejection handler to service worker to suppress console noise
        if "self.addEventListener('unhandledrejection'" not in content:
            content += "\nself.addEventListener('unhandledrejection', function(e) { e.preventDefault(); });\n"

        with open(sw_path, "w", encoding="utf-8") as f:
            f.write(content)
        print("[+] Patched flutter_service_worker.js for network fallback resilience.")
    except Exception as e:
        print(f"[!] Warning: Failed to patch flutter_service_worker.js: {e}")

def main():
    parser = argparse.ArgumentParser(description="Rebuild Flutter Web and serve on a fresh random port with no-cache headers.")
    parser.add_argument("--port", type=int, default=8080, help="Port number to listen on (default: 8080)")
    parser.add_argument("--no-build", action="store_true", help="Skip rebuilding Flutter web and only start server")
    parser.add_argument("--wasm", action="store_true", help="Build with --wasm flag")
    parser.add_argument("--profile", action="store_true", help="Build with --profile flag")
    parser.add_argument("--no-browser", action="store_true", help="Do not automatically open browser")
    args = parser.parse_args()

    stop_existing_server()

    if not args.no_build:
        build_flutter_web(wasm=args.wasm, profile=args.profile)
    else:
        patch_service_worker()

    if not os.path.exists(WEB_DIR):
        print(f"[!] Web build directory not found at: {WEB_DIR}")
        print("[!] Run without --no-build to compile first.")
        sys.exit(1)

    # Register MIME types for WASM and JS
    http.server.SimpleHTTPRequestHandler.extensions_map.update({
        '.wasm': 'application/wasm',
        '.js': 'application/javascript',
        '.json': 'application/json',
        '.html': 'text/html',
        '.css': 'text/css',
    })

    port = args.port if args.port > 0 else 8080
    url = f"http://localhost:{port}"

    # Save PID
    with open(PID_FILE, "w") as f:
        f.write(str(os.getpid()))

    print("\n" + "=" * 60)
    print(f"  [+] EATSBITS FLUTTER WEB SERVER STARTED")
    print(f"  URL: {url}")
    print(f"  Port: {port}")
    print(f"  Cache-Control: Optimized (HTML/SW revalidate, static assets cached)")
    print("=" * 60 + "\n")

    if not args.no_browser:
        print(f"[+] Opening browser at {url}...")
        webbrowser.open(url)

    try:
        httpd = http.server.ThreadingHTTPServer(("127.0.0.1", port), EatsBitsHTTPRequestHandler)
        httpd.daemon_threads = True
        print("[+] Press Ctrl+C to stop the server.\n")
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\n[+] Server stopped by user.")
        sys.exit(0)
    finally:
        if os.path.exists(PID_FILE):
            os.remove(PID_FILE)

if __name__ == "__main__":
    main()
