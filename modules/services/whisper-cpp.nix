{ lib, pkgs, ... }:

let
  whisperModelsDir = "/var/lib/whisper-cpp/models";
  whisperModel = "${whisperModelsDir}/ggml-base.bin";
in
{
  systemd.tmpfiles.rules = [
    "d ${whisperModelsDir} 0755 rileyt users -"
  ];

  environment.systemPackages = [
    pkgs.whisper-cpp
    pkgs.ffmpeg
  ];

  systemd.services.whisper-cpp = {
    description = "whisper.cpp HTTP server";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      DynamicUser = lib.mkForce false;
      User = "rileyt";
      Group = "users";
      WorkingDirectory = whisperModelsDir;
      ExecStartPre = [
        "${pkgs.coreutils}/bin/mkdir -p ${whisperModelsDir}"
        "${pkgs.runtimeShell} -c '${pkgs.coreutils}/bin/test -f ${whisperModel} || ${pkgs.whisper-cpp}/bin/whisper-cpp-download-ggml-model base ${whisperModelsDir}'"
      ];
      ExecStart = "${pkgs.whisper-cpp}/bin/whisper-server --host 127.0.0.1 --port 8081 --inference-path /v1/audio/transcriptions --convert --model ${whisperModel}";
      Restart = "on-failure";
      RestartSec = "5s";
      Environment = [
        # coreutils + gnugrep: the model-download script needs dirname/realpath/grep.
        "PATH=${lib.makeBinPath [ pkgs.ffmpeg pkgs.whisper-cpp pkgs.coreutils pkgs.gnugrep ]}"
      ];
    };
  };
}
