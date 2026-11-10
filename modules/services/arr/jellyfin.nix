# Jellyfin media player. Web page on port 8096.
{ config, lib, pkgs, ... }:
let
  cfg = config.my.services.arr.jellyfin;

  # KDE uses the NVIDIA card. Transcode must use the Intel iGPU by PCI path
  # so Jellyfin does not pick an NVIDIA render node (there are three).
  intelRender = "/dev/dri/by-path/pci-0000:00:02.0-render";
  encodingXml = "/var/lib/jellyfin/config/encoding.xml";

  jellyfinEncodingPreStart = pkgs.writeShellScript "jellyfin-sync-encoding-xml" ''
    set -euo pipefail
    conf=${encodingXml}
    mkdir -p "$(dirname "$conf")"
    ${pkgs.python3}/bin/python3 <<'PY'
    import os
    import xml.etree.ElementTree as ET

    conf = os.environ["JELLYFIN_ENCODING_XML"]
    intel_render = os.environ["JELLYFIN_INTEL_RENDER"]
    required_codecs = ("h264", "hevc", "vp9", "av1")

    NS_XSI = "http://www.w3.org/2001/XMLSchema-instance"
    NS_XSD = "http://www.w3.org/2001/XMLSchema"
    ET.register_namespace("xsi", NS_XSI)
    ET.register_namespace("xsd", NS_XSD)

    def new_root():
        root = ET.Element("EncodingOptions")
        root.attrib["xmlns:xsi"] = NS_XSI
        root.attrib["xmlns:xsd"] = NS_XSD
        return root

    def set_bool(parent, tag, value):
        el = parent.find(tag)
        if el is None:
            el = ET.SubElement(parent, tag)
        el.text = "true" if value else "false"

    def set_text(parent, tag, text):
        el = parent.find(tag)
        if el is None:
            el = ET.SubElement(parent, tag)
        el.text = text

    def ensure_codecs(parent):
        el = parent.find("HardwareDecodingCodecs")
        if el is None:
            el = ET.SubElement(parent, "HardwareDecodingCodecs")
        existing = {s.text for s in el.findall("string") if s.text}
        for codec in required_codecs:
            if codec not in existing:
                ET.SubElement(el, "string").text = codec

    if os.path.isfile(conf):
        tree = ET.parse(conf)
        root = tree.getroot()
    else:
        root = new_root()
        tree = ET.ElementTree(root)

    set_text(root, "HardwareAccelerationType", "qsv")
    set_text(root, "QsvDevice", intel_render)
    set_text(root, "VaapiDevice", intel_render)
    set_bool(root, "EnableHardwareEncoding", True)
    set_bool(root, "AllowAv1Encoding", True)
    ensure_codecs(root)

    tree.write(conf, encoding="utf-8", xml_declaration=True)
    PY
    # preStart runs as User=jellyfin; chown needs root and would fail the unit.
    chmod u+rw,go+r "$conf" 2>/dev/null || true
    echo "jellyfin encoding: HardwareAccelerationType=qsv QsvDevice=${intelRender} VaapiDevice=${intelRender} AllowAv1Encoding=true"
  '';
in
{
  options.my.services.arr.jellyfin.enable = lib.mkEnableOption "Jellyfin";

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.my.services.arr.media.enable;
        message = "services/arr/jellyfin needs services/arr/media (nixctl enable services/arr/media)";
      }
    ];

    hardware.graphics.enable = true;
    hardware.graphics.extraPackages = with pkgs; [
      intel-media-driver
      vpl-gpu-rt
      intel-compute-runtime
    ];

    services.jellyfin = {
      enable = true;
      openFirewall = false;
      group = "media";
    };

    users.users.jellyfin.extraGroups = [ "render" "video" ];

    systemd.services.jellyfin = {
      environment = {
        LIBVA_DRIVER_NAME = "iHD";
        LIBVA_DRIVERS_PATH = "/run/opengl-driver/lib/dri";
        ONEVPL_SEARCH_PATH = "/run/opengl-driver/lib";
        OCL_ICD_VENDORS = "${pkgs.intel-compute-runtime}/etc/OpenCL/vendors";
      };
      preStart = lib.mkAfter ''
        export JELLYFIN_ENCODING_XML=${encodingXml}
        export JELLYFIN_INTEL_RENDER=${intelRender}
        ${jellyfinEncodingPreStart}
      '';
    };

    # The module sets its own umask. 0002 lets the media group write new files.
    systemd.services.jellyfin.serviceConfig.UMask = lib.mkForce "0002";
    # The module's TimeoutSec=15 also covers shutdown. The library is on
    # the USB disk. Killing Jellyfin at 15 seconds leaves its database
    # half written, and the next boot opens a broken library.
    systemd.services.jellyfin.serviceConfig.TimeoutStopSec = "2min";

    networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
      8096 # Jellyfin. The home LAN rule below is also intentional.
    ];
    networking.firewall.interfaces.${config.my.lanInterface}.allowedTCPPorts = [
      # Home Wi-Fi playback is intentional. Players on the LAN use
      # http://192.168.50.101:8096. Tailnet clients use tailscale0.
      # The VPN interface stays closed.
      8096
    ];
  };
}
