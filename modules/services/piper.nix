{ lib, pkgs, ... }:

let
  piperVoicesDir = "/var/lib/piper/voices";
  defaultVoice = "en_US-lessac-medium";
  piperHttpServer = pkgs.writeTextFile {
    name = "piper-http-server.py";
    executable = true;
    text = ''
      #!/usr/bin/env python3
      import json
      import subprocess
      from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
      from pathlib import Path

      HOST = "127.0.0.1"
      PORT = 8082
      VOICES_DIR = Path("${piperVoicesDir}")
      DEFAULT_VOICE = "${defaultVoice}"
      PIPER_BIN = "${pkgs.piper-tts}/bin/piper"


      def list_voices() -> list[str]:
          return sorted(model.stem for model in VOICES_DIR.glob("*.onnx"))


      def resolve_model(voice: str | None) -> Path | None:
          requested = (voice or "").strip()
          if requested:
              candidate = Path(requested)
              if candidate.suffix != ".onnx":
                  candidate = candidate.with_suffix(".onnx")
              if not candidate.is_absolute():
                  candidate = VOICES_DIR / candidate.name
              if candidate.exists():
                  return candidate
              return None

          default_path = VOICES_DIR / f"{DEFAULT_VOICE}.onnx"
          if default_path.exists():
              return default_path

          first_voice = next(iter(sorted(VOICES_DIR.glob("*.onnx"))), None)
          return first_voice


      class PiperHandler(BaseHTTPRequestHandler):
          def _send_json(self, status: int, payload: dict) -> None:
              body = json.dumps(payload).encode("utf-8")
              self.send_response(status)
              self.send_header("Content-Type", "application/json")
              self.send_header("Content-Length", str(len(body)))
              self.end_headers()
              self.wfile.write(body)

          def _read_json_body(self) -> dict | None:
              content_length = int(self.headers.get("Content-Length", "0"))
              if content_length <= 0:
                  return None
              raw = self.rfile.read(content_length)
              return json.loads(raw.decode("utf-8"))

          def do_GET(self) -> None:
              if self.path == "/health":
                  voices = list_voices()
                  self._send_json(
                      200,
                      {
                          "status": "ok",
                          "host": HOST,
                          "port": PORT,
                          "voices": voices,
                      },
                  )
                  return

              if self.path == "/voices":
                  self._send_json(200, {"voices": list_voices()})
                  return

              self._send_json(404, {"error": "not found"})

          def do_POST(self) -> None:
              if self.path not in ["/", "/synthesize", "/v1/audio/speech"]:
                  self._send_json(404, {"error": "not found"})
                  return

              try:
                  payload = self._read_json_body() or {}
              except json.JSONDecodeError:
                  self._send_json(400, {"error": "invalid JSON body"})
                  return

              text = str(payload.get("text", "")).strip()
              if not text:
                  self._send_json(400, {"error": "text is required"})
                  return

              model_path = resolve_model(payload.get("voice"))
              if model_path is None:
                  self._send_json(
                      503,
                      {
                          "error": "voice model not found",
                          "voices_dir": str(VOICES_DIR),
                      },
                  )
                  return

              cmd = [PIPER_BIN, "--model", str(model_path)]
              for key, flag in [
                  ("speaker_id", "--speaker"),
                  ("length_scale", "--length-scale"),
                  ("noise_scale", "--noise-scale"),
                  ("noise_w_scale", "--noise-w-scale"),
                  ("sentence_silence", "--sentence-silence"),
                  ("volume", "--volume"),
              ]:
                  value = payload.get(key)
                  if value is not None:
                      cmd.extend([flag, str(value)])

              if payload.get("cuda", False):
                  cmd.append("--cuda")

              process = subprocess.run(
                  cmd,
                  input=text.encode("utf-8"),
                  stdout=subprocess.PIPE,
                  stderr=subprocess.PIPE,
                  check=False,
              )

              if process.returncode != 0:
                  self._send_json(
                      500,
                      {
                          "error": "piper synthesis failed",
                          "details": process.stderr.decode("utf-8", errors="replace"),
                      },
                  )
                  return

              self.send_response(200)
              self.send_header("Content-Type", "audio/wav")
              self.send_header("Content-Length", str(len(process.stdout)))
              self.end_headers()
              self.wfile.write(process.stdout)


      def main() -> None:
          VOICES_DIR.mkdir(parents=True, exist_ok=True)
          server = ThreadingHTTPServer((HOST, PORT), PiperHandler)
          server.serve_forever()


      if __name__ == "__main__":
          main()
    '';
  };
in
{
  systemd.tmpfiles.rules = [
    "d ${piperVoicesDir} 0755 rileyt users -"
  ];

  environment.systemPackages = [
    pkgs.piper-tts
  ];

  systemd.services.piper = {
    description = "Piper local HTTP TTS server";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      DynamicUser = lib.mkForce false;
      User = "rileyt";
      Group = "users";
      WorkingDirectory = piperVoicesDir;
      ExecStart = "${pkgs.python3}/bin/python ${piperHttpServer}";
      Restart = "on-failure";
      RestartSec = "5s";
    };
  };
}
