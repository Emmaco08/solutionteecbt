#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/encodable_value.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>

#include <memory>
#include <string>

#include "win32_window.h"

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  // Live notifications (D-166): "solutiontee/desktop" channel, a tray icon and Windows notifications.
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> desktop_channel_;
  bool tray_added_ = false;
  HWND tray_hwnd_ = nullptr;  // kept: GetHandle() is already null in OnDestroy
  HICON small_icon_ = nullptr;
  HICON large_icon_ = nullptr;
  std::string last_id_;

  void Notify(const std::wstring& title, const std::wstring& body);
  void RemoveTray();
  void BringToFront();
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
