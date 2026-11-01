#include "runner.h"
#include "preferences.h"
#include "target.h"
#include "channel.h"
#include <fstream>
#include <sstream>
namespace dt {
DWORD BackgroundRunner::run() noexcept {
    const auto com = CoInitializeEx(nullptr, COINIT_MULTITHREADED);
    try {
        check(com);
        const auto prefs = preferences_path();
        const auto logPath = prefs.parent_path() / L"launcher.log";
        std::filesystem::create_directories(prefs.parent_path());
        auto log = [&](const std::wstring& message) { std::wofstream out(logPath, std::ios::app); out << message << L'\n'; };
        auto status = [&](unsigned code) { PostMessageW(window, Status, code, 0); };
        wchar_t executable[32768]{}; if (!GetModuleFileNameW(nullptr, executable, 32768)) throw last_error();
        auto dll = std::filesystem::path(executable).parent_path() / L"DiaTweaksTap.dll";
        if (!std::filesystem::is_regular_file(dll)) throw HRESULT_FROM_WIN32(ERROR_FILE_NOT_FOUND);
        while (!stop) {
            try {
                if (reset.exchange(false)) save_preferences(prefs, 0);
                const auto target = find_target(0);
                Handle process(OpenProcess(SYNCHRONIZE, FALSE, target.pid)); if (!process) throw last_error();
                PreferencesSync preferences(prefs);
                Channel channel(target.pid); channel.shared->options = AutoSettings; channel.shared->initialFeatureMask = preferences.mask();
                check(attach(target, dll, channel.name));
                const auto deadline = GetTickCount64() + 10000;
                while (!stop && !read_flag(channel.shared->ready) && GetTickCount64() < deadline) Sleep(25);
                if (read_flag(channel.shared->ready) != 1) throw HRESULT_FROM_WIN32(ERROR_TIMEOUT);
                status(1); log(L"Attached; open Dia Settings for Patches.");
                while (!stop && WaitForSingleObject(process.value, 0) == WAIT_TIMEOUT) {
                    const auto previous = preferences.mask();
                    std::optional<uint32_t> desired;
                    try { desired = preferences.incoming(reset.exchange(false)); }
                    catch (...) { status(4); log(L"Invalid/unreadable preferences; current session retained."); }
                    if (desired) {
                        std::wstring response;
                        for (uint32_t i = 0; i < static_cast<uint32_t>(FeatureId::Count) && !stop; ++i) if (((*desired ^ previous) & (1u << i)) != 0)
                            check(channel.call({Command::SetFeature, i, (*desired & (1u << i)) ? 1u : 0u}, response));
                    }
                    if (stop) break;
                    std::wstring response; check(channel.call({Command::Features, 0, 0}, response));
                    try { preferences.observed(static_cast<uint32_t>(read_flag(channel.shared->currentFeatureMask))); }
                    catch (...) { status(4); log(L"Could not save switches; current session retained."); }
                    if (response.find(L"Settings: installed") != response.npos) status(2);
                    for (int i = 0; i < 10 && !stop; ++i) Sleep(100);
                }
                // The mapping survives Dia exiting, including its final toggle
                // state. Save before restoring the in-process overrides.
                try { preferences.observed(static_cast<uint32_t>(read_flag(channel.shared->currentFeatureMask))); }
                catch (...) { log(L"Could not save the final switch state."); }
                std::wstring restored;
                if (WaitForSingleObject(process.value, 0) == WAIT_TIMEOUT) channel.call({Command::Restore, 0, 0}, restored);
            } catch (HRESULT hr) {
                status(hr == HRESULT_FROM_WIN32(ERROR_ALREADY_EXISTS) ? 3 : 0);
                log(L"Waiting/retrying; HRESULT=" + std::to_wstring(static_cast<unsigned long>(hr)));
            } catch (const std::exception&) { status(4); log(L"Preferences/file error; correct preferences.ini and retry."); }
            for (int i = 0; i < 20 && !stop; ++i) Sleep(100);
        }
    } catch (...) { PostMessageW(window, Status, 4, 0); }
    if (SUCCEEDED(com)) CoUninitialize();
    return 0;
}
}
