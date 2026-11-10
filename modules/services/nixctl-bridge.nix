# Loopback command bridge for the Discord operator. Read-only commands run
# immediately. Saved commands run immediately. Anything else needs Discord.
{ config, lib, pkgs, ... }:
let
  cfg = config.my.services.nixctl-bridge;
  bridgePy = pkgs.writeText "nixctl-bridge-server.py" ''
    import fcntl
    import json
    import os
    import re
    import subprocess
    from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

    HOST = "127.0.0.1"
    PORT = 8094
    BIN = "/run/current-system/sw/bin"
    ALLOW_PATH = "/var/lib/nixctl-bridge/allowlist.json"
    REPO = "/etc/nixos"
    MAX_OUT = 12000
    MAX_ARGS = 12
    READ_TIMEOUT = 45
    SEARCH_TIMEOUT = 180
    CHANGE_TIMEOUT = 20 * 60

    UNIT_RE = re.compile(
        r"^[A-Za-z0-9@:_-]+(\.(service|socket|timer|mount|target|slice|scope))?$"
    )
    OPT_RE = re.compile(r"^[A-Za-z0-9_.<>*-]+$")
    WORD_RE = re.compile(r"^[A-Za-z0-9_.:@+-]{1,80}$")
    PAGES = ("start", "read", "saved", "suggest", "nixctl")

    # Shell wrappers can hide a second command inside an approved argv.
    BLOCKED = frozenset(
        {
            "sh",
            "bash",
            "dash",
            "zsh",
            "fish",
            "env",
            "sudo",
            "pkexec",
            "busybox",
            "script",
            "nix-shell",
            "nix",
        }
    )

    GUIDES = {
        "start": (
            "Pages: read, saved, suggest, nixctl.\n"
            "run_read inspects this PC and runs immediately.\n"
            "run_saved runs one exact command that was saved earlier. No Approve button.\n"
            "suggest is for anything else. Approve runs it once. A second question saves it.\n"
            "Deny runs nothing. argv is a JSON list of strings. No pipes and no shell."
        ),
        "read": (
            "Call run_read. Examples:\n"
            '["nixctl","status"]\n'
            '["nixctl","logs","n8n.service"]\n'
            '["nixctl","option","services.n8n.enable"]\n'
            '["systemctl","status","n8n.service"]\n'
            '["journalctl","-u","n8n.service","-n","50"]\n'
            '["df","-h"]\n'
            '["free","-h"]\n'
            '["nvidia-smi","-L"]\n'
            '["git","status"]\n'
            '["cat","/etc/nixos/hosts/nixos/default.nix"]\n'
            "nixctl apply is not read-only. Do not use suggest for the examples above."
        ),
        "saved": (
            "run_saved runs an argv that was saved before. It runs immediately.\n"
            "If the result says not saved, call suggest with the same argv.\n"
            "A saved nixctl apply message does not allow a different message."
        ),
        "suggest": (
            "suggest sends the argv to Discord.\n"
            "Deny runs nothing and saves nothing.\n"
            "Approve runs this exact argv once, then asks whether to save it.\n"
            "Saving means the same argv later runs with no Approve button.\n"
            'Example: ["nixctl","rollback"]'
        ),
        "nixctl": (
            "Read-only, use run_read: help, version, status, map, audit, "
            "search WORD, logs UNIT, option NAME.\n"
            "Not read-only, use suggest: check, apply, rollback, undo, clean, "
            "update, pkg, enable, disable, new.\n"
            "check is not read-only because it stages git files."
        ),
    }

    def cap(text):
        text = text or ""
        if len(text) > MAX_OUT:
            return text[:MAX_OUT] + "\n...[output truncated]"
        return text

    def result(ok, output="", error="", kind=""):
        body = {"ok": ok, "output": output, "error": error}
        if kind:
            body["kind"] = kind
        return body

    def reject(error="rejected"):
        return result(False, "", error, "rejected")

    def valid_argv(argv):
        if not isinstance(argv, list) or not (1 <= len(argv) <= MAX_ARGS):
            return None
        clean = []
        for item in argv:
            if not isinstance(item, str) or not (1 <= len(item) <= 200):
                return None
            if any(ch in item for ch in "\n\r\x00|&;<>`$"):
                return None
            clean.append(item)
        name = clean[0]
        if "/" in name or name.startswith("-") or name in BLOCKED:
            return None
        return clean

    def resolve_bin(name):
        path = os.path.join(BIN, name)
        if not os.path.isfile(path) or not os.access(path, os.X_OK):
            return None
        # Profile commands are symlinks into /nix/store. Keep the profile
        # path as argv0 so the script shebang still runs.
        real = os.path.realpath(path)
        if not real.startswith("/nix/store/"):
            return None
        return path

    def timeout_for(argv):
        if argv[0] == "nixctl" and len(argv) > 1:
            if argv[1] in ("apply", "rollback", "undo", "clean", "update"):
                return CHANGE_TIMEOUT
            if argv[1] == "search":
                return SEARCH_TIMEOUT
        return READ_TIMEOUT

    def nixos_path(raw):
        if not isinstance(raw, str) or raw.startswith("-") or not raw.startswith("/etc/nixos"):
            return None
        root = os.path.realpath(REPO)
        real = os.path.realpath(raw)
        if real != root and not real.startswith(root + "/"):
            return None
        parts = os.path.relpath(real, root).split(os.sep)
        if "secrets" in parts or real.endswith(".age"):
            return None
        return real

    def nixctl_read(argv):
        if len(argv) < 2:
            return None
        sub, rest = argv[1], argv[2:]
        if sub in ("help", "version", "status", "map", "audit") and not rest:
            return ["nixctl", sub]
        if sub == "search" and len(rest) == 1 and WORD_RE.fullmatch(rest[0]):
            return ["nixctl", "search", rest[0]]
        if sub == "logs" and len(rest) == 1 and UNIT_RE.fullmatch(rest[0]):
            return ["nixctl", "logs", rest[0]]
        if sub == "option" and len(rest) == 1 and OPT_RE.fullmatch(rest[0]):
            return ["nixctl", "option", rest[0]]
        return None

    def systemctl_read(argv):
        pager_subs = {
            "status",
            "show",
            "list-units",
            "list-unit-files",
            "list-jobs",
            "cat",
        }
        subs = pager_subs | {"is-active", "is-enabled", "is-failed"}
        flags = []
        pos = []
        i = 1
        while i < len(argv):
            arg = argv[i]
            if arg == "--no-pager":
                i += 1
                continue
            if arg in ("--type", "--state", "--property") and i + 1 < len(argv):
                if not WORD_RE.fullmatch(argv[i + 1]):
                    return None
                flags.extend([arg, argv[i + 1]])
                i += 2
                continue
            if arg in (
                "--user",
                "--system",
                "--full",
                "--all",
                "--failed",
                "--plain",
                "--no-legend",
                "--legend",
                "--quiet",
                "-l",
                "-a",
                "-q",
            ):
                flags.append(arg)
                i += 1
                continue
            if arg.startswith("-"):
                return None
            pos.append(arg)
            i += 1
        if not pos or pos[0] not in subs:
            return None
        for unit in pos[1:]:
            if not UNIT_RE.fullmatch(unit):
                return None
        out = ["systemctl", *flags]
        if pos[0] in pager_subs:
            out.append("--no-pager")
        return out + pos

    def journal_read(argv):
        banned = {"-f", "--follow", "--rotate", "--flush", "--sync"}
        out = ["journalctl"]
        saw_lines = False
        i = 1
        while i < len(argv):
            arg = argv[i]
            if arg in banned or arg.startswith("--vacuum"):
                return None
            if arg in ("-n", "--lines") and i + 1 < len(argv):
                if not argv[i + 1].isdigit():
                    return None
                out.extend(["-n", str(min(200, max(1, int(argv[i + 1]))))])
                saw_lines = True
                i += 2
                continue
            if arg.startswith("--lines="):
                number = arg.split("=", 1)[1]
                if not number.isdigit():
                    return None
                out.extend(["-n", str(min(200, max(1, int(number))))])
                saw_lines = True
                i += 1
                continue
            if arg in ("-u", "--unit") and i + 1 < len(argv):
                if not UNIT_RE.fullmatch(argv[i + 1]):
                    return None
                out.extend([arg, argv[i + 1]])
                i += 2
                continue
            if arg in (
                "-b",
                "--no-pager",
                "-o",
                "--output",
                "-p",
                "--priority",
                "--since",
                "--until",
                "-k",
                "--dmesg",
                "-q",
                "--quiet",
                "--no-hostname",
                "-x",
                "--catalog",
            ):
                if arg in ("-o", "--output", "-p", "--priority", "--since", "--until"):
                    if i + 1 >= len(argv) or not WORD_RE.fullmatch(argv[i + 1].lstrip("-")) and arg not in (
                        "--since",
                        "--until",
                    ):
                        if i + 1 >= len(argv):
                            return None
                    if i + 1 >= len(argv) or len(argv[i + 1]) > 80:
                        return None
                    out.extend([arg, argv[i + 1]])
                    i += 2
                    continue
                if arg != "--no-pager":
                    out.append(arg)
                i += 1
                continue
            return None
        if not saw_lines:
            out.extend(["-n", "50"])
        out.append("--no-pager")
        return out

    def flag_command(argv, allowed):
        if any(arg not in allowed for arg in argv[1:]):
            return None
        return argv

    def ip_read(argv):
        banned = {"add", "del", "delete", "set", "change", "replace", "flush", "monitor"}
        if any(arg in banned for arg in argv[1:]):
            return None
        flags = {"-br", "-4", "-6", "-o", "-d", "-h", "-j", "-p", "-s"}
        pos = [arg for arg in argv[1:] if arg not in flags]
        if not pos:
            return None
        obj = {"address": "addr", "a": "addr", "r": "route", "l": "link"}.get(pos[0], pos[0])
        if obj not in ("addr", "route", "link"):
            return None
        rest = pos[1:]
        if rest and rest != ["show"] and rest != ["list"]:
            return None
        return argv

    def nvidia_read(argv):
        i = 1
        while i < len(argv):
            arg = argv[i]
            if arg in ("-pm", "--persistence-mode", "-r", "--gpu-reset", "-pl", "--power-limit", "-c", "--compute-mode"):
                return None
            if arg.startswith("--persistence") or arg.startswith("-pm"):
                return None
            if arg in ("-L", "-q", "--list-gpus", "--help"):
                i += 1
                continue
            if arg.startswith("--query-gpu=") or arg.startswith("--query-compute-apps="):
                if not re.fullmatch(r"--query-[a-z-]+=[A-Za-z0-9_.,]+", arg):
                    return None
                i += 1
                continue
            if arg in ("--format=csv", "--format=csv,noheader", "--format=csv,noheader,nounits"):
                i += 1
                continue
            if arg == "-i" and i + 1 < len(argv) and argv[i + 1].isdigit():
                i += 2
                continue
            return None
        return argv

    def git_read(argv):
        if len(argv) < 2 or argv[1] not in ("status", "log", "diff", "show"):
            return None
        i = 2
        while i < len(argv):
            arg = argv[i]
            if arg in ("--oneline", "--stat", "--name-only", "--name-status", "--shortstat", "-p", "--patch", "-1"):
                i += 1
                continue
            if arg in ("-n", "--max-count") and i + 1 < len(argv) and argv[i + 1].isdigit():
                if int(argv[i + 1]) > 50:
                    return None
                i += 2
                continue
            if re.fullmatch(r"-n\d+", arg) or re.fullmatch(r"--max-count=\d+", arg):
                number = arg.split("n")[-1].split("=")[-1]
                if int(number) > 50:
                    return None
                i += 1
                continue
            if arg.startswith("-") or ".." in arg:
                return None
            if arg.startswith("/") and nixos_path(arg) is None:
                return None
            i += 1
        return argv

    def file_read(argv):
        flags = []
        paths = []
        i = 1
        while i < len(argv):
            arg = argv[i]
            if argv[0] in ("head", "tail") and arg in ("-n", "-c") and i + 1 < len(argv):
                if not argv[i + 1].isdigit():
                    return None
                limit = 200 if arg == "-n" else 100000
                if int(argv[i + 1]) > limit or int(argv[i + 1]) < 1:
                    return None
                flags.extend([arg, argv[i + 1]])
                i += 2
                continue
            if arg.startswith("-"):
                if not re.fullmatch(r"-[lahnsdcwL1]+", arg):
                    return None
                flags.append(arg)
                i += 1
                continue
            path = nixos_path(arg)
            if path is None:
                return None
            paths.append(path)
            i += 1
        if not paths:
            if argv[0] not in ("ls", "du"):
                return None
            paths = [REPO]
        if argv[0] in ("head", "tail") and "-n" not in flags and "-c" not in flags:
            flags.extend(["-n", "80"])
        return [argv[0], *flags, *paths]

    def ps_read(argv):
        for arg in argv[1:]:
            if arg in ("aux", "ax", "ef"):
                continue
            if arg in ("-e", "-f", "-a", "-u", "-x", "-o", "-p", "-C"):
                continue
            if re.fullmatch(r"-[efauxo]+", arg):
                continue
            if re.fullmatch(r"[A-Za-z0-9_,.%:-]+", arg):
                continue
            return None
        return argv

    SIMPLE = {
        "df": {"-h", "-T", "-a", "-l", "--human-readable", "--print-type", "--si", "-P"},
        "free": {"-h", "-m", "-g", "-b", "-w", "--si", "--mega", "--giga", "--human"},
        "uptime": set(),
        "date": set(),
        "uname": {"-a", "-r", "-m", "-s", "-n", "-v", "-o"},
        "hostnamectl": {"status", "--static", "--pretty"},
        "lsblk": {"-f", "-J", "-n", "-b", "-d", "-o", "-a", "-l"},
        "findmnt": {"-A", "-J", "-n", "-t", "-o", "-l", "-D"},
    }

    def readonly(argv):
        name = argv[0]
        if name == "nixctl":
            return nixctl_read(argv)
        if name == "systemctl":
            return systemctl_read(argv)
        if name == "journalctl":
            return journal_read(argv)
        if name == "ip":
            return ip_read(argv)
        if name == "nvidia-smi":
            return nvidia_read(argv)
        if name == "git":
            return git_read(argv)
        if name == "ps":
            return ps_read(argv)
        if name in ("ls", "stat", "wc", "du", "head", "tail", "cat"):
            return file_read(argv)
        if name in SIMPLE:
            return flag_command(argv, SIMPLE[name])
        return None

    def execute(argv, timeout):
        binary = resolve_bin(argv[0])
        if binary is None:
            return reject("no such command")
        try:
            proc = subprocess.run(
                [binary, *argv[1:]],
                capture_output=True,
                text=True,
                timeout=timeout,
                shell=False,
                cwd=REPO,
            )
        except subprocess.TimeoutExpired as exc:
            partial = cap((exc.stdout or "") + (exc.stderr or ""))
            return result(False, partial, "timeout")
        except OSError as exc:
            return result(False, "", str(exc))
        out = cap((proc.stdout or "") + (proc.stderr or ""))
        if proc.returncode != 0:
            return result(False, out, "exit " + str(proc.returncode))
        return result(True, out, "")

    def load_entries(handle):
        raw = handle.read()
        try:
            data = json.loads(raw) if raw.strip() else []
        except json.JSONDecodeError:
            data = []
        if not isinstance(data, list):
            return []
        entries = []
        for item in data:
            cleaned = valid_argv(item)
            if cleaned is not None:
                entries.append(cleaned)
        return entries

    def with_allow(mutate):
        os.makedirs(os.path.dirname(ALLOW_PATH), exist_ok=True)
        fd = os.open(ALLOW_PATH, os.O_RDWR | os.O_CREAT, 0o600)
        with os.fdopen(fd, "r+") as handle:
            fcntl.flock(handle, fcntl.LOCK_EX)
            entries = load_entries(handle)
            changed, value = mutate(entries)
            if changed:
                handle.seek(0)
                handle.truncate()
                json.dump(entries, handle, indent=2)
                handle.write("\n")
                handle.flush()
                os.fsync(handle.fileno())
            return value

    def is_saved(argv):
        def look(entries):
            return False, argv in entries

        return with_allow(look)

    def save_argv(argv):
        def add(entries):
            if argv in entries:
                return False, result(True, "already saved", "", "saved")
            entries.append(argv)
            return True, result(True, "saved", "", "saved")

        return with_allow(add)

    def classify(argv):
        if readonly(argv) is not None:
            return "read"
        if is_saved(argv):
            return "saved"
        if resolve_bin(argv[0]) is None:
            return "rejected"
        return "unknown"

    def handle(body):
        if not isinstance(body, dict):
            return reject()
        op = body.get("op")
        if op == "guide":
            page = body.get("page")
            if page not in GUIDES:
                return reject("unknown page")
            return result(True, GUIDES[page], "", "guide")
        argv = valid_argv(body.get("argv"))
        if argv is None:
            return reject()
        if op == "classify":
            kind = classify(argv)
            if kind == "rejected":
                return reject()
            return result(True, kind, "", kind)
        if op == "read":
            cleaned = readonly(argv)
            if cleaned is None:
                return reject()
            ran = execute(cleaned, timeout_for(cleaned))
            ran["kind"] = "read"
            return ran
        if op == "run":
            if not is_saved(argv):
                return result(False, "", "not saved; use suggest", "unknown")
            ran = execute(argv, timeout_for(argv))
            ran["kind"] = "saved"
            return ran
        if op == "once":
            if resolve_bin(argv[0]) is None:
                return reject("no such command")
            ran = execute(argv, timeout_for(argv))
            ran["kind"] = "once"
            return ran
        if op == "allow":
            if resolve_bin(argv[0]) is None:
                return reject("no such command")
            return save_argv(argv)
        return reject()

    class Handler(BaseHTTPRequestHandler):
        def log_message(self, _fmt, *_args):
            return

        def do_POST(self):
            if self.path != "/run":
                self.send_response(404)
                self.end_headers()
                return
            try:
                length = int(self.headers.get("Content-Length", "0") or 0)
            except ValueError:
                length = -1
            if length < 0 or length > 16384:
                payload = json.dumps(reject()).encode("utf-8")
            else:
                raw = self.rfile.read(length) if length else b"{}"
                try:
                    body = json.loads(raw.decode("utf-8"))
                except (UnicodeDecodeError, json.JSONDecodeError):
                    body = None
                payload = json.dumps(handle(body)).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            try:
                self.wfile.write(payload)
            except BrokenPipeError:
                return

    def main():
        server = ThreadingHTTPServer((HOST, PORT), Handler)
        server.serve_forever()

    if __name__ == "__main__":
        main()
  '';
in
{
  options.my.services.nixctl-bridge.enable = lib.mkEnableOption "Loopback command bridge for the Discord operator.";

  config = lib.mkIf cfg.enable {
    systemd.services.nixctl-bridge = {
      description = "Loopback command bridge for the Discord operator";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      serviceConfig = {
        Type = "simple";
        User = config.my.user;
        Group = "users";
        WorkingDirectory = "/etc/nixos";
        ExecStart = "${pkgs.python3}/bin/python3 ${bridgePy}";
        # The allowlist is state, not config, so a saved command does not
        # need a rebuild. StateDirectory creates the directory for this user.
        StateDirectory = "nixctl-bridge";
        StateDirectoryMode = "0700";
        # User= already sets HOME from the account. Set it explicitly so
        # nixctl's state directory stays under /home/rileyt. There is no
        # systemd Home= key.
        Environment = [
          "HOME=/home/${config.my.user}"
          "PATH=/run/current-system/sw/bin"
        ];
        Restart = "on-failure";
        RestartSec = "5s";
      };
    };
  };
}
