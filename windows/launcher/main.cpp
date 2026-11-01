#include "runner.h"
#include "preferences.h"
#include <shellapi.h>
using namespace dt;
static BackgroundRunner runner;
static NOTIFYICONDATAW tray{sizeof(tray)};
static std::wstring statusText = L"DiaTweaks: waiting for Dia";
static void open_dia() {
    ShellExecuteW(nullptr, L"open", L"shell:AppsFolder\\TheBrowserCompany.Dia_ttt1ap7aakyb4!Dia", nullptr, nullptr, SW_SHOWNORMAL);
}
static LRESULT CALLBACK window_proc(HWND window, UINT message, WPARAM wp, LPARAM lp) {
    if (message == BackgroundRunner::Status) {
        const wchar_t* texts[] = {L"Waiting for Dia", L"Connected - open Dia Settings", L"Patches ready in Dia Settings",
            L"Quit/reopen Dia to load this build", L"Preferences/error - see launcher.log"};
        statusText = wp < 5 ? texts[wp] : texts[4];
        wcsncpy_s(tray.szTip, statusText.c_str(), _TRUNCATE); Shell_NotifyIconW(NIM_MODIFY, &tray);
        return 0;
    }
    if (message == WM_APP + 1) {
        if (lp == WM_LBUTTONDBLCLK) { open_dia(); return 0; }
        if (lp == WM_RBUTTONUP || lp == WM_CONTEXTMENU) {
            HMENU menu = CreatePopupMenu();
            AppendMenuW(menu, MF_STRING | MF_DISABLED, 0, statusText.c_str());
            AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);
            AppendMenuW(menu, MF_STRING, 1, L"Open Dia");
            AppendMenuW(menu, MF_STRING, 2, L"Edit patch preferences");
            AppendMenuW(menu, MF_STRING, 3, L"Turn all patches off");
            AppendMenuW(menu, MF_STRING, 4, L"Quit DiaTweaks");
            POINT point{}; GetCursorPos(&point); SetForegroundWindow(window);
            const auto command = TrackPopupMenu(menu, TPM_RETURNCMD | TPM_NONOTIFY, point.x, point.y, 0, window, nullptr);
            DestroyMenu(menu);
            if (command == 1) open_dia();
            if (command == 2) {
                try { auto path = preferences_path(); if (!std::filesystem::exists(path)) save_preferences(path, 0);
                    ShellExecuteW(window, L"open", path.c_str(), nullptr, nullptr, SW_SHOWNORMAL);
                } catch (...) {}
            }
            if (command == 3) runner.reset = true;
            if (command == 4) DestroyWindow(window);
        }
        return 0;
    }
    if (message == WM_DESTROY) { runner.stop = true; Shell_NotifyIconW(NIM_DELETE, &tray); PostQuitMessage(0); return 0; }
    return DefWindowProcW(window, message, wp, lp);
}
int WINAPI wWinMain(HINSTANCE instance, HINSTANCE, PWSTR commandLine, int) {
    const auto com = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
    try {
        wchar_t executable[32768]{}; if (!GetModuleFileNameW(nullptr, executable, 32768)) throw last_error();
        const auto folder = std::filesystem::path(executable).parent_path();
        if (std::wstring(commandLine) == L"--self-test") {
            return std::filesystem::is_regular_file(folder / L"DiaTweaksTap.dll") ? 0 : 2;
        }
        if (!std::filesystem::is_regular_file(folder / L"DiaTweaksTap.dll")) throw HRESULT_FROM_WIN32(ERROR_FILE_NOT_FOUND);
        Handle singleton(CreateMutexW(nullptr, FALSE, L"Local\\DiaTweaks.BackgroundController"));
        if (!singleton || GetLastError() == ERROR_ALREADY_EXISTS) return 0;
        WNDCLASSW wc{}; wc.lpfnWndProc = window_proc; wc.hInstance = instance; wc.lpszClassName = L"DiaTweaks.Tray";
        if (!RegisterClassW(&wc)) throw last_error();
        runner.window = CreateWindowExW(0, wc.lpszClassName, L"DiaTweaks", 0, 0, 0, 0, 0, HWND_MESSAGE, nullptr, instance, nullptr);
        if (!runner.window) throw last_error();
        tray.hWnd = runner.window; tray.uID = 1; tray.uFlags = NIF_ICON | NIF_MESSAGE | NIF_TIP;
        tray.uCallbackMessage = WM_APP + 1; tray.hIcon = LoadIconW(nullptr, IDI_APPLICATION);
        wcscpy_s(tray.szTip, L"DiaTweaks: waiting for Dia");
        if (!Shell_NotifyIconW(NIM_ADD, &tray)) throw last_error();
        Handle thread(CreateThread(nullptr, 0, [](void*) -> DWORD { return runner.run(); }, nullptr, 0, nullptr));
        if (!thread) throw last_error();
        open_dia();
        MSG message{};
        while (GetMessageW(&message, nullptr, 0, 0) > 0) { TranslateMessage(&message); DispatchMessageW(&message); }
        runner.stop = true; WaitForSingleObject(thread.value, 30000);
    } catch (...) { MessageBoxW(nullptr, L"DiaTweaks could not start. Extract the complete ZIP and run DiaTweaks.exe again.", L"DiaTweaks", MB_OK | MB_ICONERROR); return 1; }
    if (SUCCEEDED(com)) CoUninitialize();
    return 0;
}
