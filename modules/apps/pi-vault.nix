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
    modelThinkingLevels = { "spark/spark" = "low"; };
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
      "You do not turn web pages into markdown. pi-vault-crawl URL does that for one page and prints link URLs. You choose which of those links to crawl next, one URL per call, and only when the user asked for those links. You do not crawl links of links unless the user asked. You still move, rename, delete, and organize notes. Never paste a crawled page into a note yourself. Reply with the command's lines."
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
                    "low",
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

  mdLintConfig = pkgs.writeText "pi-vault-md-lint.json" (builtins.toJSON {
    default = true;
    MD013 = false;
    MD033 = false;
    MD040 = false;
  });

  markdownlintExe = lib.getExe pkgs.markdownlint-cli2;

  piVaultMd = pkgs.writeShellApplication {
    name = "pi-vault-md";
    runtimeInputs = [ pkgs.markdownlint-cli2 pkgs.coreutils pkgs.perl ];
    text = ''
      set -euo pipefail
      vault=/obsidian-vault
      refuse() { echo "pi-vault-md: $1" >&2; exit 1; }
      if [[ $# -ne 1 ]]; then
        refuse "usage: pi-vault-md FILE"
      fi
      file=$1
      case "$file" in
        "$vault"/*) ;;
        *) refuse "file must be under $vault" ;;
      esac
      if [[ ! -e "$file" ]] || [[ -d "$file" ]] || [[ ! -f "$file" ]]; then
        refuse "not a vault file"
      fi
      canon=$(readlink -f -- "$file")
      case "$canon" in
        "$vault"/*) ;;
        *) refuse "file must stay in vault" ;;
      esac
      ${lib.getExe pkgs.perl} -i -pe \
        's/([a-zA-Z0-9_.\/#@+-]+)\[\]\(([^)]+)\)/[$1]($2)/g' "$file"
      ${markdownlintExe} --config ${mdLintConfig} --fix ":$canon" >/dev/null 2>&1 || true
      if ${markdownlintExe} --config ${mdLintConfig} ":$canon" >/dev/null 2>&1; then
        echo "ok $file"
      else
        echo "issues $file"
      fi
    '';
  };

  piVaultCrawl = pkgs.writeShellApplication {
    name = "pi-vault-crawl";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.curl
      pkgs.gnugrep
      pkgs.perl
      piVaultMd
    ];
    text = ''
      set -euo pipefail

      vault=/obsidian-vault
      crawl_root="$vault/crawl"
      crawl_api=http://127.0.0.1:5678/webhook/crawl4ai-markdown
      md_lint=${lib.getExe piVaultMd}
      max_link_lines=40

      die() { echo "pi-vault-crawl: $1" >&2; exit 1; }

      json_url() {
        local u=$1
        u=''${u//\\/\\\\}
        u=''${u//\"/\\\"}
        printf '%s' "$u"
      }

      url_host_path() {
        local url=$1 n
        n=''${url%%#*}
        n=''${n%%\?*}
        if [[ ! "$n" =~ ^https?://([^/]+)(/.*)?$ ]]; then
          return 1
        fi
        printf '%s\n%s\n' "''${BASH_REMATCH[1]}" "''${BASH_REMATCH[2]:-/}"
      }

      note_path() {
        local url=$1 host path rel
        mapfile -t _hp < <(url_host_path "$url") || return 1
        host=''${_hp[0]}
        path=''${_hp[1]}
        path=''${path#/}
        path=''${path%/}
        if [[ -z "$path" ]]; then
          rel="''${host}/index.md"
        else
          rel="''${host}/''${path}.md"
        fi
        printf '%s/crawl/%s\n' "$vault" "$rel"
      }

      drop_obvious() {
        local low u=$1
        [[ "$u" =~ ^mailto: ]] && return 0
        low=$(printf '%s' "''${u%%\?*}" | tr '[:upper:]' '[:lower:]')
        [[ "$low" =~ \.(png|jpe?g|gif|webp|svg|pdf|zip)(\?|#|$) ]]
      }

      strip_fragment() {
        printf '%s' "''${1%%#*}"
      }

      trim_link() {
        local u=$1 ch
        u=$(strip_fragment "$u")
        while [[ -n "$u" ]]; do
          ch="''${u: -1}"
          case "$ch" in
            ")" | "]" | "." | ",") u="''${u%?}" ;;
            *) break ;;
          esac
        done
        printf '%s' "$u"
      }

      gate_reason() {
        local url=$1 file=$2
        local -a hp=()
        if [[ "$url" == *"/blob/"* ]] || [[ "$url" == *"Special:"* ]] || [[ "$url" == *"index.php"* ]]; then
          printf '%s' "blocked-url-pattern"
          return 0
        fi
        mapfile -t hp < <(url_host_path "$url") || true
        if ((''${#hp[@]} > 0)) && [[ "''${hp[0],,}" == "example.com" ]]; then
          printf '%s' "example-host"
          return 0
        fi
        if [[ ! -s "$file" ]] || (($(wc -c <"$file") < 200)); then
          printf '%s' "too-small"
          return 0
        fi
        if grep -qF 'js_challenge' "$file" 2>/dev/null \
          || grep -qF 'You have been blocked' "$file" 2>/dev/null \
          || grep -qF 'potentially abusive' "$file" 2>/dev/null; then
          printf '%s' "blocked-content"
          return 0
        fi
        if grep -q . "$file" 2>/dev/null; then
          while IFS= read -r line || [[ -n "$line" ]]; do
            if ((''${#line} > 8000)); then
              printf '%s' "long-line"
              return 0
            fi
          done <"$file"
        fi
        return 1
      }

      collect_link_urls() {
        local file=$1
        local -a out=()
        local -A seen=()
        local raw norm
        while IFS= read -r raw; do
          [[ -n "$raw" ]] || continue
          norm=$(trim_link "$raw")
          [[ "$norm" =~ ^https?:// ]] || continue
          drop_obvious "$norm" && continue
          [[ -n "''${seen[$norm]+x}" ]] && continue
          seen["$norm"]=1
          out+=("$norm")
        done < <(grep -oE 'https?://[^[:space:]<>\)"]+' "$file" 2>/dev/null || true)
        if ((''${#out[@]} > 0)); then
          printf '%s\n' "''${out[@]}"
        fi
      }

      print_link_lines() {
        local file=$1
        local -a links=()
        local i=0 u
        mapfile -t links < <(collect_link_urls "$file")
        for u in "''${links[@]}"; do
          echo "link $u"
          i=$((i + 1))
          (( i >= max_link_lines )) && break
        done
      }

      rewrite_obsidian_links() {
        local file=$1
        local canon
        canon=$(readlink -f -- "$file")
        VAULT="$vault" CRAWL_ROOT="$crawl_root" FILE="$canon" ${lib.getExe pkgs.perl} -i -0pe '
          use strict;
          use warnings;
          use File::Spec;
          my $vault = $ENV{VAULT};
          my $crawl = $ENV{CRAWL_ROOT};
          my $file = $ENV{FILE};
          my $dir = (File::Spec->splitpath($file))[1];
          sub url_host_path {
            my ($url) = @_;
            $url =~ s/#.*\z//;
            $url =~ s/\?.*\z//;
            return unless $url =~ m{^https?://([^/]+)(/.*)?$};
            my ($host, $path) = ($1, $2 // "/");
            $path =~ s{^/}{};
            $path =~ s{/$}{};
            my $rel = length($path) ? "$host/$path.md" : "$host/index.md";
            return "$crawl/$rel";
          }
          sub rel {
            my ($dest) = @_;
            return File::Spec->abs2rel($dest, $dir);
          }
          my %map;
          while (m{(https?://[^\s<>\)"]+)}g) {
            my $u = $1;
            my $np = url_host_path($u);
            next unless defined $np && -f $np;
            $map{$u} = rel($np);
          }
          for my $u (sort { length($b) <=> length($a) } keys %map) {
            my $r = $map{$u};
            s~\Q($u)\E~($r)~g;
            s~(?<!\()\Q$u\E(?!\))~[$u]($r)~g;
          }
        ' "$canon"
      }

      check_links_ok() {
        local file=$1
        local canon
        canon=$(readlink -f -- "$file")
        VAULT="$vault" FILE="$canon" ${lib.getExe pkgs.perl} -e '
          use strict;
          use warnings;
          use File::Spec;
          use File::Basename qw(basename fileparse);
          my $vault = $ENV{VAULT};
          my $file = $ENV{FILE};
          my $dir = (File::Spec->splitpath($file))[1];
          open my $fh, "<", $file or exit 1;
          local $/;
          my $body = <$fh>;
          close $fh;
          my $fail = 0;
          while ($body =~ m/\[[^\]]*\]\(([^)]+)\)/g) {
            my $t = $1;
            next if $t =~ m{^https?://};
            my $path = $t;
            $path =~ s/^\s+|\s+$//g;
            next if $path eq "";
            my $abs;
            if (File::Spec->file_name_is_absolute($path)) {
              $abs = File::Spec->rel2abs($path, $vault);
            } else {
              $abs = File::Spec->rel2abs($path, $dir);
            }
            unless (-f $abs) { $fail = 1; last; }
          }
          exit 1 if $fail;
          while ($body =~ m/\[\[([^\]|#]+)(?:#[^\]|]+)?(?:\|[^\]]+)?\]\]/g) {
            my $target = $1;
            $target =~ s/^\s+|\s+$//g;
            next if $target eq "";
            my @hits;
            if ($target =~ m{/}) {
              my $p = "$vault/$target.md";
              push @hits, $p if -f $p;
            } else {
              my $want = lc $target;
              require File::Find;
              File::Find::find({
                wanted => sub {
                  my $fn = $File::Find::name;
                  return unless -f $fn;
                  return unless $fn =~ /\.md\z/;
                  my $base = fileparse($fn, qr/\.md/);
                  push @hits, $fn if lc($base) eq $want;
                },
                no_chdir => 1,
              }, $vault);
            }
            if (@hits != 1) { $fail = 1; last; }
          }
          exit($fail ? 1 : 0);
        '
      }

      links_pass() {
        local file=$1
        rewrite_obsidian_links "$file"
        if check_links_ok "$file"; then
          echo "links ok"
        else
          echo "links fail $file"
        fi
      }

      fetch_page() {
        local url=$1 dest=$2 payload
        payload=$(printf '{"url":"%s","mode":"fit"}' "$(json_url "$url")")
        mkdir -p "$(dirname "$dest")"
        if curl -fsS --max-time 180 -H 'Content-Type: application/json' -d "$payload" -o "$dest" "$crawl_api"; then
          return 0
        fi
        rm -f "$dest"
        return 1
      }

      vault_file_ok() {
        local f=$1
        case "$f" in
          "$vault"/*) ;;
          *) die "file must be under $vault" ;;
        esac
        [[ -f "$f" ]] || die "not a file"
      }

      if [[ $# -eq 1 && "$1" == "--continue" ]]; then
        echo "left 0"
        exit 0
      fi

      if [[ $# -eq 2 && "$1" == "--links" ]]; then
        vault_file_ok "$2"
        links_pass "$2"
        exit 0
      fi

      if [[ $# -ne 1 ]]; then
        die "usage: pi-vault-crawl URL | pi-vault-crawl --continue | pi-vault-crawl --links FILE"
      fi

      url=$1
      dest=$(note_path "$url") || die "bad URL"

      if [[ -f "$dest" ]]; then
        echo "skip $dest"
        print_link_lines "$dest"
        links_pass "$dest"
        echo "left 0"
        exit 0
      fi

      if ! fetch_page "$url" "$dest"; then
        echo "reject $url fetch"
        echo "left 0"
        exit 0
      fi

      "$md_lint" "$dest" >/dev/null 2>&1 || true

      reason=$(gate_reason "$url" "$dest" || true)
      if [[ -n "$reason" ]]; then
        rm -f "$dest"
        echo "reject $url $reason"
        echo "left 0"
        exit 0
      fi

      echo "saved $dest"
      print_link_lines "$dest"
      links_pass "$dest"
      echo "left 0"
    '';
  };

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

    environment.systemPackages = [ piVaultCli piVaultCrawl piVaultMd piVaultKey ];

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
