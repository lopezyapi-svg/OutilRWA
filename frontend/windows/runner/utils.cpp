#include "utils.h"

#include <winsock2.h>
#include <ws2tcpip.h>

#include <flutter_windows.h>
#include <io.h>
#include <stdio.h>
#include <windows.h>

#include <chrono>
#include <filesystem>
#include <iostream>
#include <string>
#include <thread>

#pragma comment(lib, "Ws2_32.lib")

namespace {

constexpr wchar_t kBackendHost[] = L"127.0.0.1";
constexpr unsigned short kBackendPort = 8001;
constexpr auto kBackendStartupTimeout = std::chrono::seconds(15);
constexpr auto kBackendPollInterval = std::chrono::milliseconds(150);

HANDLE g_backend_process = nullptr;
bool g_backend_started_by_runner = false;

std::filesystem::path GetExecutableDirectory() {
  wchar_t buffer[MAX_PATH];
  const DWORD length = ::GetModuleFileNameW(nullptr, buffer, MAX_PATH);
  if (length == 0 || length == MAX_PATH) {
    return std::filesystem::current_path();
  }
  return std::filesystem::path(std::wstring(buffer, length)).parent_path();
}

std::filesystem::path GetBackendLogPath() {
  wchar_t* local_app_data = nullptr;
  size_t required_size = 0;
  if (_wdupenv_s(&local_app_data, &required_size, L"LOCALAPPDATA") != 0 ||
      local_app_data == nullptr) {
    return GetExecutableDirectory() / L"backend.log";
  }

  std::filesystem::path log_path =
      std::filesystem::path(local_app_data) / L"Risk management" / L"logs" /
      L"backend.log";
  free(local_app_data);
  return log_path;
}

std::filesystem::path GetBackendLaunchLogPath() {
  return GetBackendLogPath().parent_path() / L"backend-launch.log";
}

bool IsBackendReachable() {
  WSADATA wsa_data;
  if (::WSAStartup(MAKEWORD(2, 2), &wsa_data) != 0) {
    return false;
  }

  SOCKET socket_handle = ::socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
  if (socket_handle == INVALID_SOCKET) {
    ::WSACleanup();
    return false;
  }

  u_long non_blocking = 1;
  if (::ioctlsocket(socket_handle, FIONBIO, &non_blocking) != 0) {
    ::closesocket(socket_handle);
    ::WSACleanup();
    return false;
  }

  sockaddr_in address = {};
  address.sin_family = AF_INET;
  address.sin_port = htons(kBackendPort);
  if (::InetPtonW(AF_INET, kBackendHost, &address.sin_addr) != 1) {
    ::closesocket(socket_handle);
    ::WSACleanup();
    return false;
  }

  const int connect_result = ::connect(
      socket_handle, reinterpret_cast<sockaddr*>(&address), sizeof(address));
  if (connect_result == SOCKET_ERROR) {
    const int connect_error = ::WSAGetLastError();
    if (connect_error != WSAEWOULDBLOCK && connect_error != WSAEINPROGRESS &&
        connect_error != WSAEINVAL) {
      ::closesocket(socket_handle);
      ::WSACleanup();
      return false;
    }
  } else {
    ::closesocket(socket_handle);
    ::WSACleanup();
    return true;
  }

  fd_set write_set;
  FD_ZERO(&write_set);
  FD_SET(socket_handle, &write_set);

  timeval timeout = {};
  timeout.tv_sec = 0;
  timeout.tv_usec = 250 * 1000;

  const int select_result =
      ::select(0, nullptr, &write_set, nullptr, &timeout);
  if (select_result <= 0) {
    ::closesocket(socket_handle);
    ::WSACleanup();
    return false;
  }

  int socket_error = 0;
  int option_length = sizeof(socket_error);
  const int option_result =
      ::getsockopt(socket_handle, SOL_SOCKET, SO_ERROR,
                   reinterpret_cast<char*>(&socket_error), &option_length);

  ::closesocket(socket_handle);
  ::WSACleanup();
  return option_result == 0 && socket_error == 0;
}

std::wstring BuildBackendCommandLine(
    const std::filesystem::path& python_executable,
    const std::filesystem::path& server_script) {
  return L"\"" + python_executable.wstring() + L"\" \"" +
         server_script.wstring() + L"\"";
}

}  // namespace

void CreateAndAttachConsole() {
  if (::AllocConsole()) {
    FILE *unused;
    if (freopen_s(&unused, "CONOUT$", "w", stdout)) {
      _dup2(_fileno(stdout), 1);
    }
    if (freopen_s(&unused, "CONOUT$", "w", stderr)) {
      _dup2(_fileno(stdout), 2);
    }
    std::ios::sync_with_stdio();
    FlutterDesktopResyncOutputStreams();
  }
}

std::vector<std::string> GetCommandLineArguments() {
  // Convert the UTF-16 command line arguments to UTF-8 for the Engine to use.
  int argc;
  wchar_t** argv = ::CommandLineToArgvW(::GetCommandLineW(), &argc);
  if (argv == nullptr) {
    return std::vector<std::string>();
  }

  std::vector<std::string> command_line_arguments;

  // Skip the first argument as it's the binary name.
  for (int i = 1; i < argc; i++) {
    command_line_arguments.push_back(Utf8FromUtf16(argv[i]));
  }

  ::LocalFree(argv);

  return command_line_arguments;
}

std::string Utf8FromUtf16(const wchar_t* utf16_string) {
  if (utf16_string == nullptr) {
    return std::string();
  }
  unsigned int target_length = ::WideCharToMultiByte(
      CP_UTF8, WC_ERR_INVALID_CHARS, utf16_string,
      -1, nullptr, 0, nullptr, nullptr)
    -1; // remove the trailing null character
  int input_length = (int)wcslen(utf16_string);
  std::string utf8_string;
  if (target_length == 0 || target_length > utf8_string.max_size()) {
    return utf8_string;
  }
  utf8_string.resize(target_length);
  int converted_length = ::WideCharToMultiByte(
      CP_UTF8, WC_ERR_INVALID_CHARS, utf16_string,
      input_length, utf8_string.data(), target_length, nullptr, nullptr);
  if (converted_length == 0) {
    return std::string();
  }
  return utf8_string;
}

bool EnsureBackendServerRunning(std::wstring* error_message) {
  if (IsBackendReachable()) {
    return true;
  }

  const std::filesystem::path install_directory = GetExecutableDirectory();
  const std::filesystem::path backend_root = install_directory / L"backend";
  const std::filesystem::path python_directory = backend_root / L"python";
  const std::filesystem::path python_executable = python_directory / L"python.exe";
  const std::filesystem::path server_script =
      backend_root / L"src" / L"run_server.py";
  const std::filesystem::path launch_log_path = GetBackendLaunchLogPath();
  const std::wstring python_executable_string = python_executable.wstring();

  if (!std::filesystem::exists(python_executable)) {
    if (error_message != nullptr) {
      *error_message =
          L"Runtime Python embarque introuvable: " + python_executable.wstring();
    }
    return false;
  }

  if (!std::filesystem::exists(server_script)) {
    if (error_message != nullptr) {
      *error_message =
          L"Lanceur backend introuvable: " + server_script.wstring();
    }
    return false;
  }

  ::SetEnvironmentVariableW(L"RWA_PACKAGED", L"1");
  ::SetEnvironmentVariableW(L"RWA_API_HOST", kBackendHost);
  ::SetEnvironmentVariableW(L"RWA_API_PORT", L"8001");
  ::SetEnvironmentVariableW(L"RWA_API_LOG_LEVEL", L"warning");
  ::SetEnvironmentVariableW(L"PYTHONUTF8", L"1");

  std::error_code create_directories_error;
  std::filesystem::create_directories(launch_log_path.parent_path(),
                                      create_directories_error);

  SECURITY_ATTRIBUTES security_attributes = {};
  security_attributes.nLength = sizeof(security_attributes);
  security_attributes.bInheritHandle = TRUE;
  security_attributes.lpSecurityDescriptor = nullptr;

  HANDLE log_handle = ::CreateFileW(
      launch_log_path.wstring().c_str(),
      FILE_APPEND_DATA,
      FILE_SHARE_READ | FILE_SHARE_WRITE,
      &security_attributes,
      OPEN_ALWAYS,
      FILE_ATTRIBUTE_NORMAL,
      nullptr);
  if (log_handle == INVALID_HANDLE_VALUE) {
    if (error_message != nullptr) {
      *error_message =
          L"Impossible d'ouvrir le journal backend: " +
          launch_log_path.wstring();
    }
    return false;
  }

  HANDLE null_handle = ::CreateFileW(
      L"NUL",
      GENERIC_READ | GENERIC_WRITE,
      FILE_SHARE_READ | FILE_SHARE_WRITE,
      &security_attributes,
      OPEN_EXISTING,
      FILE_ATTRIBUTE_NORMAL,
      nullptr);
  if (null_handle == INVALID_HANDLE_VALUE) {
    ::CloseHandle(log_handle);
    if (error_message != nullptr) {
      *error_message =
          L"Impossible d'initialiser le canal standard du backend.";
    }
    return false;
  }

  std::wstring command_line =
      BuildBackendCommandLine(python_executable, server_script);
  std::vector<wchar_t> mutable_command_line(command_line.begin(),
                                            command_line.end());
  mutable_command_line.push_back(L'\0');

  STARTUPINFOW startup_info = {};
  startup_info.cb = sizeof(startup_info);
  startup_info.dwFlags = STARTF_USESHOWWINDOW | STARTF_USESTDHANDLES;
  startup_info.wShowWindow = SW_HIDE;
  startup_info.hStdInput = null_handle;
  startup_info.hStdOutput = log_handle;
  startup_info.hStdError = log_handle;

  PROCESS_INFORMATION process_information = {};
  const BOOL create_result = ::CreateProcessW(
      python_executable_string.c_str(),
      mutable_command_line.data(),
      nullptr,
      nullptr,
      TRUE,
      CREATE_NO_WINDOW,
      nullptr,
      python_directory.wstring().c_str(),
      &startup_info,
      &process_information);

  ::CloseHandle(null_handle);
  ::CloseHandle(log_handle);

  if (!create_result) {
    if (error_message != nullptr) {
      *error_message =
          L"Impossible de demarrer le backend embarque (code Win32 " +
          std::to_wstring(::GetLastError()) + L"). Consultez: " +
          launch_log_path.wstring();
    }
    return false;
  }

  ::CloseHandle(process_information.hThread);
  g_backend_process = process_information.hProcess;
  g_backend_started_by_runner = true;

  const auto deadline = std::chrono::steady_clock::now() + kBackendStartupTimeout;
  while (std::chrono::steady_clock::now() < deadline) {
    if (IsBackendReachable()) {
      return true;
    }

    DWORD wait_result = ::WaitForSingleObject(g_backend_process, 0);
    if (wait_result == WAIT_OBJECT_0) {
      DWORD exit_code = 0;
      ::GetExitCodeProcess(g_backend_process, &exit_code);
      if (error_message != nullptr) {
        *error_message =
            L"Le backend embarque s'est arrete au demarrage (code " +
            std::to_wstring(exit_code) + L"). Consultez: " +
            launch_log_path.wstring();
      }
      StopManagedBackendServer();
      return false;
    }

    std::this_thread::sleep_for(kBackendPollInterval);
  }

  if (error_message != nullptr) {
    *error_message =
        L"Le backend embarque ne repond pas sur 127.0.0.1:8001. Consultez: " +
        launch_log_path.wstring();
  }
  StopManagedBackendServer();
  return false;
}

void StopManagedBackendServer() {
  if (!g_backend_started_by_runner || g_backend_process == nullptr) {
    return;
  }

  DWORD exit_code = 0;
  if (::GetExitCodeProcess(g_backend_process, &exit_code) &&
      exit_code == STILL_ACTIVE) {
    ::TerminateProcess(g_backend_process, 0);
    ::WaitForSingleObject(g_backend_process, 2000);
  }

  ::CloseHandle(g_backend_process);
  g_backend_process = nullptr;
  g_backend_started_by_runner = false;
}
