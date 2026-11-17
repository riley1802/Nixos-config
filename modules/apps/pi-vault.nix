# Vault Pi on loopback 8095
{ config, lib, pkgs, ... }:
let
  cfg = config.my.apps.pi-vault;
  stateDir = "/var/lib/pi-vault";
  agentDir = "${stateDir}/agent";
  sessionDir = "${stateDir}/sessions";
  piExe = lib.getExe pkgs.pi-coding-agent;

  piVaultKey = pkgs.writeShellApplication {
    name = "pi-vault-key";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      tr -d '\n\r' < "''${CREDENTIALS_DIRECTORY}/llama-api-key"
    '';
  };

  modelsJson = pkgs.writeText "pi-vault-models.json" ''
    {
      "$schema": "https://pi.dev/schemas/models.schema.json",
      "providers": {
        "spark": {
          "name": "Spark",
          "baseUrl": "http://127.0.0.1:8083/v1",
          "api": "openai-completions",
      ${"\""}apiKey${"\""}: "!${piVaultKey}/bin/pi-vault-key",
          "authHeader": true,
          "models": [{
            "id": "spark",
            "name": "Spark-X2.6-4B",
            "reasoning": true,
            "input": ["text"],
            "contextWindow": 32768,
            "maxTokens": 8192,
            "cost": {"input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0},
            "samplingParams": {"temperature": 1.0, "top_p": 0.95}
          }]
        }
      }
    }
  '';

  settingsJson = pkgs.writeText "pi-vault-settings.json" (builtins.toJSON {
    defaultProvider = "spark";
    defaultModel = "spark";
    extensions = [ "-builtin:llama.cpp" ];
    packages = [ ];
    images = { blockImages = true; };
    modelThinkingLevels = { "spark/spark" = "minimal"; };
  });

  appendSystem = pkgs.writeText "pi-vault-APPEND_SYSTEM.md" (
    lib.concatStringsSep "\n" [
      "This agent only organizes the Obsidian vault at /obsidian-vault. Do not edit .obsidian/ (Obsidian rewrites workspace.json while it is open). Do not touch /etc/nixos, home, or other disks. Do not call nixctl or Discord."
      ""
      "Delete means move the file into .trash/. Never shred."
      ""
      "If the message names the note, one move is fine. Bulk delete, or anything you are unsure about, do nothing, ask, and stop the turn."
      ""
      "Reply with the paths that changed. A crawled page becomes a note in the vault. The reply is the path, not the page."
      ""
      "To save a web page, one curl, no pipes:"
      ""
      "curl -fsS --max-time 180 -H 'Content-Type: application/json' -d '{\"url\":\"https://example.com\"}' http://127.0.0.1:5678/webhook/crawl4ai-markdown"
      ""
      "The field is url, not link. Optional mode: omit or fit for main content, raw for the whole page; bm25 and llm also need q. Stdout of a 200 is the markdown. The Content-Disposition attachment header does not change that. A non-200 body is JSON with error and message. There is no login. Use 127.0.0.1. The tailnet URL fails inside this service. Then write that markdown into a note."
    ]
    + "\n"
  );

  bridgePy = pkgs.writeText "pi-vault-bridge.py" ''
    import hmac
    import json
    import os
    import re
    import secrets
    import signal
    import subprocess
    import sys
    import threading
    import urllib.error
    import urllib.request
    import uuid
    from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

    HOST = "127.0.0.1"
    PORT = 8095
    PI_EXE = "${piExe}"
    CWD = "/obsidian-vault"
    TOKEN_PATH = "/var/lib/pi-vault/token"
    SESSIONS_PATH = "/var/lib/pi-vault/sessions.json"
    PROGRESS_URL = "http://127.0.0.1:5678/webhook/pi-vault-progress"
    RUN_TIMEOUT = 6 * 60
    RPC_TIMEOUT = 120
    SHUTDOWN_WAIT = 20

    SESSION_RE = re.compile(r"^[A-Za-z0-9._-]{1,64}$")

    class PiDown(Exception):
        pass

    class Bridge:
        def __init__(self):
            self.child = None
            self.stdin_lock = threading.Lock()
            self.pending_lock = threading.Lock()
            self.pending = {}
            self.run_lock = threading.Lock()
            self.run_active = False
            self.active_session = ""
            self.settled = threading.Event()
            self.settled_aborted = False
            self.sessions = {}
            self.stdout_thread = None
            self.dead = threading.Event()
            self.auth_token = ""

        def load_token(self):
            if not os.path.isfile(TOKEN_PATH):
                fd = os.open(TOKEN_PATH, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
                try:
                    token = secrets.token_hex(32)
                    os.write(fd, token.encode("utf-8"))
                finally:
                    os.close(fd)
            with open(TOKEN_PATH, "r", encoding="utf-8") as handle:
                self.auth_token = handle.read().strip()

        def load_sessions(self):
            if os.path.isfile(SESSIONS_PATH):
                try:
                    with open(SESSIONS_PATH, "r", encoding="utf-8") as handle:
                        data = json.load(handle)
                    if isinstance(data, dict):
                        self.sessions = data
                        return
                except (json.JSONDecodeError, OSError):
                    pass
            self.sessions = {}

        def save_sessions(self):
            tmp = SESSIONS_PATH + ".tmp"
            with open(tmp, "w", encoding="utf-8") as handle:
                json.dump(self.sessions, handle)
            os.chmod(tmp, 0o600)
            os.replace(tmp, SESSIONS_PATH)

        def child_alive(self):
            return self.child is not None and self.child.poll() is None

        def mark_dead(self):
            if not self.dead.is_set():
                self.dead.set()
                with self.pending_lock:
                    for entry in self.pending.values():
                        entry["error"] = PiDown()
                        entry["event"].set()

        def spawn_child(self):
            self.child = subprocess.Popen(
                [
                    PI_EXE,
                    "--mode",
                    "rpc",
                    "--provider",
                    "spark",
                    "--model",
                    "spark",
                    "--thinking",
                    "minimal",
                    "--tools",
                    "read,write,edit,bash",
                    "--no-skills",
                    "--no-mcp",
                    "--offline",
                ],
                cwd=CWD,
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=None,
                text=False,
                bufsize=0,
            )
            self.stdout_thread = threading.Thread(
                target=self.read_stdout, name="pi-stdout", daemon=True
            )
            self.stdout_thread.start()

        def write_stdin(self, obj):
            with self.stdin_lock:
                if not self.child_alive():
                    raise PiDown()
                line = json.dumps(obj, separators=(",", ":")) + "\n"
                self.child.stdin.write(line.encode("utf-8"))
                self.child.stdin.flush()

        def rpc(self, cmd_type, timeout=RPC_TIMEOUT, **fields):
            rid = str(uuid.uuid4())
            msg = {"id": rid, "type": cmd_type}
            msg.update(fields)
            entry = {"event": threading.Event(), "data": None, "error": None}
            with self.pending_lock:
                self.pending[rid] = entry
            try:
                self.write_stdin(msg)
            except PiDown:
                with self.pending_lock:
                    self.pending.pop(rid, None)
                raise
            if not entry["event"].wait(timeout):
                with self.pending_lock:
                    self.pending.pop(rid, None)
                raise TimeoutError(cmd_type)
            if entry["error"] is not None:
                raise entry["error"]
            data = entry["data"] or {}
            if not data.get("success", False):
                raise RuntimeError(cmd_type + " failed")
            return data.get("data") or {}

        def current_session_file(self):
            state = self.rpc("get_state")
            return state.get("sessionFile")

        def ensure_session(self, key):
            path = self.current_session_file()
            if key not in self.sessions:
                self.rpc("new_session")
                self.rpc("set_session_name", name=key)
                path = self.current_session_file()
                if path:
                    self.sessions[key] = path
                    self.save_sessions()
            elif self.sessions[key] != path:
                self.rpc("switch_session", sessionPath=self.sessions[key])

        def progress_text(self, event):
            tool = event.get("toolName") or ""
            args = event.get("args") or {}
            if tool == "bash":
                cmd = (args.get("command") or "").strip()[:120]
                return ("bash " + cmd).strip()
            if tool in ("write", "edit"):
                path = args.get("path") or ""
                return (tool + " " + path).strip()
            return tool

        def post_progress_async(self, session_key, text):
            def worker():
                body = json.dumps({"session": session_key or "", "text": text}).encode(
                    "utf-8"
                )
                req = urllib.request.Request(
                    PROGRESS_URL,
                    data=body,
                    headers={"Content-Type": "application/json"},
                    method="POST",
                )
                try:
                    urllib.request.urlopen(req, timeout=2)
                except (urllib.error.URLError, OSError, TimeoutError):
                    pass

            threading.Thread(target=worker, daemon=True).start()

        def on_agent_settled(self, aborted):
            self.settled_aborted = bool(aborted)
            self.settled.set()

        def handle_extension_ui(self, obj):
            eid = obj.get("id")
            if not eid:
                return
            try:
                self.write_stdin(
                    {
                        "type": "extension_ui_response",
                        "id": eid,
                        "cancelled": True,
                    }
                )
            except PiDown:
                pass

        def dispatch_event(self, obj):
            typ = obj.get("type")
            if typ == "agent_settled":
                self.on_agent_settled(obj.get("aborted", False))
            elif typ == "extension_ui_request":
                self.handle_extension_ui(obj)
            elif typ == "tool_execution_start":
                session_key = self.active_session if self.run_active else ""
                line = self.progress_text(obj)
                if line:
                    self.post_progress_async(session_key, line)

        def read_stdout(self):
            buf = b""
            handle = self.child.stdout
            while True:
                chunk = handle.read(4096)
                if not chunk:
                    self.mark_dead()
                    return
                buf += chunk
                while b"\n" in buf:
                    line, buf = buf.split(b"\n", 1)
                    if not line.strip():
                        continue
                    try:
                        obj = json.loads(line.decode("utf-8", errors="replace"))
                    except json.JSONDecodeError as err:
                        print("pi-vault: bad json: " + str(err), file=sys.stderr)
                        continue
                    if not isinstance(obj, dict):
                        continue
                    if obj.get("type") == "response" and "id" in obj:
                        rid = obj["id"]
                        with self.pending_lock:
                            entry = self.pending.pop(rid, None)
                        if entry is not None:
                            entry["data"] = obj
                            entry["event"].set()
                        continue
                    self.dispatch_event(obj)

        def wait_settled(self, timeout):
            return self.settled.wait(timeout)

        def finish_run_response(self):
            try:
                data = self.rpc("get_last_assistant_text")
            except (PiDown, TimeoutError, RuntimeError):
                data = {}
            text = data.get("text") if isinstance(data, dict) else None
            if not text:
                text = "finished with no reply"
            out = {"ok": True, "text": text}
            if self.settled_aborted:
                out["stopped"] = True
            return out

        def handle_prompt(self, session_key, text):
            if not self.child_alive():
                raise PiDown()
            is_stop = text.strip().lower() == "stop"
            with self.run_lock:
                if self.run_active:
                    if self.active_session != session_key:
                        return 409, {"ok": False, "error": "busy"}
                    if is_stop:
                        try:
                            self.rpc("abort", timeout=RUN_TIMEOUT + 60)
                        except (PiDown, TimeoutError, RuntimeError):
                            raise PiDown()
                        return 200, {"ok": True, "stopped": True}
                    try:
                        self.rpc("steer", message=text, timeout=30)
                    except (PiDown, TimeoutError, RuntimeError):
                        raise PiDown()
                    return 200, {"ok": True, "steered": True}
                self.ensure_session(session_key)
                self.run_active = True
                self.active_session = session_key
                self.settled.clear()
                self.settled_aborted = False
            try:
                self.rpc("prompt", message=text, timeout=30)
            except (PiDown, TimeoutError, RuntimeError) as err:
                with self.run_lock:
                    self.run_active = False
                    self.active_session = ""
                if isinstance(err, PiDown):
                    raise
                return 500, {"ok": False, "error": "prompt failed"}
            if not self.wait_settled(RUN_TIMEOUT):
                try:
                    self.rpc("abort", timeout=RUN_TIMEOUT + 60)
                except (PiDown, TimeoutError, RuntimeError):
                    pass
                self.wait_settled(120)
                self.settled_aborted = True
            body = self.finish_run_response()
            with self.run_lock:
                self.run_active = False
                self.active_session = ""
            return 200, body

        def shutdown_child(self):
            if self.child is None:
                return
            try:
                if self.child.stdin:
                    self.child.stdin.close()
            except OSError:
                pass
            try:
                self.child.wait(timeout=SHUTDOWN_WAIT)
            except subprocess.TimeoutExpired:
                self.child.kill()
                self.child.wait(timeout=5)

    bridge = Bridge()

    def handle_sigterm(signum, frame):
        bridge.shutdown_child()
        sys.exit(0)

    signal.signal(signal.SIGTERM, handle_sigterm)

    class Handler(BaseHTTPRequestHandler):
        server_version = "pi-vault/1"

        def log_message(self, fmt, *args):
            sys.stderr.write("%s - %s\n" % (self.address_string(), fmt % args))

        def send_json(self, code, body):
            raw = json.dumps(body).encode("utf-8")
            self.send_response(code)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(raw)))
            self.end_headers()
            self.wfile.write(raw)

        def do_POST(self):
            if bridge.dead.is_set() or not bridge.child_alive():
                self.send_json(503, {"ok": False, "error": "pi down"})
                os._exit(1)
            if self.path != "/prompt":
                self.send_json(404, {"ok": False, "error": "not found"})
                return
            token = self.headers.get("X-Pi-Vault-Token", "")
            if not token or not hmac.compare_digest(token, bridge.auth_token):
                self.send_response(401)
                self.end_headers()
                return
            length = int(self.headers.get("Content-Length", "0") or "0")
            if length <= 0 or length > 20000:
                self.send_json(400, {"ok": False, "error": "bad request"})
                return
            try:
                payload = json.loads(self.rfile.read(length).decode("utf-8"))
            except (json.JSONDecodeError, UnicodeDecodeError):
                self.send_json(400, {"ok": False, "error": "bad request"})
                return
            session_key = payload.get("session")
            text = payload.get("text")
            if (
                not isinstance(session_key, str)
                or not SESSION_RE.fullmatch(session_key)
                or not isinstance(text, str)
                or not (1 <= len(text) <= 16000)
            ):
                self.send_json(400, {"ok": False, "error": "bad request"})
                return
            try:
                code, body = bridge.handle_prompt(session_key, text)
                self.send_json(code, body)
            except PiDown:
                self.send_json(503, {"ok": False, "error": "pi down"})
                os._exit(1)

        def do_GET(self):
            self.send_json(404, {"ok": False, "error": "not found"})

    def main():
        bridge.load_token()
        bridge.load_sessions()
        bridge.spawn_child()
        try:
            bridge.rpc("get_state", timeout=60)
        except (PiDown, TimeoutError, RuntimeError) as err:
            print("pi-vault: pi failed get_state: " + str(err), file=sys.stderr)
            bridge.shutdown_child()
            sys.exit(1)
        server = ThreadingHTTPServer((HOST, PORT), Handler)
        try:
            server.serve_forever()
        finally:
            server.server_close()
            bridge.shutdown_child()

    if __name__ == "__main__":
        main()
  '';

  jq = lib.getExe pkgs.jq;

  piVaultCli = pkgs.writeShellApplication {
    name = "pi-vault";
    runtimeInputs = [ pkgs.curl pkgs.jq ];
    text = ''
      set -euo pipefail
      session=local
      args=()
      while [[ $# -gt 0 ]]; do
        case "$1" in
          --session) session="$2"; shift 2 ;;
          *) args+=("$1"); shift ;;
        esac
      done
      if [[ ''${#args[@]} -ne 1 ]]; then
        echo "usage: pi-vault [--session NAME] MESSAGE" >&2
        exit 1
      fi
      token_file=${stateDir}/token
      if [[ ! -f "$token_file" ]]; then
        echo "missing token file" >&2
        exit 1
      fi
      token=$(<"$token_file")
      text=''${args[0]}
      body=$(${jq} -n --arg session "$session" --arg text "$text" '{session: $session, text: $text}')
      curl -fsS --max-time 400 -H "X-Pi-Vault-Token: $token" -H "Content-Type: application/json" -d "$body" http://127.0.0.1:8095/prompt
    '';
  };
in
{
  options.my.apps.pi-vault.enable = lib.mkEnableOption "Vault Pi on loopback port 8095";

  config = lib.mkIf cfg.enable {
    assertions = [{ assertion = config.my.services.nemotron.enable; message = "apps/pi-vault needs services/nemotron (nixctl enable services/nemotron)"; }];

    environment.systemPackages = [ piVaultCli piVaultKey ];

    systemd.services.pi-vault = {
      description = "Vault Pi loopback bridge for Obsidian vault";
      wantedBy = [ "multi-user.target" ];
      after = [ "obsidian-vault.mount" "network.target" ];
      serviceConfig = {
        Type = "simple";
        KillMode = "control-group";
        User = config.my.user;
        Group = "users";
        WorkingDirectory = "/obsidian-vault";
        StateDirectory = "pi-vault";
        StateDirectoryMode = "0700";
        Environment = [
          "HOME=${stateDir}"
          "PATH=/run/current-system/sw/bin"
          "PI_CODING_AGENT_DIR=${agentDir}"
          "PI_CODING_AGENT_SESSION_DIR=${sessionDir}"
          "PI_OFFLINE=1"
          "PI_SKIP_VERSION_CHECK=1"
        ];
        LoadCredential = [ "llama-api-key:${config.age.secrets.llama-api-key.path}" ];
        ExecStartPre = [
          "${pkgs.coreutils}/bin/mkdir -p ${agentDir} ${sessionDir}"
          "${pkgs.coreutils}/bin/cp -f ${appendSystem} ${agentDir}/APPEND_SYSTEM.md"
          "${pkgs.coreutils}/bin/cp -f ${modelsJson} ${agentDir}/models.json"
          "${pkgs.coreutils}/bin/cp -f ${settingsJson} ${agentDir}/settings.json"
        ];
        ExecStart = "${pkgs.python3}/bin/python3 ${bridgePy}";
        Restart = "on-failure";
        RestartSec = "5s";
        ProtectSystem = "strict";
        ProtectHome = "tmpfs";
        PrivateTmp = true;
        NoNewPrivileges = true;
        ReadWritePaths = [ "/obsidian-vault" stateDir ];
        InaccessiblePaths = [ "/etc/nixos" "/run/agenix" "/var/lib/nixctl-bridge" ];
        IPAddressDeny = "any";
        IPAddressAllow = "localhost";
        RestrictAddressFamilies = [ "AF_INET" "AF_UNIX" ];
      };
    };
  };
}
