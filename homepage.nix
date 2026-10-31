{ config, ... }:
{
  # Homepage 1.13.1 from homepage-package.nix. nixos-26.05 has 1.12.3,
  # which rejects qBittorrent 5.2's empty login reply. The board in this file is
  # the one declared in the flake. Uptime Kuma stays the alerter; this page
  # only links to it. The module default port is 8082, which is the CPU
  # llama server, so this listens on 3010. openFirewall stays false.
  # Chrome forces HTTPS for *.ts.net, so Tailscale Serve terminates TLS on
  # 3010 and proxies to the loopback port. tailscale-serve.nix installs
  # that route.
  #
  # The module has no listen-address option. The package runs Next.js's
  # standalone server.js, which binds process.env.HOSTNAME or 0.0.0.0.
  # HOSTNAME=127.0.0.1 below is that bind address. Homepage's own source
  # does not read HOSTNAME.
  # https://github.com/NixOS/nixpkgs/blob/6713828a351efa628b025a1adf7f43cbf8597513/nixos/modules/services/misc/homepage-dashboard.nix
  # https://github.com/vercel/next.js/blob/v16.2.4/packages/next/src/build/utils.ts
  # https://gethomepage.dev/installation/#homepage_allowed_hosts
  #
  # Service hrefs are http://127.0.0.1 so the Cinnamon Chrome window opens
  # them on this machine. Widget URLs use the same addresses because
  # Homepage fetches them from here.
  # https://gethomepage.dev/configs/services/
  #
  # 1.13.1 substitutes {{HOMEPAGE_VAR_*}} from an environment variable of
  # that same name. A ${HOMEPAGE_SONARR_KEY} placeholder is left unchanged.
  # The age file holds HOMEPAGE_VAR_SONARR_KEY and the same pattern for
  # Radarr, Lidarr, Prowlarr, Bazarr, Jellyfin, and Seerr. The *arr keys
  # were already in the service config on disk. The Jellyfin key was created
  # in the Jellyfin dashboard, and the Seerr key was copied from Seerr's
  # Settings page. The YAML does not contain them.
  # https://github.com/gethomepage/homepage/blob/v1.13.1/src/utils/config/config.js
  # https://github.com/gethomepage/homepage/blob/v1.13.1/docs/installation/docker.md
  #
  # No API widget for a service whose secret is not already on disk.
  # The qBittorrent widget logs in with the WebUI username and password.
  # 1.13.1 accepts the HTTP 204 login reply from qBittorrent 5.2. It does
  # not send the 5.2 API key. Uptime Kuma's status-page slug is only in
  # its database.
  # Pi-hole's address is only there too, so Pi-hole is not on this board.
  # Those cards use siteMonitor instead: an HTTP check and a status dot.
  # llama.cpp and n8n use their health URLs the same way.
  # https://gethomepage.dev/configs/services/#site-monitor
  # https://gethomepage.dev/widgets/services/sonarr/
  # https://gethomepage.dev/widgets/services/radarr/
  # https://gethomepage.dev/widgets/services/lidarr/
  # https://gethomepage.dev/widgets/services/prowlarr/
  # https://gethomepage.dev/widgets/services/bazarr/
  # https://gethomepage.dev/widgets/services/jellyfin/
  # https://gethomepage.dev/widgets/services/seerr/
  # https://gethomepage.dev/widgets/info/resources/
  age.secrets.homepage-api-keys = {
    file = ./secrets/homepage-api-keys.age;
    mode = "0400";
    owner = "root";
    group = "root";
  };

  services.homepage-dashboard = {
    enable = true;
    openFirewall = false;
    listenPort = 3010;
    allowedHosts = "localhost:3010,127.0.0.1:3010,nixos.taile9f484.ts.net:3010";
    environmentFiles = [ config.age.secrets.homepage-api-keys.path ];
    # Dark and slate match the Cinnamon session. Links open beside this
    # window so the board stays put. The version line and the GitHub update
    # check are this app's own release, not the machine.
    # https://gethomepage.dev/configs/settings/
    settings = {
      title = "nixos";
      theme = "dark";
      color = "slate";
      target = "_blank";
      hideVersion = true;
      disableUpdateCheck = true;
      useEqualHeights = true;
      blockStyle = "refined";
      headerStyle = "boxed";
      statusStyle = "dot";
      quicklaunch.hideInternetSearch = true;
      quicklaunch.searchDescriptions = true;
    };
    # MATRIX theme published by karolhel. Dark and slate stay as they are.
    # The stylesheet loads VT323 and Share Tech Mono from Google Fonts.
    # https://gethomepage.dev/configs/custom-css-js/
    # https://github.com/gethomepage/homepage/discussions/473#discussioncomment-19294810
    customCSS = ''
      /* =====================================================================
         MATRIX theme for gethomepage/homepage
         - green phosphor palette, VT323 / Share Tech Mono fonts
         - dimmed falling code rain BEHIND the tiles (canvas from custom.js)
         - CRT scanlines + vignette, HUD corners, scanner + glitch on hover
         - service down -> tile turns red and pulses
         Use with settings.yaml: theme: dark, color: slate
         Change the accent colour in one place: --mx (R G B)
         ===================================================================== */
      @import url("https://fonts.googleapis.com/css2?family=Share+Tech+Mono&family=VT323&display=swap");
      
      /* whole theme palette -> green phosphor (Homepage colours everything via --color-*) */
      html[class],
      html[class] body {
        --color-50: 230 255 236;
        --color-100: 190 255 205;
        --color-200: 140 255 170;
        --color-300: 80 255 130;
        --color-400: 0 255 65;
        --color-500: 0 220 60;
        --color-600: 0 160 45;
        --color-700: 0 110 30;
        --color-800: 0 40 12;
        --color-900: 0 18 6;
        --mx: 0 255 65;
      }
      
      /* everything ~12% bigger (Homepage's Tailwind sizes are in rem) */
      html {
        font-size: 18px;
      }
      
      html,
      body,
      #__next,
      #page_wrapper,
      #inner_wrapper {
        background: #000 !important;
        background-image: none !important;
      }
      #page_wrapper,
      #inner_wrapper {
        background: transparent !important;
      }
      
      body {
        font-family: "Share Tech Mono", ui-monospace, "Cascadia Mono", Consolas, monospace !important;
        color: rgb(var(--mx));
        text-shadow: 0 0 4px rgb(var(--mx) / 0.45);
      }
      body * {
        font-family: inherit !important;
      }
      
      /* code rain (canvas created by custom.js) */
      #mx-rain {
        position: fixed;
        inset: 0;
        width: 100vw;
        height: 100vh;
        z-index: 0;
        pointer-events: none;
        opacity: 0.32;
      }
      #__next {
        position: relative;
        z-index: 1;
      }
      
      /* CRT scanlines + vignette */
      body::after {
        content: "";
        position: fixed;
        inset: 0;
        z-index: 50;
        pointer-events: none;
        background:
          repeating-linear-gradient(to bottom, rgb(0 0 0 / 0) 0 2px, rgb(0 0 0 / 0.22) 2px 3px),
          radial-gradient(ellipse at center, rgb(0 0 0 / 0) 60%, rgb(0 0 0 / 0.65) 100%);
      }
      
      /* ===== Top bar (information widgets) ===== */
      #information-widgets {
        border: 1px solid rgb(var(--mx) / 0.35);
        background: rgb(0 12 4 / 0.75) !important;
        box-shadow: 0 0 18px rgb(var(--mx) / 0.15), inset 0 0 25px rgb(var(--mx) / 0.06);
        border-radius: 4px;
        backdrop-filter: blur(2px);
      }
      .information-widget-greeting span,
      .information-widget-greeting div {
        font-family: "VT323", monospace !important;
        font-size: 2.4rem !important;
        letter-spacing: 0.08em;
        color: rgb(var(--mx)) !important;
        text-shadow: 0 0 6px rgb(var(--mx)), 0 0 18px rgb(var(--mx) / 0.6);
      }
      .mx-cursor {
        display: inline-block;
        width: 0.55em;
        margin-left: 0.1em;
        background: rgb(var(--mx));
        box-shadow: 0 0 8px rgb(var(--mx));
        animation: mx-blink 1s steps(1) infinite;
      }
      .information-widget-datetime * {
        font-family: "VT323", monospace !important;
      }
      .resource-icon {
        color: rgb(var(--mx)) !important;
        filter: drop-shadow(0 0 3px rgb(var(--mx)));
      }
      
      /* ===== Group headers: terminal prompt + blinking cursor ===== */
      .services-group h2,
      .bookmark-group h2 {
        font-family: "VT323", monospace !important;
        font-size: 1.5rem !important;
        text-transform: uppercase;
        letter-spacing: 0.18em;
        color: rgb(var(--mx)) !important;
      }
      .services-group h2::before {
        content: "root@homelab:~# ";
        color: rgb(var(--mx) / 0.55);
        letter-spacing: 0.02em;
      }
      .services-group h2::after {
        content: "_";
        animation: mx-blink 1s steps(1) infinite;
      }
      
      /* ===== Tiles ===== */
      .service-card {
        position: relative;
        background: rgb(0 10 3 / 0.82) !important;
        border: 1px solid rgb(var(--mx) / 0.28) !important;
        border-radius: 3px !important;
        box-shadow: 0 0 10px rgb(var(--mx) / 0.08), inset 0 0 18px rgb(var(--mx) / 0.04) !important;
        transition: border-color 0.15s, box-shadow 0.15s, transform 0.15s;
        overflow: hidden;
      }
      /* HUD corners */
      .service-card::before {
        content: "";
        position: absolute;
        inset: 0;
        pointer-events: none;
        z-index: 30;
        background:
          linear-gradient(rgb(var(--mx)), rgb(var(--mx))) top left / 10px 2px,
          linear-gradient(rgb(var(--mx)), rgb(var(--mx))) top left / 2px 10px,
          linear-gradient(rgb(var(--mx)), rgb(var(--mx))) bottom right / 10px 2px,
          linear-gradient(rgb(var(--mx)), rgb(var(--mx))) bottom right / 2px 10px;
        background-repeat: no-repeat;
        opacity: 0.8;
      }
      /* scanner line on hover */
      .service-card::after {
        content: "";
        position: absolute;
        left: 0;
        right: 0;
        top: -40%;
        height: 40%;
        pointer-events: none;
        z-index: 29;
        background: linear-gradient(to bottom, rgb(var(--mx) / 0), rgb(var(--mx) / 0.12), rgb(var(--mx) / 0));
        opacity: 0;
      }
      .service-card:hover {
        border-color: rgb(var(--mx) / 0.9) !important;
        box-shadow: 0 0 16px rgb(var(--mx) / 0.45), inset 0 0 22px rgb(var(--mx) / 0.1) !important;
        transform: translateY(-1px);
      }
      .service-card:hover::after {
        opacity: 1;
        animation: mx-scan 1.1s linear infinite;
      }
      .service-card:hover .service-name > :first-child {
        animation: mx-glitch 0.35s steps(2) 1;
      }
      
      .service-name {
        color: rgb(var(--mx)) !important;
        text-transform: uppercase;
        letter-spacing: 0.06em;
      }
      .service-description {
        color: rgb(var(--mx) / 0.6) !important;
        text-transform: none;
        letter-spacing: 0;
      }
      .service-icon img {
        filter: grayscale(1) sepia(1) hue-rotate(70deg) saturate(6) brightness(0.95) drop-shadow(0 0 3px rgb(var(--mx) / 0.7));
      }
      .service-icon svg {
        color: rgb(var(--mx)) !important;
      }
      
      /* widget number blocks */
      .service-block {
        background: rgb(var(--mx) / 0.06) !important;
        border: 1px solid rgb(var(--mx) / 0.15);
        border-radius: 2px !important;
      }
      .service-block-value {
        color: rgb(var(--mx)) !important;
        text-shadow: 0 0 6px rgb(var(--mx) / 0.8);
      }
      .service-block-label {
        color: rgb(var(--mx) / 0.55) !important;
        text-transform: uppercase;
        font-size: 0.65rem !important;
      }
      
      /* Glances charts */
      .service-card .recharts-area-curve {
        stroke: rgb(var(--mx)) !important;
        stroke-width: 1.5px;
        filter: drop-shadow(0 0 3px rgb(var(--mx)));
      }
      .service-card .recharts-area-area {
        fill: rgb(var(--mx) / 0.16) !important;
      }
      .service-card .recharts-area:nth-of-type(2) .recharts-area-curve {
        stroke: #9dffb7 !important;
      }
      
      /* percentage bars (disks, RAM) */
      .service-card [class*="bg-theme-"][style*="width"],
      #information-widgets [style*="width"][class*="bg-"] {
        background: rgb(var(--mx)) !important;
        box-shadow: 0 0 6px rgb(var(--mx));
      }
      
      /* selection + scrollbar */
      ::selection {
        background: rgb(var(--mx));
        color: #000;
      }
      ::-webkit-scrollbar {
        width: 8px;
        background: #000;
      }
      ::-webkit-scrollbar-thumb {
        background: rgb(var(--mx) / 0.4);
      }
      #footer,
      #version {
        opacity: 0.4;
      }
      
      @keyframes mx-blink {
        50% {
          opacity: 0;
        }
      }
      @keyframes mx-scan {
        from {
          top: -40%;
        }
        to {
          top: 100%;
        }
      }
      @keyframes mx-glitch {
        0% {
          transform: translate(0);
          text-shadow: -2px 0 #ff00c8, 2px 0 #00e1ff;
        }
        50% {
          transform: translate(-2px, 1px);
          text-shadow: 2px 0 #ff00c8, -2px 0 #00e1ff;
        }
        100% {
          transform: translate(0);
        }
      }
      
      @media (prefers-reduced-motion: reduce) {
        .service-card:hover::after,
        .mx-cursor,
        .services-group h2::after {
          animation: none;
        }
      }
      
      /* ===== Service down -> red pulsing tile =====
         Homepage colours the status tag: siteMonitor error/HTTP>403 = rose, stopped container = orange */
      .service-card:has(.service-tags [class*="text-rose-"], .service-tags [class*="text-orange-"]) {
        --mx: 255 59 48;
        border-color: rgb(255 59 48 / 0.85) !important;
        background: rgb(30 0 0 / 0.85) !important;
        box-shadow: 0 0 14px rgb(255 59 48 / 0.45), inset 0 0 22px rgb(255 59 48 / 0.12) !important;
        animation: mx-alarm 1.6s ease-in-out infinite;
      }
      .service-card:has(.service-tags [class*="text-rose-"], .service-tags [class*="text-orange-"]) .service-icon img {
        filter: grayscale(1) sepia(1) hue-rotate(-50deg) saturate(6) brightness(0.9) drop-shadow(0 0 3px rgb(255 59 48 / 0.7));
      }
      .service-tags [class*="text-rose-"],
      .service-tags [class*="text-orange-"] {
        color: rgb(255 80 70) !important;
      }
      @keyframes mx-alarm {
        50% {
          box-shadow: 0 0 4px rgb(255 59 48 / 0.2), inset 0 0 10px rgb(255 59 48 / 0.05);
        }
      }
      @media (prefers-reduced-motion: reduce) {
        .service-card {
          animation: none !important;
        }
      }
      
      
      /* download queues (Radarr, Sonarr, qBittorrent): progress bars in theme colour */
      .service-card div.relative.h-5.m-1 {
        height: 1.5rem;
        margin: 0.3rem 0.35rem 0;
        background: rgb(var(--mx) / 0.05) !important;
        border: 1px solid rgb(var(--mx) / 0.18);
        border-radius: 2px;
        overflow: hidden;
      }
      .service-card div.relative.h-5.m-1 > .absolute.h-5 {
        height: 100%;
        margin-left: -0.25rem;
        border-radius: 0;
        background: linear-gradient(90deg, rgb(var(--mx) / 0.12), rgb(var(--mx) / 0.32)) !important;
        box-shadow: inset -2px 0 0 rgb(var(--mx));
      }
      .service-card div.relative.h-5.m-1 .text-xs {
        font-size: 0.72rem;
      }
      /* mdi-* icons (masked div with inline grey gradient) -> green with glow like image icons.
         drop-shadow goes on the parent, on the masked element it would be clipped. Red when the service is down. */
      .service-icon div[style*=mask] {
        background: rgb(var(--mx)) !important;
      }
      .service-icon:has(> div[style*=mask]) {
        filter: drop-shadow(0 0 3px rgb(var(--mx) / 0.7));
      }
      .service-card:not(:has(.chart)) .service-icon div[style*=mask] {
        width: 2.3rem !important;
        height: 2.3rem !important;
      }
      
      
      /* ===== Rain visible behind the tiles, but dimmed ===== */
      #__next {
        background: transparent !important;
      }
      #mx-rain {
        opacity: 0.2;
        filter: brightness(0.8);
      }
      /* shade over the rain: darker in the middle (tiles), livelier at the edges */
      body::before {
        content: "";
        position: fixed;
        inset: 0;
        z-index: 0;
        pointer-events: none;
        background: radial-gradient(ellipse at 50% 40%, rgb(0 0 0 / 0.45) 0%, rgb(0 0 0 / 0.15) 70%, rgb(0 0 0 / 0) 100%);
      }
      /* tiles + top bar: slightly transparent + blur, rain shows through like frosted glass */
      .service-card {
        background: rgb(0 10 3 / 0.72) !important;
        backdrop-filter: blur(3px);
      }
      #information-widgets {
        background: rgb(0 12 4 / 0.7) !important;
        backdrop-filter: blur(3px);
      }
      
      /* ===== Language switch (custom.js) ===== */
      #mx-lang {
        position: fixed;
        top: 6px;
        right: 8px;
        z-index: 60;
        display: flex;
        border: 1px solid rgb(var(--mx) / 0.45);
        border-radius: 3px;
        background: rgb(0 10 3 / 0.85);
        box-shadow: 0 0 10px rgb(var(--mx) / 0.2);
        backdrop-filter: blur(3px);
      }
      #mx-lang button {
        font: 0.8rem/1 "VT323", monospace !important;
        letter-spacing: 0.1em;
        padding: 0.3rem 0.55rem;
        color: rgb(var(--mx) / 0.55);
        background: transparent;
        cursor: pointer;
      }
      #mx-lang button.on {
        color: #000;
        background: rgb(var(--mx));
        text-shadow: none;
      }
      #mx-lang button:not(.on):hover {
        color: rgb(var(--mx));
      }
    '';
    customJS = ''
      // MATRIX theme for gethomepage/homepage - custom.js
      // 1) Language switch MX_NATIVE <-> EN (button top-right)   2) falling code rain behind the page + blinking cursor
      // Respects prefers-reduced-motion (rain = one still frame). Rain pauses when the tab is hidden.
      
      // ---- Language switch MX_NATIVE <-> EN (top-right button, choice stored per browser) ----
      // Set MX_NATIVE to the `language:` from your settings.yaml. EN mode translates the page in the browser using
      // Homepage's own /locales/<lang>/common.json files + MX_DICT below (your own group names, descriptions...).
      const MX_NATIVE = "pl";
      window.MX_LANG = localStorage.getItem("mx-lang") === "en" ? "en" : MX_NATIVE;
      window.MX_DICT = {
        // "Your group name": "English name",
      };
      
      (function () {
        const en = window.MX_LANG === "en";
        if (en) document.documentElement.classList.add("mx-en");
      
        function button() {
          if (document.getElementById("mx-lang")) return;
          const b = document.createElement("div");
          b.id = "mx-lang";
          b.title = "Language";
          [MX_NATIVE, "en"].forEach((l) => {
            const a = document.createElement("button");
            a.type = "button";
            a.textContent = l.toUpperCase();
            if (l === window.MX_LANG) a.className = "on";
            a.onclick = () => {
              if (l === window.MX_LANG) return;
              localStorage.setItem("mx-lang", l);
              location.reload();
            };
            b.appendChild(a);
          });
          document.body.appendChild(b);
        }
      
        if (!en) {
          if (document.body) button();
          else document.addEventListener("DOMContentLoaded", button);
          return;
        }
      
        // ---- EN mode: translate texts on the page ----
        const exact = new Map(Object.entries(window.MX_DICT));
        const patterns = []; // Homepage templates with {{variable}}
        const cache = new Map();
        // weekday / month names in dates
        const words = new Map();
        for (let i = 0; i < 12; i++) {
          const d = new Date(2026, i, 15);
          for (const o of [{ month: "long" }, { month: "short" }]) words.set(d.toLocaleString(MX_NATIVE, o), d.toLocaleString("en", o));
          words.set(new Intl.DateTimeFormat(MX_NATIVE, { day: "numeric", month: "long" }).formatToParts(d).find((p) => p.type === "month").value,
            d.toLocaleString("en", { month: "long" }));
        }
        for (let i = 0; i < 7; i++) {
          const d = new Date(2026, 9, 26 + i);
          for (const o of [{ weekday: "long" }, { weekday: "short" }]) words.set(d.toLocaleString(MX_NATIVE, o), d.toLocaleString("en", o));
        }
        const wordRe = new RegExp("(^|[^\\p{L}])(" + [...words.keys()].sort((a, b) => b.length - a.length).map((w) => w.replace(/[.*+?^''${}()|[\]\\]/g, "\\$&")).join("|") + ")(?=$|[^\\p{L}])", "giu");
      
        const esc = (s) => s.replace(/[.*+?^''${}()|[\]\\]/g, "\\$&");
        const PH = /\{\{\s*([^,}\s]+)[^}]*\}\}/g;
      
        function flat(o, p, out) {
          for (const k in o) typeof o[k] === "object" ? flat(o[k], p + k + ".", out) : (out[p + k] = o[k]);
          return out;
        }
      
        function tr(s) {
          if (cache.has(s)) return cache.get(s);
          let r = exact.get(s);
          if (r === undefined) {
            for (const p of patterns) {
              const m = p.re.exec(s);
              if (m) {
                r = p.en.replace(PH, (_, n) => (m.groups && m.groups[n]) || "");
                break;
              }
            }
          }
          if (r === undefined && FIX.some(([re]) => re.test(s))) r = FIX.reduce((x, [re, to]) => x.replace(re, to), s);
          if (r === undefined && wordRe.test(s)) r = s.replace(wordRe, (_, a, w) => a + (words.get(w.toLowerCase()) || words.get(w) || w));
          wordRe.lastIndex = 0;
          if (cache.size > 5000) cache.clear();
          cache.set(s, r === undefined ? null : r);
          return r === undefined ? null : r;
        }
      
        const hits = new WeakMap();
        // Polish unit leftovers in Homepage formatting (harmless for other languages)
        const FIX = [[/(\d) ?st\. C\b/, "$1 °C"], [/(\d) ?st\. F\b/, "$1 °F"], [/(\d) ?godz\.?/, "$1h"]];
        const SKIP = new Set(["SCRIPT", "STYLE", "TEXTAREA", "INPUT", "CODE"]);
        function textNode(n) {
          const v = n.nodeValue;
          if (!v || !/\p{L}/u.test(v)) return;
          const p = n.parentElement;
          if (!p || SKIP.has(p.tagName) || p.closest("#mx-lang")) return;
          const t = v.trim();
          const r = tr(t);
          if (r && r !== t) {
            // safety: same node translated >20x per second = loop with other code -> leave it
            const now = Date.now(), h = hits.get(n) || { c: 0, t: now };
            if (now - h.t > 1000) (h.c = 0), (h.t = now);
            hits.set(n, h);
            if (++h.c < 20) n.nodeValue = v.replace(t, r);
          }
        }
        function el(e) {
          if (e.nodeType === 3) return textNode(e);
          if (e.nodeType !== 1 || SKIP.has(e.tagName)) return;
          if (e.title) {
            const r = tr(e.title);
            if (r) e.title = r;
          }
          const w = document.createTreeWalker(e, NodeFilter.SHOW_TEXT | NodeFilter.SHOW_ELEMENT);
          let n;
          while ((n = w.nextNode())) {
            if (n.nodeType === 3) textNode(n);
            else if (n.title) {
              const r = tr(n.title);
              if (r) n.title = r;
            }
          }
        }
      
        function run() {
          button();
          el(document.body);
          // safety: >300 mutation batches per second = something loops -> stop translating, page keeps working
          let n = 0, t0 = Date.now();
          const obs = new MutationObserver((ms) => {
            if (Date.now() - t0 > 1000) (n = 0), (t0 = Date.now());
            if (++n > 300) {
              obs.disconnect();
              console.error("mx-lang: mutation loop, translation stopped");
              return;
            }
            for (const m of ms) {
              if (m.type === "characterData") textNode(m.target);
              else if (m.type === "attributes") {
                const r = m.target.title && tr(m.target.title);
                if (r) m.target.title = r;
              } else m.addedNodes.forEach(el);
            }
          });
          obs.observe(document.body, { childList: true, subtree: true, characterData: true, attributes: true, attributeFilter: ["title"] });
        }
      
        // Homepage dictionaries: MX_NATIVE -> en (same key)
        Promise.all([MX_NATIVE, "en"].map((l) => fetch("/locales/" + l + "/common.json").then((r) => r.json())))
          .then(([pl, enj]) => {
            const P = flat(pl, "", {}), E = flat(enj, "", {});
            for (const k in P) {
              const a = P[k], b = E[k];
              if (typeof a !== "string" || typeof b !== "string" || a === b || !/\p{L}/u.test(a.replace(PH, ""))) continue;
              if (!a.includes("{{")) {
                if (!exact.has(a)) exact.set(a, b);
              } else {
                const src = "^" + a.split(PH).map((x, i) => (i % 2 ? "(?<" + x.replace(/\W/g, "_") + ">.+?)" : esc(x))).join("") + "$";
                try {
                  patterns.push({ re: new RegExp(src), en: b.replace(PH, (_, n) => "{{" + n.replace(/\W/g, "_") + "}}") });
                } catch (e) {}
              }
            }
            cache.clear();
          })
          .catch(() => {})
          .finally(() => (document.body ? run() : document.addEventListener("DOMContentLoaded", run)));
      })();
      
      
      // ---- Code rain + cursor ----
      (function () {
        const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
      
        function rain() {
          if (document.getElementById("mx-rain")) return;
          const c = document.createElement("canvas");
          c.id = "mx-rain";
          document.body.prepend(c);
          const ctx = c.getContext("2d");
          const chars = "アイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワン0123456789ABCDEF$#@%&*<>";
          const size = 16;
          let cols = 0;
          let drops = [];
      
          function resize() {
            c.width = window.innerWidth;
            c.height = window.innerHeight;
            cols = Math.ceil(c.width / size);
            drops = Array.from({ length: cols }, () => Math.floor((Math.random() * -c.height) / size));
          }
          resize();
          window.addEventListener("resize", resize);
      
          let last = 0;
          function frame(t) {
            if (!reduced) requestAnimationFrame(frame);
            if (document.hidden || t - last < 50) return; // ~20 fps, enough and keeps the CPU cool
            last = t;
            ctx.fillStyle = "rgba(0, 0, 0, 0.08)";
            ctx.fillRect(0, 0, c.width, c.height);
            ctx.font = size + "px monospace";
            for (let i = 0; i < cols; i++) {
              const y = drops[i] * size;
              ctx.fillStyle = Math.random() > 0.975 ? "#d6ffe0" : "#00ff41";
              ctx.fillText(chars[(Math.random() * chars.length) | 0], i * size, y);
              if (y > c.height && Math.random() > 0.975) drops[i] = 0;
              drops[i]++;
            }
          }
          if (reduced) {
            // prefers-reduced-motion: draw one still frame of rain instead of animating
            const still = () => {
              drops = drops.map(() => Math.floor((Math.random() * c.height) / size));
              for (let k = 0; k < 40; k++) frame(last + 1000);
            };
            window.removeEventListener("resize", resize);
            window.addEventListener("resize", () => { resize(); still(); });
            still();
            return;
          }
          requestAnimationFrame(frame);
        }
      
        function cursor() {
          const g = document.querySelector(".information-widget-greeting span, .information-widget-greeting div > div");
          if (g && !g.querySelector(".mx-cursor")) {
            const s = document.createElement("span");
            s.className = "mx-cursor";
            s.innerHTML = "&nbsp;";
            g.appendChild(s);
          }
        }
      
        function start() {
          rain();
          cursor();
          new MutationObserver(cursor).observe(document.documentElement, { childList: true, subtree: true });
        }
      
        if (document.body) start();
        else document.addEventListener("DOMContentLoaded", start);
      })();
    '';
    # System and Disk are separate meters. CPU temperature may stay blank
    # on this widget; cputemp is still set because that is the published layout.
    # Network rate is on System only. The clock is 24-hour, short time, xl.
    # https://gethomepage.dev/widgets/info/resources/
    # https://gethomepage.dev/widgets/info/datetime/
    # https://github.com/gethomepage/homepage/discussions/3650
    # https://github.com/gethomepage/homepage/discussions/5395
    # https://gist.github.com/Dan6erbond/c20d54d0953af4e4ece22d4464f0841b
    widgets = [
      {
        resources = {
          label = "System";
          cpu = true;
          memory = true;
          uptime = true;
          cputemp = true;
          network = true;
          refresh = 3000;
        };
      }
      {
        resources = {
          label = "Disk";
          expanded = true;
          disk = [
            "/"
            "/vault"
          ];
        };
      }
      {
        datetime = {
          text_size = "xl";
          format = {
            timeStyle = "short";
            hour12 = false;
          };
        };
      }
      {
        # Loopback is HTTP, so coordinates are required.
        # https://gethomepage.dev/widgets/info/openmeteo/
        openmeteo = {
          label = "Muleshoe";
          latitude = 34.22647;
          longitude = -102.72383;
          timezone = "America/Chicago";
          units = "metric";
          cache = 10;
        };
      }
      {
        openmeteo = {
          label = "Canyon";
          latitude = 34.98033;
          longitude = -101.9188;
          timezone = "America/Chicago";
          units = "metric";
          cache = 10;
        };
      }
    ];
    # Calendar is a service widget. It reads the Sonarr, Radarr, and Lidarr
    # widgets already in Media, so it has no API key of its own. 1.13.1
    # accepts type, service_group, and service_name on each integration.
    # https://gethomepage.dev/widgets/services/calendar/
    # https://github.com/epoch-philosophy/homepage-example/blob/main/configuration/services.yaml
    services = [
      {
        Calendar = [
          {
            Calendar = {
              widget = {
                type = "calendar";
                integrations = [
                  {
                    type = "sonarr";
                    service_group = "Media";
                    service_name = "Sonarr";
                  }
                  {
                    type = "radarr";
                    service_group = "Media";
                    service_name = "Radarr";
                  }
                  {
                    type = "lidarr";
                    service_group = "Media";
                    service_name = "Lidarr";
                  }
                ];
              };
            };
          }
        ];
      }
      {
        Media = [
          {
            Seerr = {
              icon = "seerr.png";
              href = "http://127.0.0.1:5055";
              description = "Request a show or movie";
              # https://gethomepage.dev/widgets/services/seerr/
              widget = {
                type = "seerr";
                url = "http://127.0.0.1:5055";
                key = "{{HOMEPAGE_VAR_SEERR_KEY}}";
              };
            };
          }
          {
            Jellyfin = {
              icon = "jellyfin.png";
              href = "http://127.0.0.1:8096";
              description = "Watch and listen";
              # This host runs Jellyfin 10.11.11. Homepage 1.13.1 uses widget
              # version 1 below 10.12, and version 2 from 10.12 on.
              # https://gethomepage.dev/widgets/services/jellyfin/
              widget = {
                type = "jellyfin";
                url = "http://127.0.0.1:8096";
                key = "{{HOMEPAGE_VAR_JELLYFIN_KEY}}";
                version = 1;
                enableBlocks = true;
                enableNowPlaying = true;
              };
            };
          }
          {
            Sonarr = {
              icon = "sonarr.png";
              href = "http://127.0.0.1:8989";
              description = "TV downloads and library";
              widget = {
                type = "sonarr";
                url = "http://127.0.0.1:8989";
                key = "{{HOMEPAGE_VAR_SONARR_KEY}}";
                enableQueue = true;
              };
            };
          }
          {
            Radarr = {
              icon = "radarr.png";
              href = "http://127.0.0.1:7878";
              description = "Movie downloads and library";
              widget = {
                type = "radarr";
                url = "http://127.0.0.1:7878";
                key = "{{HOMEPAGE_VAR_RADARR_KEY}}";
                enableQueue = true;
              };
            };
          }
          {
            Lidarr = {
              icon = "lidarr.png";
              href = "http://127.0.0.1:8686";
              description = "Music downloads and library";
              widget = {
                type = "lidarr";
                url = "http://127.0.0.1:8686";
                key = "{{HOMEPAGE_VAR_LIDARR_KEY}}";
              };
            };
          }
          {
            Bazarr = {
              icon = "bazarr.png";
              href = "http://127.0.0.1:6767";
              description = "Subtitles";
              widget = {
                type = "bazarr";
                url = "http://127.0.0.1:6767";
                key = "{{HOMEPAGE_VAR_BAZARR_KEY}}";
              };
            };
          }
          {
            Prowlarr = {
              icon = "prowlarr.png";
              href = "http://127.0.0.1:9696";
              description = "Indexers";
              widget = {
                type = "prowlarr";
                url = "http://127.0.0.1:9696";
                key = "{{HOMEPAGE_VAR_PROWLARR_KEY}}";
                fields = [ "numberOfGrabs" "numberOfQueries" ];
              };
            };
          }
          {
            qBittorrent = {
              icon = "qbittorrent.png";
              href = "http://127.0.0.1:8080";
              description = "Torrent client";
              # The restarted client is username admin. The other username
              # in the age file is not the one qBittorrent is using.
              # https://github.com/gethomepage/homepage/blob/v1.13.1/src/widgets/qbittorrent/proxy.js
              widget = {
                type = "qbittorrent";
                url = "http://127.0.0.1:8080";
                username = "admin";
                password = "{{HOMEPAGE_VAR_QBITTORRENT_PASSWORD}}";
              };
            };
          }
        ];
      }
      {
        "This computer" = [
          {
            "Open WebUI" = {
              icon = "open-webui.png";
              href = "http://127.0.0.1:8088";
              description = "Chat";
              siteMonitor = "http://127.0.0.1:8088";
            };
          }
          {
            "llama VL" = {
              icon = "mdi-eye-outline";
              href = "http://127.0.0.1:8081";
              description = "LFM3-VL-2B";
              siteMonitor = "http://127.0.0.1:8081/health";
            };
          }
          {
            "llama 1.7B" = {
              icon = "mdi-chip";
              href = "http://127.0.0.1:8082";
              description = "LFM3-1.7B";
              siteMonitor = "http://127.0.0.1:8082/health";
            };
          }
          {
            n8n = {
              icon = "n8n.png";
              href = "http://127.0.0.1:5678";
              description = "Workflows";
              siteMonitor = "http://127.0.0.1:5678/healthz";
            };
          }
          {
            ntfy = {
              icon = "ntfy.png";
              href = "http://127.0.0.1:2586";
              description = "Phone notifications";
              siteMonitor = "http://127.0.0.1:2586";
            };
          }
          {
            Immich = {
              icon = "immich.png";
              href = "http://127.0.0.1:2283";
              description = "Photos and videos";
              siteMonitor = "http://127.0.0.1:2283/api/server/ping";
            };
          }
          {
            "Uptime Kuma" = {
              icon = "uptime-kuma.png";
              href = "http://127.0.0.1:3001";
              description = "Outage checks";
              siteMonitor = "http://127.0.0.1:3001";
            };
          }
          {
            Homarr = {
              icon = "homarr.png";
              href = "http://127.0.0.1:7575";
              description = "Visual board";
              siteMonitor = "http://127.0.0.1:7575";
            };
          }
          {
            # Warnings and criticals come from /api/v1/info. No API key.
            # https://gethomepage.dev/widgets/services/netdata/
            Netdata = {
              icon = "netdata.png";
              href = "http://127.0.0.1:19999/v3";
              description = "CPU, GPU, and disks";
              widget = {
                type = "netdata";
                url = "http://127.0.0.1:19999";
              };
            };
          }
        ];
      }
    ];
  };

  # Next.js standalone server.js: hostname = process.env.HOSTNAME || '0.0.0.0'.
  systemd.services.homepage-dashboard.environment.HOSTNAME = "127.0.0.1";

  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
    3010 # Homepage
  ];
}
