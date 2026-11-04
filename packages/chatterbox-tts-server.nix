# Server script for Chatterbox Turbo; run with /var/lib/chatterbox/venv/bin/python.
{ pkgs }:
pkgs.writeTextFile {
  name = "chatterbox-tts-server.py";
  text = builtins.readFile ./chatterbox-tts-server.py;
}
