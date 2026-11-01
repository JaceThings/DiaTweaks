#include "preferences.h"
#include "common.h"
#include <sstream>
#include <iostream>
using namespace dt;
static void require(bool value, const char* detail) { if (!value) throw std::runtime_error(detail); }
int main() {
    try {
        std::istringstream input("# editing switches\nedgeToEdge=on\nsquareSidebarCorners=1\nhideToolbar=false\nunknownFutureKey=1\n");
        const auto mask = parse_preferences(input);
        std::istringstream bom("\xEF\xBB\xBF# Notepad UTF-8\nhideChatButton=on\n");
        require(parse_preferences(bom) == feature_bit(FeatureId::Chat), "support UTF-8 editor BOM");
        require(requested(mask, FeatureId::Edge) && requested(mask, FeatureId::Square) && !requested(mask, FeatureId::Toolbar), "parse and retain independent requests");
        std::istringstream bad("hideToolbar=perhaps\n");
        bool rejected = false; try { (void)parse_preferences(bad); } catch (HRESULT hr) { rejected = hr == E_INVALIDARG; }
        require(rejected, "malformed values must not silently turn patches off");
        wchar_t folder[MAX_PATH]{}, file[MAX_PATH]{};
        require(GetTempPathW(MAX_PATH, folder) && GetTempFileNameW(folder, L"dtw", 0, file), "temporary preferences path");
        const std::filesystem::path path(file);
        try {
            save_preferences(path, mask); require(load_preferences(path) == mask, "atomic preferences round trip");
            PreferencesSync sync(path);
            require(sync.mask() == mask && !sync.incoming(false), "initial saved switches are ready for attachment");
            const auto previousTime = std::filesystem::last_write_time(path);
            save_preferences(path, feature_bit(FeatureId::Toolbar));
            std::filesystem::last_write_time(path, previousTime + std::chrono::seconds(2));
            require(sync.incoming(false) == feature_bit(FeatureId::Toolbar), "live file edits reach the running controller");
            sync.observed(feature_bit(FeatureId::Chat));
            require(load_preferences(path) == feature_bit(FeatureId::Chat), "native Settings switches persist to the same file");
            DeleteFileW(file);
            require(!sync.incoming(false) && sync.mask() == feature_bit(FeatureId::Chat), "editor atomic-save gap does not disconnect or reset switches");
            require(sync.incoming(true) == 0u, "tray reset requests all switches off");
            sync.observed(0); require(load_preferences(path) == 0, "tray reset persists");
            save_preferences(path, 0); require(load_preferences(path) == 0, "reset saved switches");
        } catch (...) { DeleteFileW(file); throw; }
        DeleteFileW(file);
        std::cout << "PASS: preferences parsing, invalid values, atomic write and reset\n";
    } catch (const std::exception& e) { std::cerr << e.what() << '\n'; return 1; }
      catch (HRESULT hr) { std::cerr << std::hex << hr << '\n'; return 1; }
    return 0;
}
