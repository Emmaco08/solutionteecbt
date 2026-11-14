#include "flutter_window.h"

#include <flutter/standard_method_codec.h>
#include <flutter_windows.h>
#include <shellapi.h>

#include <optional>

#include "flutter/generated_plugin_registrant.h"
#include "resource.h"

namespace {

// Tray icon callback message and id (live notifications, D-166).
constexpr UINT kTrayMessage = WM_APP + 7;
constexpr UINT kTrayId = 1;

std::wstring Wide(const std::string& s) {
  if (s.empty()) return std::wstring();
  const int n = ::MultiByteToWideChar(CP_UTF8, 0, s.data(), static_cast<int>(s.size()), nullptr, 0);
  if (n <= 0) return std::wstring();
  std::wstring w(static_cast<size_t>(n), L'\0');
  ::MultiByteToWideChar(CP_UTF8, 0, s.data(), static_cast<int>(s.size()), &w[0], n);
  return w;
}

std::string Arg(const flutter::EncodableMap& m, const char* key) {
  const auto it = m.find(flutter::EncodableValue(key));
  if (it == m.end()) return std::string();
  if (const auto* s = std::get_if<std::string>(&it->second)) return *s;
  return std::string();
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
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  // Live notifications (lib/core/desktop_alerts.dart): "notify" shows a Windows notification and flashes the taskbar
  // button when the window is not in front, and answers whether it did; the app shows its own toast otherwise.
  desktop_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "solutiontee/desktop",
      &flutter::StandardMethodCodec::GetInstance());
  desktop_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() == "notify") {
          const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
          if (args == nullptr) {
            result->Error("bad_args", "notify needs a map");
            return;
          }
          const bool behind = ::GetForegroundWindow() != GetHandle();
          if (behind) {
            last_id_ = Arg(*args, "id");
            Notify(Wide(Arg(*args, "title")), Wide(Arg(*args, "body")));
            FLASHWINFO flash{};
            flash.cbSize = sizeof(flash);
            flash.hwnd = GetHandle();
            flash.dwFlags = FLASHW_TRAY | FLASHW_TIMERNOFG;
            flash.uCount = 3;
            ::FlashWindowEx(&flash);
          }
          result->Success(flutter::EncodableValue(behind));
        } else {
          result->NotImplemented();
        }
      });

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::Notify(const std::wstring& title, const std::wstring& body) {
  HWND hwnd = GetHandle();
  if (hwnd == nullptr) return;
  HINSTANCE instance = ::GetModuleHandle(nullptr);
  if (!tray_added_) {
    if (small_icon_ == nullptr) {
      small_icon_ = static_cast<HICON>(::LoadImageW(instance, MAKEINTRESOURCEW(IDI_APP_ICON), IMAGE_ICON,
                                                    ::GetSystemMetrics(SM_CXSMICON), ::GetSystemMetrics(SM_CYSMICON), 0));
    }
    NOTIFYICONDATAW add{};
    add.cbSize = sizeof(add);
    add.hWnd = hwnd;
    add.uID = kTrayId;
    add.uFlags = NIF_ICON | NIF_MESSAGE | NIF_TIP | NIF_SHOWTIP;
    add.uCallbackMessage = kTrayMessage;
    add.hIcon = small_icon_;
    wcscpy_s(add.szTip, L"SolutionTee CBT");
    if (!::Shell_NotifyIconW(NIM_ADD, &add)) return;
    tray_hwnd_ = hwnd;
    add.uVersion = NOTIFYICON_VERSION_4;
    ::Shell_NotifyIconW(NIM_SETVERSION, &add);
    tray_added_ = true;
  }
  if (large_icon_ == nullptr) {
    large_icon_ = static_cast<HICON>(::LoadImageW(instance, MAKEINTRESOURCEW(IDI_APP_ICON), IMAGE_ICON,
                                                  ::GetSystemMetrics(SM_CXICON), ::GetSystemMetrics(SM_CYICON), 0));
  }
  NOTIFYICONDATAW info{};
  info.cbSize = sizeof(info);
  info.hWnd = hwnd;
  info.uID = kTrayId;
  info.uFlags = NIF_INFO;
  wcsncpy_s(info.szInfoTitle, title.empty() ? L"SolutionTee CBT" : title.c_str(), _TRUNCATE);
  wcsncpy_s(info.szInfo, body.empty() ? L" " : body.c_str(), _TRUNCATE);
  info.dwInfoFlags = NIIF_USER | NIIF_LARGE_ICON | NIIF_RESPECT_QUIET_TIME;
  info.hBalloonIcon = large_icon_;
  ::Shell_NotifyIconW(NIM_MODIFY, &info);
}

void FlutterWindow::RemoveTray() {
  if (tray_added_) {
    NOTIFYICONDATAW del{};
    del.cbSize = sizeof(del);
    del.hWnd = tray_hwnd_;
    del.uID = kTrayId;
    ::Shell_NotifyIconW(NIM_DELETE, &del);
    tray_added_ = false;
  }
  if (small_icon_ != nullptr) {
    ::DestroyIcon(small_icon_);
    small_icon_ = nullptr;
  }
  if (large_icon_ != nullptr) {
    ::DestroyIcon(large_icon_);
    large_icon_ = nullptr;
  }
}

void FlutterWindow::BringToFront() {
  HWND hwnd = GetHandle();
  if (hwnd == nullptr) return;
  ::ShowWindow(hwnd, ::IsIconic(hwnd) ? SW_RESTORE : SW_SHOW);
  ::SetForegroundWindow(hwnd);
}

void FlutterWindow::OnDestroy() {
  RemoveTray();
  desktop_channel_ = nullptr;
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

  // Explorer restarted: the tray icon is gone and is added again with the next notification.
  static const UINT taskbar_created = ::RegisterWindowMessageW(L"TaskbarCreated");
  if (message == taskbar_created) {
    tray_added_ = false;
  }

  switch (message) {
    // Tray icon and Windows notification clicks (D-166).
    case kTrayMessage:
      switch (LOWORD(lparam)) {
        case NIN_BALLOONUSERCLICK:
          BringToFront();
          if (desktop_channel_) {
            desktop_channel_->InvokeMethod("open", std::make_unique<flutter::EncodableValue>(last_id_));
          }
          return 0;
        case NIN_SELECT:
        case NIN_KEYSELECT:
        case WM_LBUTTONUP:
          BringToFront();
          return 0;
      }
      return 0;
    // Minimum size (D-166): the desktop layout needs about 960 x 640 logical pixels.
    case WM_GETMINMAXINFO: {
      auto info = reinterpret_cast<MINMAXINFO*>(lparam);
      const double scale = FlutterDesktopGetDpiForMonitor(::MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST)) / 96.0;
      info->ptMinTrackSize.x = static_cast<LONG>(960 * scale);
      info->ptMinTrackSize.y = static_cast<LONG>(640 * scale);
      return 0;
    }
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
