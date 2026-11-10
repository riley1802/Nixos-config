# Loopback HTTP menu for nixctl. Used by the Discord operator.
{ config, lib, pkgs, ... }:
let
  cfg = config.my.services.nixctl-bridge;
  nixctl = "/run/current-system/sw/bin/nixctl";
  nvidiaSmi = "/run/current-system/sw/bin/nvidia-smi";
  systemctl = "/run/current-system/sw/bin/systemctl";
  bridgePy = pkgs.writeText "nixctl-bridge-server.py" ''
    import json
    import re
    import subprocess
    from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

    HOST = "127.0.0.1"
    PORT = 8094
    NIXCTL = ${builtins.toJSON nixctl}
    NVIDIA_SMI = ${builtins.toJSON nvidiaSmi}
    SYSTEMCTL = ${builtins.toJSON systemctl}

    READ_OPS = frozenset({"status", "map", "audit", "logs", "option", "gpu", "services"})
    CHANGE_OPS = frozenset({"apply", "rollback", "undo", "clean"})
    ALL_OPS = READ_OPS | CHANGE_OPS

    UNIT_RE = re.compile(
        r"^[A-Za-z0-9@:_-]+(\.(service|socket|timer|mount|target))?$"
    )
    OPT_RE = re.compile(r"^[A-Za-z0-9_.<>*-]+$")
    MSG_RE = re.compile(r"^[\x20-\x7E]{1,200}$")

    READ_TIMEOUT = 45
    CHANGE_TIMEOUT = 20 * 60
    MAX_OUT = 12000

    def cap(text):
        text = text or ""
        if len(text) > MAX_OUT:
            return text[:MAX_OUT] + "\n...[output truncated]"
        return text

    def run(argv, timeout):
        try:
            proc = subprocess.run(
                argv,
                capture_output=True,
                text=True,
                timeout=timeout,
                shell=False,
            )
            out = cap((proc.stdout or "") + (proc.stderr or ""))
            if proc.returncode != 0:
                return {"ok": False, "output": out, "error": f"exit {proc.returncode}"}
            return {"ok": True, "output": out, "error": ""}
        except subprocess.TimeoutExpired as exc:
            partial = cap((exc.stdout or "") + (exc.stderr or ""))
            return {"ok": False, "output": partial, "error": "timeout"}
        except OSError as exc:
            return {"ok": False, "output": "", "error": str(exc)}

    def reject():
        return {"ok": False, "output": "", "error": "rejected"}

    def handle(body):
        if not isinstance(body, dict):
            return reject()
        op = body.get("op")
        if not isinstance(op, str) or op not in ALL_OPS:
            return reject()
        timeout = CHANGE_TIMEOUT if op in CHANGE_OPS else READ_TIMEOUT

        if op == "status":
            return run([NIXCTL, "status"], timeout)
        if op == "map":
            return run([NIXCTL, "map"], timeout)
        if op == "audit":
            return run([NIXCTL, "audit"], timeout)
        if op == "logs":
            unit = body.get("unit")
            if not isinstance(unit, str) or not UNIT_RE.fullmatch(unit):
                return reject()
            return run([NIXCTL, "logs", unit], timeout)
        if op == "option":
            name = body.get("name")
            if not isinstance(name, str) or not OPT_RE.fullmatch(name):
                return reject()
            return run([NIXCTL, "option", name], timeout)
        if op == "gpu":
            return run(
                [
                    NVIDIA_SMI,
                    "--query-gpu=name,memory.used,memory.total,utilization.gpu",
                    "--format=csv,noheader",
                ],
                timeout,
            )
        if op == "services":
            return run(
                [
                    SYSTEMCTL,
                    "is-active",
                    "llama-cpp-nemotron.service",
                    "n8n.service",
                ],
                timeout,
            )
        if op == "apply":
            message = body.get("message")
            if not isinstance(message, str) or not MSG_RE.fullmatch(message):
                return reject()
            return run([NIXCTL, "apply", message], timeout)
        if op == "rollback":
            return run([NIXCTL, "rollback"], timeout)
        if op == "undo":
            return run([NIXCTL, "undo"], timeout)
        if op == "clean":
            return run([NIXCTL, "clean", "5"], timeout)
        return reject()

    class Handler(BaseHTTPRequestHandler):
        def log_message(self, _fmt, *_args):
            return

        def do_POST(self):
            if self.path != "/run":
                self.send_response(404)
                self.end_headers()
                return
            length = int(self.headers.get("Content-Length", "0") or 0)
            raw = self.rfile.read(length) if length else b"{}"
            try:
                body = json.loads(raw.decode("utf-8"))
            except (UnicodeDecodeError, json.JSONDecodeError):
                body = None
            result = handle(body)
            payload = json.dumps(result).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)

    def main():
        server = ThreadingHTTPServer((HOST, PORT), Handler)
        server.serve_forever()

    if __name__ == "__main__":
        main()
  '';
in
{
  options.my.services.nixctl-bridge.enable = lib.mkEnableOption "Loopback HTTP menu for nixctl. Used by the Discord operator.";

  config = lib.mkIf cfg.enable {
    systemd.services.nixctl-bridge = {
      description = "Loopback HTTP menu for nixctl (Discord operator)";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      serviceConfig = {
        Type = "simple";
        User = config.my.user;
        Group = "users";
        Home = "/home/${config.my.user}";
        WorkingDirectory = "/etc/nixos";
        ExecStart = "${pkgs.python3}/bin/python3 ${bridgePy}";
        Restart = "on-failure";
        RestartSec = "5s";
      };
    };
  };
}
