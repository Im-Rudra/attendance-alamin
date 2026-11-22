#include "flutter_window.h"

#include <optional>

#include "flutter/generated_plugin_registrant.h"

// bhor/window (added by tool/platform_patches/apply.py): the title bar follows
// the app theme, set from Dart (lib/app/shell/window_chrome.dart).
#include <dwmapi.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#ifndef DWMWA_USE_IMMERSIVE_DARK_MODE
#define DWMWA_USE_IMMERSIVE_DARK_MODE 20
#endif

namespace {

std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> g_window_channel;

// -1: follow Windows (the template's UpdateTheme); 0: light; 1: dark.
int g_app_dark = -1;

void ApplyAppTitleBar(HWND hwnd) {
  if (hwnd == nullptr || g_app_dark < 0) {
    return;
  }
  BOOL dark = g_app_dark == 1 ? TRUE : FALSE;
  DwmSetWindowAttribute(hwnd, DWMWA_USE_IMMERSIVE_DARK_MODE, &dark, sizeof(dark));
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  // bhor/window setDark(bool) (apply.py).
  g_window_channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "bhor/window",
      &flutter::StandardMethodCodec::GetInstance());
  g_window_channel->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() == "setDark") {
          const bool* dark = std::get_if<bool>(call.arguments());
          if (dark == nullptr) {
            result->Error("bad-args", "setDark expects a bool");
            return;
          }
          g_app_dark = *dark ? 1 : 0;
          ApplyAppTitleBar(GetHandle());
          result->Success();
          return;
        }
        result->NotImplemented();
      });
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  g_window_channel = nullptr;  // apply.py: before the engine goes
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_DWMCOLORIZATIONCOLORCHANGED: {
      // The template re-reads the Windows theme here; keep the app's (apply.py).
      LRESULT handled = Win32Window::MessageHandler(hwnd, message, wparam, lparam);
      ApplyAppTitleBar(hwnd);
      return handled;
    }
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
