// Homeport tray companion: shows the existing Homepage dashboard in a window,
// lives in the system tray, and relays ntfy alerts as native notifications.
// See apps/homeport-tray/README.md for the full design.

use std::time::Duration;

use futures_util::StreamExt;
use tauri::{
    image::Image,
    menu::{Menu, MenuItem},
    tray::{MouseButton, MouseButtonState, TrayIconBuilder, TrayIconEvent},
    AppHandle, Manager, WindowEvent,
};
use tauri_plugin_notification::NotificationExt;

const DASHBOARD_WINDOW_LABEL: &str = "main";
const TRAY_ID: &str = "homeport-tray";
const NTFY_BASE_URL: &str = "http://127.0.0.1:8090";

fn main() {
    let start_hidden = std::env::args().any(|arg| arg == "--start-hidden");

    tauri::Builder::default()
        .plugin(tauri_plugin_single_instance::init(|app, _argv, _cwd| {
            focus_dashboard(app);
        }))
        .plugin(tauri_plugin_notification::init())
        .setup(move |app| {
            let app_handle = app.handle().clone();

            if let Some(window) = app.get_webview_window(DASHBOARD_WINDOW_LABEL) {
                if start_hidden {
                    let _ = window.hide();
                }

                let hide_target = window.clone();
                window.on_window_event(move |event| {
                    if let WindowEvent::CloseRequested { api, .. } = event {
                        // Close = minimize to tray, never quit outright.
                        api.prevent_close();
                        let _ = hide_target.hide();
                    }
                });
            }

            build_tray(app)?;
            spawn_ntfy_watcher(app_handle);

            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("error while running homeport-tray");
}

fn focus_dashboard(app: &AppHandle) {
    if let Some(window) = app.get_webview_window(DASHBOARD_WINDOW_LABEL) {
        let _ = window.show();
        let _ = window.set_focus();
    }
}

fn build_tray(app: &tauri::App) -> tauri::Result<()> {
    let show_item = MenuItem::with_id(app, "show", "Show Dashboard", true, None::<&str>)?;
    let reload_item = MenuItem::with_id(app, "reload", "Reload", true, None::<&str>)?;
    let quit_item = MenuItem::with_id(app, "quit", "Quit", true, None::<&str>)?;
    let menu = Menu::with_items(app, &[&show_item, &reload_item, &quit_item])?;

    let normal_icon = tauri::include_image!("icons/tray-normal.png");

    TrayIconBuilder::with_id(TRAY_ID)
        .icon(normal_icon)
        .menu(&menu)
        .show_menu_on_left_click(false)
        .tooltip("Homeport")
        .on_menu_event(|app, event| match event.id.as_ref() {
            "show" => focus_dashboard(app),
            "reload" => {
                if let Some(window) = app.get_webview_window(DASHBOARD_WINDOW_LABEL) {
                    let _ = window.eval("location.reload()");
                }
            }
            "quit" => app.exit(0),
            _ => {}
        })
        .on_tray_icon_event(|tray, event| {
            if let TrayIconEvent::Click {
                button: MouseButton::Left,
                button_state: MouseButtonState::Up,
                ..
            } = event
            {
                let app = tray.app_handle();
                if let Some(window) = app.get_webview_window(DASHBOARD_WINDOW_LABEL) {
                    let visible = window.is_visible().unwrap_or(false);
                    if visible {
                        let _ = window.hide();
                    } else {
                        let _ = window.show();
                        let _ = window.set_focus();
                    }
                }
            }
        })
        .build(app)?;

    Ok(())
}

/// Long-polls ntfy's NDJSON subscribe endpoint for the configured topic and
/// turns each message into a native notification + tray icon status swap.
/// This intentionally does no independent health polling — ntfy (fed by
/// Uptime Kuma) is the single source of truth for "something is down".
fn spawn_ntfy_watcher(app: AppHandle) {
    tauri::async_runtime::spawn(async move {
        let topic = match std::env::var("NTFY_TOPIC") {
            Ok(t) if !t.is_empty() => t,
            _ => {
                eprintln!("homeport-tray: NTFY_TOPIC not set, notifications disabled");
                return;
            }
        };

        let stream_url = format!("{NTFY_BASE_URL}/{topic}/json");
        let normal_icon = tauri::include_image!("icons/tray-normal.png");
        let alert_icon = tauri::include_image!("icons/tray-alert.png");

        loop {
            if let Ok(response) = reqwest::get(&stream_url).await {
                let mut byte_stream = response.bytes_stream();
                let mut buffer: Vec<u8> = Vec::new();

                while let Some(chunk) = byte_stream.next().await {
                    let Ok(bytes) = chunk else { break };
                    buffer.extend_from_slice(&bytes);

                    while let Some(newline_pos) = buffer.iter().position(|byte| *byte == b'\n') {
                        let line: Vec<u8> = buffer.drain(..=newline_pos).collect();
                        handle_ntfy_line(&app, &line, &normal_icon, &alert_icon);
                    }
                }
            }

            // Stream dropped (network hiccup, ntfy restart, etc.) — back off and reconnect.
            tokio::time::sleep(Duration::from_secs(5)).await;
        }
    });
}

fn handle_ntfy_line(app: &AppHandle, line: &[u8], normal_icon: &Image, alert_icon: &Image) {
    let Ok(text) = std::str::from_utf8(line) else {
        return;
    };
    let text = text.trim();
    if text.is_empty() {
        return;
    }

    let Ok(value) = serde_json::from_str::<serde_json::Value>(text) else {
        return;
    };

    // ntfy also emits "open"/"keepalive" control frames on this endpoint; only
    // real published messages should become notifications.
    if value.get("event").and_then(|v| v.as_str()) != Some("message") {
        return;
    }

    let title = value
        .get("title")
        .and_then(|v| v.as_str())
        .unwrap_or("Homeport alert");
    let body = value.get("message").and_then(|v| v.as_str()).unwrap_or("");

    let _ = app.notification().builder().title(title).body(body).show();

    let combined = format!("{title} {body}").to_lowercase();
    let is_down_alert = combined.contains("down");

    if let Some(tray) = app.tray_by_id(TRAY_ID) {
        let icon = if is_down_alert { alert_icon } else { normal_icon };
        let _ = tray.set_icon(Some(icon.clone()));
    }
}
