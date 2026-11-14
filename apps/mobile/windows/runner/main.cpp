#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter_windows.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // One window only (D-166): a second launch brings the open window to the front.
  HANDLE single = ::CreateMutexW(nullptr, TRUE, L"SolutionTeeCBT.SingleInstance");
  if (single != nullptr && ::GetLastError() == ERROR_ALREADY_EXISTS) {
    HWND open = ::FindWindowW(L"FLUTTER_RUNNER_WIN32_WINDOW", L"SolutionTee CBT");
    if (open != nullptr) {
      ::ShowWindow(open, ::IsIconic(open) ? SW_RESTORE : SW_SHOW);
      ::SetForegroundWindow(open);
    }
    return EXIT_SUCCESS;
  }

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  // Size the window to the screen (laptops are often 1366 x 768): up to 1360 x 860, centred in the work area;
  // small screens start maximised.
  RECT work{};
  ::SystemParametersInfoW(SPI_GETWORKAREA, 0, &work, 0);
  const POINT centre{(work.left + work.right) / 2, (work.top + work.bottom) / 2};
  const double scale = FlutterDesktopGetDpiForMonitor(::MonitorFromPoint(centre, MONITOR_DEFAULTTONEAREST)) / 96.0;
  const int work_w = static_cast<int>((work.right - work.left) / scale);
  const int work_h = static_cast<int>((work.bottom - work.top) / scale);
  const int w = work_w - 40 < 1360 ? work_w - 40 : 1360;
  const int h = work_h - 40 < 860 ? work_h - 40 : 860;
  const bool maximise = work_w < 1400 || work_h < 820;

  FlutterWindow window(project);
  // Shown on the first frame (flutter_window.cpp), maximised when the screen is small.
  window.SetStartMaximised(maximise);
  Win32Window::Point origin(static_cast<int>(work.left / scale) + (work_w - w) / 2, static_cast<int>(work.top / scale) + (work_h - h) / 2);
  Win32Window::Size size(w, h);
  if (!window.Create(L"SolutionTee CBT", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
