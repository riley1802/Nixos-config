# Kokoro-82M TTS on the CPU. Loopback HTTP on port 8087.
{ config, lib, pkgs, ... }:
let
  cfg = config.my.services.kokoro;
  data = "/var/lib/kokoro";
  port = 8087;
  # Median of three runs on 2026-11-04, voice af_heart, 24 kHz, device cpu,
  # one warmup discarded. The short line is 46 characters and 3.275 s of
  # audio. The long passage is 1015 characters plus a trailing newline
  # (1016 counted) and 59.7 s of audio, in three chunks. Real-time factor
  # is audio seconds divided by wall seconds. Peak RSS was about 1968 MiB.
  #
  # threads  short wall  long wall  long first audio  long RTF
  #  4       0.646 s     14.191 s   6.449 s           4.21
  #  8       0.520 s     10.845 s   4.932 s           5.51
  # 12       0.442 s      9.824 s   4.643 s           6.08
  # 16       0.424 s      9.340 s   4.334 s           6.39
  # 20       1.711 s     11.392 s   4.669 s           5.24
  #  8 on performance cores 0-7: short 1.037 s, long 12.167 s, RTF 4.91
  #
  # 16 threads won. 20 was slower than 8, so the pin run was required, and
  # it lost as well. https://huggingface.co/hexgrad/Kokoro-82M
  cpuThreads = 16;
  pythonEnv = pkgs.python3.withPackages (ps: [
    ps.kokoro
    ps.spacy-models.en_core_web_sm
  ]);
  server = pkgs.writeScript "kokoro-tts.py" ''
    #!${pythonEnv}/bin/python3
    import io
    import json
    import os
    import re
    import sys
    import threading
    import wave
    from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

    os.environ["CUDA_VISIBLE_DEVICES"] = ""
    os.environ.setdefault("HF_HUB_DISABLE_XET", "1")
    os.environ["TOKENIZERS_PARALLELISM"] = "false"

    import numpy as np
    import torch

    threads = int(os.environ["KOKORO_THREADS"])
    torch.set_num_threads(threads)
    try:
      torch.set_num_interop_threads(1)
    except RuntimeError:
      pass

    from loguru import logger

    logger.remove()
    from kokoro import KModel, KPipeline

    REPO = "hexgrad/Kokoro-82M"
    RATE = 24000
    DEFAULT_VOICE = "af_heart"
    MAX_CHARS = 5000
    MAX_BYTES = 1024 * 1024
    VOICE_NAME = re.compile(r"[a-z]{1,2}_[a-z0-9]{1,24}")
    HOST = "127.0.0.1"
    PORT = int(os.environ["KOKORO_PORT"])

    model = KModel(repo_id=REPO).to("cpu").eval()
    if not str(model.device).startswith("cpu"):
      print("kokoro model is not on cpu: %s" % model.device, file=sys.stderr)
      sys.exit(1)
    pipelines = {
      "a": KPipeline(lang_code="a", repo_id=REPO, model=model),
    }
    speak_lock = threading.Lock()


    def pipeline_for(voice):
      lang = "b" if voice.startswith("b") else "a"
      if lang not in pipelines:
        pipelines[lang] = KPipeline(lang_code=lang, repo_id=REPO, model=model)
      return pipelines[lang]


    def synthesize(text, voice):
      chunks = []
      with speak_lock:
        pipeline = pipeline_for(voice)
        for result in pipeline(text, voice=voice, speed=1):
          audio = result.audio
          if audio is None:
            continue
          chunks.append(audio.detach().cpu().float().numpy().reshape(-1))
      if not chunks:
        return None
      return np.concatenate(chunks)


    def wav_bytes(samples):
      pcm = np.clip(samples, -1.0, 1.0)
      pcm = (pcm * 32767.0).astype(np.int16)
      buf = io.BytesIO()
      with wave.open(buf, "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(RATE)
        handle.writeframes(pcm.tobytes())
      return buf.getvalue()


    with torch.inference_mode():
      synthesize("Hello.", DEFAULT_VOICE)
    print("kokoro ready device=cpu threads=%d" % threads, flush=True)


    class Handler(BaseHTTPRequestHandler):
      protocol_version = "HTTP/1.1"

      def send_json(self, code, payload):
        body = json.dumps(payload).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

      def do_GET(self):
        if self.path.split("?", 1)[0] != "/health":
          self.send_json(404, {"error": "not found"})
          return
        self.send_json(200, {
          "model_id": REPO,
          "device": "cpu",
          "voice": DEFAULT_VOICE,
        })

      def do_POST(self):
        if self.path.split("?", 1)[0] != "/v1/audio/speech":
          self.send_json(404, {"error": "not found"})
          return
        raw = self.headers.get("Content-Length")
        if raw is None:
          self.send_json(411, {"error": "Content-Length required"})
          return
        try:
          size = int(raw)
        except ValueError:
          self.send_json(400, {"error": "bad Content-Length"})
          return
        if size <= 0 or size > MAX_BYTES:
          self.send_json(413, {"error": "body is empty or larger than 1 MB"})
          return
        try:
          payload = json.loads(self.rfile.read(size))
        except json.JSONDecodeError:
          self.send_json(400, {"error": "body is not JSON"})
          return
        if not isinstance(payload, dict):
          self.send_json(400, {"error": "body must be a JSON object"})
          return
        text = payload.get("input")
        if not isinstance(text, str) or not text.strip():
          self.send_json(400, {"error": "input must be text"})
          return
        if len(text) > MAX_CHARS:
          self.send_json(413, {"error": "input is longer than 5000 characters"})
          return
        voice = payload.get("voice", DEFAULT_VOICE)
        if not isinstance(voice, str) or VOICE_NAME.fullmatch(voice) is None:
          self.send_json(400, {"error": "voice must look like af_heart"})
          return
        if payload.get("response_format", "wav") != "wav":
          self.send_json(400, {"error": "response_format must be wav"})
          return
        try:
          with torch.inference_mode():
            samples = synthesize(text, voice)
        except (BrokenPipeError, ConnectionResetError):
          return
        except Exception as exc:
          print("kokoro synthesis failed: %s" % exc, file=sys.stderr, flush=True)
          self.send_json(500, {"error": "synthesis failed"})
          return
        if samples is None or samples.size == 0:
          self.send_json(422, {"error": "no audio"})
          return
        body = wav_bytes(samples)
        self.send_response(200)
        self.send_header("Content-Type", "audio/wav")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        try:
          self.wfile.write(body)
        except (BrokenPipeError, ConnectionResetError):
          return

      def log_message(self, fmt, *args):
        return


    ThreadingHTTPServer((HOST, PORT), Handler).serve_forever()
  '';
in
{
  options.my.services.kokoro.enable = lib.mkEnableOption "Kokoro-82M TTS (CPU)";

  config = lib.mkIf cfg.enable {
    # hexgrad/Kokoro-82M through the nixpkgs kokoro package (CPU torch,
    # espeak-ng paths already patched into misaki). Weights download into
    # HF_HOME. The benchmark cache is copied once when this directory is
    # still empty, so the first boot does not fetch them again. XET
    # downloads have stalled on this machine.
    # https://github.com/hexgrad/kokoro
    # https://github.com/NixOS/nixpkgs/blob/nixos-26.05/pkgs/development/python-modules/kokoro/default.nix
    users.groups.kokoro = { };
    users.users.kokoro = {
      isSystemUser = true;
      group = "kokoro";
      home = data;
      createHome = true;
    };

    systemd.tmpfiles.settings.kokoro = {
      "${data}".d = {
        mode = "0755";
        user = "kokoro";
        group = "kokoro";
      };
      "${data}/huggingface".d = {
        mode = "0755";
        user = "kokoro";
        group = "kokoro";
      };
    };

    system.activationScripts.kokoro-weights = {
      deps = [ "users" "groups" ];
      text = ''
        install -d -o kokoro -g kokoro -m 0755 ${data} ${data}/huggingface
        src=/var/tmp/kokoro-bench/huggingface
        if [[ -d $src/hub && ! -d ${data}/huggingface/hub ]]; then
          ${pkgs.rsync}/bin/rsync -a "$src/" ${data}/huggingface/
          chown -R kokoro:kokoro ${data}/huggingface
        fi
      '';
    };

    systemd.services.kokoro = {
      description = "Kokoro-82M TTS (CPU)";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      environment = {
        CUDA_VISIBLE_DEVICES = "";
        HF_HUB_DISABLE_XET = "1";
        HF_HUB_DISABLE_PROGRESS_BARS = "1";
        HF_HOME = "${data}/huggingface";
        KOKORO_THREADS = toString cpuThreads;
        KOKORO_PORT = toString port;
        OMP_NUM_THREADS = toString cpuThreads;
        MKL_NUM_THREADS = toString cpuThreads;
        OPENBLAS_NUM_THREADS = toString cpuThreads;
      };
      serviceConfig = {
        User = "kokoro";
        Group = "kokoro";
        WorkingDirectory = data;
        ExecStart = server;
        Restart = "on-failure";
        RestartSec = 5;
        TimeoutStartSec = "10min";
        # Same CPU-process exceptions as the llama 1.7B unit. PyTorch needs
        # writable executable pages. No GPU nodes are required.
        MemoryDenyWriteExecute = false;
        PrivateUsers = false;
        PrivateDevices = true;
      };
    };

    networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
      port # Kokoro-82M
    ];
  };
}
