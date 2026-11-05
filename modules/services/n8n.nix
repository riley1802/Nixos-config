# n8n workflow editor. Web page on port 5678.
{ config, lib, pkgs, ... }:
let
  cfg = config.my.services.n8n;
  # n8n 2.34.6 generates Zod schemas as *.schema.js, then the Nix package
  # deletes every *.ts file. The MCP resolver only opens *.ts, so node
  # definitions such as Postgres disappear. This copy keeps the same build
  # and adds a relative link for each schema. It does not rebuild n8n.
  mcpNodeTypes = pkgs.runCommand "${pkgs.n8n.name}-mcp-node-types"
    {
      nativeBuildInputs = [
        pkgs.coreutils
        pkgs.findutils
      ];
      meta = pkgs.n8n.meta;
      passthru = pkgs.n8n.passthru or { };
    }
    ''
      cp -a --reflink=auto ${pkgs.n8n}/. "$out/"

      # The installed launcher contains the original output path. Point it at
      # this copy so Node resolves packages containing the compatibility links.
      chmod u+w "$out/bin/n8n"
      substituteInPlace "$out/bin/n8n" \
        --replace-fail '${pkgs.n8n}' "$out"

      while IFS= read -r -d "" source; do
        # Copied store directories are mode 555. The builder is not root, so
        # the directory must be writable before the link can be created.
        chmod u+w "$(dirname "$source")"
        target="''${source%.schema.js}.ts"
        ln -s "$(basename "$source")" "$target"
      done < <(
        find "$out/lib/n8n" \
          -type f \
          -path "*/dist/node-definitions/*" \
          -name "*.schema.js" \
          -print0
      )
    '';
  # Discord voice messages are Opus in an Ogg file. LFM3-Omni's llama.cpp
  # audio input accepts wav, mp3, and flac. Breeze returns wav from
  # POST /v1/audio/speech. n8n's Code node cannot run ffmpeg, so this
  # loopback service converts both ways.
  # POST / returns 16 kHz mono wav. POST /discord-voice returns the Ogg Opus
  # file Discord will show as a voice memo, plus duration and waveform.
  audioToWav = pkgs.writeScript "audio-to-wav.py" ''
    #!${pkgs.python3}/bin/python3
    import base64
    import json
    import struct
    import subprocess
    from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

    FFMPEG = "${pkgs.ffmpeg}/bin/ffmpeg"
    MAX_BYTES = 25 * 1024 * 1024

    def ffmpeg(data, args):
        return subprocess.run(
            [FFMPEG, "-hide_banner", "-loglevel", "error", "-i", "pipe:0"] + args,
            input=data,
            capture_output=True,
            timeout=120,
            check=False,
        )

    def discord_voice(data):
        pcm = ffmpeg(data, ["-ar", "48000", "-ac", "1", "-f", "s16le", "pipe:1"])
        ogg = ffmpeg(data, [
            "-ar", "48000", "-ac", "1", "-c:a", "libopus", "-b:a", "48k",
            "-application", "voip", "-frame_duration", "20", "-f", "ogg", "pipe:1",
        ])
        if pcm.returncode != 0 or ogg.returncode != 0 or not ogg.stdout:
            return None
        raw = pcm.stdout
        count = len(raw) // 2
        samples = struct.unpack("<" + ("h" * count), raw[:count * 2]) if count else ()
        buckets = 256
        wave = bytearray(buckets)
        if samples:
            size = max(1, len(samples) // buckets)
            for index in range(buckets):
                chunk = samples[index * size:(index + 1) * size] or (0,)
                peak = max(abs(sample) for sample in chunk)
                wave[index] = min(255, int(peak * 255 / 32768))
        body = json.dumps({
            "ogg_base64": base64.b64encode(ogg.stdout).decode("ascii"),
            "duration_secs": round(len(samples) / 48000.0, 3),
            "waveform": base64.b64encode(wave).decode("ascii"),
        }).encode("utf-8")
        return body

    class Handler(BaseHTTPRequestHandler):
        protocol_version = "HTTP/1.1"

        def do_POST(self):
            raw = self.headers.get("Content-Length")
            if raw is None:
                self.send_error(411, "Content-Length required")
                return
            try:
                size = int(raw)
            except ValueError:
                self.send_error(400, "Bad Content-Length")
                return
            if size <= 0 or size > MAX_BYTES:
                self.send_error(413, "Audio is empty or larger than 25 MB")
                return
            data = self.rfile.read(size)
            path = self.path.split("?", 1)[0]
            try:
                if path == "/discord-voice":
                    body = discord_voice(data)
                    if body is None:
                        self.send_error(422, "Could not make a Discord voice memo")
                        return
                    content_type = "application/json"
                else:
                    result = ffmpeg(data, [
                        "-ar", "16000", "-ac", "1", "-c:a", "pcm_s16le", "-f", "wav", "pipe:1",
                    ])
                    if result.returncode != 0 or not result.stdout:
                        self.send_error(422, "Could not convert that audio to wav")
                        return
                    body = result.stdout
                    content_type = "audio/wav"
            except subprocess.TimeoutExpired:
                self.send_error(408, "Conversion timed out")
                return
            self.send_response(200)
            self.send_header("Content-Type", content_type)
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def do_GET(self):
            if self.path != "/health":
                self.send_error(404)
                return
            body = b"ok\n"
            self.send_response(200)
            self.send_header("Content-Type", "text/plain")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def log_message(self, fmt, *args):
            return

    ThreadingHTTPServer(("127.0.0.1", 8091), Handler).serve_forever()
  '';
in
{
  options.my.services.n8n.enable = lib.mkEnableOption "n8n";

  config = lib.mkIf cfg.enable {
    # n8n 2.34.6 from the nixos-26.05 module. The editor listens on loopback.
    # Chrome's HSTS list upgrades http://*.ts.net to HTTPS on the same port,
    # so Tailscale Serve terminates TLS on 5678 and proxies here.
    # tailscale-serve.nix installs that route. 5678 is free: 8080 is
    # qBittorrent, 8081 and 8082 are llama.cpp, and 8088 is Open WebUI.
    #
    # The owner account, workflows, SQLite database, and the generated
    # encryption key live in /var/lib/n8n. That directory is not in git.
    #
    # LFM3-1.7B is the OpenAI-compatible server on 127.0.0.1:8082. n8n
    # cannot take that URL or the API key from an environment variable, and
    # a credential import needs the owner account created on first login.
    # After that login, add one OpenAI credential:
    #   API key: the single line in /run/agenix/llama-api-key
    #            (pkexec cat /run/agenix/llama-api-key)
    #   Base URL: http://127.0.0.1:8082/v1
    #   Organization ID: empty
    # On an OpenAI or OpenAI Chat Model node, the model id is lfm3-1.7b.
    # Leave "Use Responses API" off. llama-server rejects /v1 without that
    # key. /health stays open. LFM3-Omni-2B on 8081 is the voice model.
    # A workflow that hears Discord voice memos posts the audio file to
    # http://127.0.0.1:8091/ and sends the wav to
    # http://127.0.0.1:8081/v1/chat/completions with model id lfm3-omni.
    # The spoken reply comes from Breeze at
    # http://127.0.0.1:8084/v1/audio/speech (OpenAI-style JSON,
    # response_format wav). POST that wav to
    # http://127.0.0.1:8091/discord-voice for the Discord voice-memo file.
    # The voice-or-text delivery choice is POST http://127.0.0.1:8086/v1/systemone
    # with model alias d1-2b.
    # The 1.7B server has one slot and is shared with Open WebUI, so a
    # workflow waits if a chat is already generating. The Omni server has
    # one slot too.
    # https://github.com/NixOS/nixpkgs/blob/6713828a351efa628b025a1adf7f43cbf8597513/nixos/modules/services/misc/n8n.nix
    # https://docs.n8n.io/hosting/configuration/environment-variables/
    services.n8n = {
      enable = true;
      package = mcpNodeTypes;
      openFirewall = false;
      environment = {
        N8N_LISTEN_ADDRESS = "127.0.0.1";
        N8N_PORT = 5678;
        N8N_PROTOCOL = "https";
        N8N_HOST = config.my.tailnetHost;
        # 2.34.6 still accepts WEBHOOK_URL and warns to use this name instead.
        N8N_WEBHOOK_URL = "https://${config.my.tailnetHost}:5678/";
        N8N_EDITOR_BASE_URL = "https://${config.my.tailnetHost}:5678/";
        # Tailscale Serve sets X-Forwarded-Proto. One hop is that proxy.
        N8N_PROXY_HOPS = 1;
        # Stays false so a login at http://127.0.0.1:5678 still works. The
        # Secure flag would drop that cookie because loopback is HTTP.
        # Tailnet access is HTTPS through Tailscale Serve.
        N8N_SECURE_COOKIE = false;
      };
    };

    # A workflow notifies the phone with an HTTP Request node: POST the
    # message body to http://127.0.0.1:2586/n8n and send the publisher token
    # from /run/agenix/ntfy-passwords as Authorization: Bearer. The token and
    # the topic are set up in ntfy.nix. n8n has no notification of its own
    # until a workflow posts one.
    # https://docs.ntfy.sh/publish/
    # https://docs.n8n.io/integrations/builtin/core-nodes/n8n-nodes-base.httprequest/

    # Start after the model when it is present. Do not require it, so n8n
    # still comes up if the GGUF is missing.
    systemd.services.audio-to-wav = {
      description = "Convert posted audio to 16 kHz mono WAV";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = audioToWav;
        DynamicUser = true;
        Restart = "on-failure";
        RestartSec = 2;
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
      };
    };

    systemd.services.n8n = {
      after = [
        "llama-cpp-1.7b.service"
        "llama-cpp-omni.service"
        "llama-cpp-d1.service"
        "audio-to-wav.service"
      ];
      wants = [
        "llama-cpp-1.7b.service"
        "llama-cpp-omni.service"
        "llama-cpp-d1.service"
        "audio-to-wav.service"
      ];
    };

    networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
      5678 # n8n
    ];
  };
}
