{ config, lib, pkgs, ... }:

let
  nvidiaBin = config.hardware.nvidia.package.bin;
  # Compact JSON API for Homepage customapi widgets (dual NVIDIA cards).
  gpuStatsServer = pkgs.writeTextFile {
    name = "gpu-stats-server.py";
    executable = true;
    text = ''
      #!/usr/bin/env python3
      import json
      import subprocess
      import threading
      import time
      from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
      from pathlib import Path

      HOST = "127.0.0.1"
      PORT = 8091
      NVIDIA_SMI = "${nvidiaBin}/bin/nvidia-smi"
      NETWORK_INTERFACE = "enp132s0"
      network_lock = threading.Lock()
      network_previous = None


      def read_loadavg() -> dict:
          parts = Path("/proc/loadavg").read_text().split()
          return {
              "load1": float(parts[0]),
              "load5": float(parts[1]),
              "load15": float(parts[2]),
          }


      def read_uptime_seconds() -> float:
          return float(Path("/proc/uptime").read_text().split()[0])


      def read_mem() -> dict:
          info = {}
          for line in Path("/proc/meminfo").read_text().splitlines():
              key, value = line.split(":", 1)
              info[key] = int(value.split()[0])  # KiB
          total = info.get("MemTotal", 0)
          available = info.get("MemAvailable", 0)
          return {
              "mem_total_mib": round(total / 1024, 1),
              "mem_available_mib": round(available / 1024, 1),
              "mem_used_pct": round(100 * (1 - (available / total)), 1) if total else 0,
          }


      def read_network() -> dict:
          global network_previous
          stats = Path("/sys/class/net") / NETWORK_INTERFACE / "statistics"
          rx_bytes = int((stats / "rx_bytes").read_text())
          tx_bytes = int((stats / "tx_bytes").read_text())
          now = time.monotonic()

          with network_lock:
              previous = network_previous
              network_previous = (now, rx_bytes, tx_bytes)

          if previous is None:
              rx_mbps = 0.0
              tx_mbps = 0.0
          else:
              previous_time, previous_rx, previous_tx = previous
              elapsed = max(now - previous_time, 0.001)
              rx_mbps = max(rx_bytes - previous_rx, 0) * 8 / elapsed / 1_000_000
              tx_mbps = max(tx_bytes - previous_tx, 0) * 8 / elapsed / 1_000_000

          return {
              "rx_mbps": round(rx_mbps, 2),
              "tx_mbps": round(tx_mbps, 2),
          }


      def read_gpus() -> list:
          out = subprocess.check_output(
              [
                  NVIDIA_SMI,
                  "--query-gpu=index,name,utilization.gpu,memory.used,memory.total,temperature.gpu,power.draw",
                  "--format=csv,noheader,nounits",
              ],
              text=True,
          )
          gpus = []
          for line in out.strip().splitlines():
              parts = [p.strip() for p in line.split(",")]
              mem_used = float(parts[3])
              mem_total = float(parts[4])
              power_raw = parts[6]
              try:
                  power_w = float(power_raw)
              except ValueError:
                  power_w = None
              gpus.append(
                  {
                      "index": int(parts[0]),
                      "name": parts[1],
                      "util": float(parts[2]),
                      "mem_used_mib": mem_used,
                      "mem_total_mib": mem_total,
                      "mem_pct": round(100 * mem_used / mem_total, 1) if mem_total else 0,
                      "temp_c": float(parts[5]),
                      "power_w": power_w,
                  }
              )
          return gpus


      def snapshot() -> dict:
          return {
              "host": {
                  **read_loadavg(),
                  "uptime_seconds": read_uptime_seconds(),
                  **read_mem(),
              },
              "gpus": read_gpus(),
          }


      class Handler(BaseHTTPRequestHandler):
          def log_message(self, fmt: str, *args) -> None:
              return

          def _send(self, status: int, payload: dict | list) -> None:
              body = json.dumps(payload).encode("utf-8")
              self.send_response(status)
              self.send_header("Content-Type", "application/json")
              self.send_header("Content-Length", str(len(body)))
              self.send_header("Cache-Control", "no-store")
              self.end_headers()
              self.wfile.write(body)

          def do_GET(self) -> None:
              path = self.path.split("?", 1)[0].rstrip("/") or "/"
              if path == "/network":
                  try:
                      self._send(200, read_network())
                  except Exception as exc:  # noqa: BLE001 — surface to client for Homepage
                      self._send(500, {"error": str(exc)})
                  return

              try:
                  data = snapshot()
              except Exception as exc:  # noqa: BLE001 — surface to client for Homepage
                  self._send(500, {"error": str(exc)})
                  return

              if path in ("/", "/stats"):
                  self._send(200, data)
                  return
              if path == "/host":
                  self._send(200, data["host"])
                  return
              if path.startswith("/gpu/"):
                  try:
                      idx = int(path.split("/")[2])
                  except (IndexError, ValueError):
                      self._send(404, {"error": "not found"})
                      return
                  for gpu in data["gpus"]:
                      if gpu["index"] == idx:
                          self._send(200, gpu)
                          return
                  self._send(404, {"error": "gpu not found"})
                  return

              self._send(404, {"error": "not found"})


      def main() -> None:
          server = ThreadingHTTPServer((HOST, PORT), Handler)
          server.serve_forever()


      if __name__ == "__main__":
          main()
    '';
  };
in
{
  systemd.services.gpu-stats = {
    description = "Local NVIDIA GPU stats JSON API for Homepage";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      DynamicUser = lib.mkForce false;
      User = "rileyt";
      Group = "users";
      ExecStart = "${pkgs.python3}/bin/python ${gpuStatsServer}";
      Restart = "on-failure";
      RestartSec = "5s";
      # NVML / nvidia-smi need device nodes; keep the unit otherwise tight.
      PrivateDevices = false;
      ProtectHome = true;
      ProtectSystem = "strict";
      PrivateTmp = true;
      NoNewPrivileges = true;
    };
  };
}
