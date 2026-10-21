#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

// Custom window message used to request the existing instance to un-hide and restore itself
static const UINT WM_CALLWAVE_SHOW_INSTANCE =
    ::RegisterWindowMessageW(L"CallWave_Show_Single_Instance_Msg");

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Enforce single instance only in Release builds.
  // In Debug mode (flutter run / IDE), we skip the mutex so the Flutter VM
  // service port can always attach without colliding with a tray instance.
#ifndef _DEBUG
  HANDLE hMutex = ::CreateMutexW(nullptr, TRUE, L"CallWave_Single_Instance_Mutex_998811");
  if (::GetLastError() == ERROR_ALREADY_EXISTS) {
    // Notify the existing instance to show and bring itself to the foreground
    ::PostMessageW(HWND_BROADCAST, WM_CALLWAVE_SHOW_INSTANCE, 0, 0);

    // Also look up the Flutter window directly to restore and focus it
    HWND existing_window = ::FindWindowW(L"FLUTTER_RUNNER_WIN32_WINDOW", nullptr);
    if (existing_window) {
      ::ShowWindow(existing_window, SW_SHOW);
      ::ShowWindow(existing_window, SW_RESTORE);
      ::SetForegroundWindow(existing_window);
    }

    if (hMutex) {
      ::CloseHandle(hMutex);
    }
    return EXIT_SUCCESS; // Terminate duplicate instance immediately
  }
#else
  HANDLE hMutex = nullptr; // No mutex in debug builds
#endif

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

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"videocall", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  if (hMutex) {
    ::ReleaseMutex(hMutex);
    ::CloseHandle(hMutex);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
