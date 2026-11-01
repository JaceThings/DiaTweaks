#include "preferences.h"
#include "common.h"
#include <shlobj.h>
#include <fstream>
#include <algorithm>
namespace dt {
static std::string trim(std::string s) {
    const auto start = s.find_first_not_of(" \t\r\n");
    return start == s.npos ? "" : s.substr(start, s.find_last_not_of(" \t\r\n") - start + 1);
}
uint32_t parse_preferences(std::istream& input) {
    uint32_t mask = 0; std::string line;
    while (std::getline(input, line)) {
        if (line.starts_with("\xEF\xBB\xBF")) line.erase(0, 3);
        line = trim(line); if (line.empty() || line[0] == '#' || line[0] == ';') continue;
        const auto equals = line.find('='); if (equals == line.npos) throw E_INVALIDARG;
        const auto key = trim(line.substr(0, equals)), value = trim(line.substr(equals + 1));
        const auto id = feature_id(std::wstring(key.begin(), key.end()));
        if (id == FeatureId::Count) continue; // Preserve compatibility with a newer catalog.
        if (value == "1" || value == "true" || value == "on") mask |= feature_bit(id);
        else if (value == "0" || value == "false" || value == "off") mask &= ~feature_bit(id);
        else throw E_INVALIDARG;
    }
    return mask;
}
uint32_t load_preferences(const std::filesystem::path& path) {
    if (!std::filesystem::exists(path)) return 0;
    std::ifstream input(path); if (!input) throw E_ACCESSDENIED;
    return parse_preferences(input);
}
void save_preferences(const std::filesystem::path& path, uint32_t mask) {
    std::filesystem::create_directories(path.parent_path());
    auto temporary = path; temporary += L"." + std::to_wstring(GetCurrentProcessId()) + L".tmp";
    {
        std::ofstream output(temporary, std::ios::binary | std::ios::trunc);
        if (!output) throw E_ACCESSDENIED;
        output << "# DiaTweaks Windows preferences. Changes apply while DiaTweaks is running.\n";
        for (uint32_t i = 0; i < static_cast<uint32_t>(FeatureId::Count); ++i) {
            const std::wstring key = FeatureKeys[i];
            std::string ascii;
            for (const auto character : key) ascii.push_back(static_cast<char>(character)); // Catalog keys are ASCII.
            output << ascii << '=' << (requested(mask, static_cast<FeatureId>(i)) ? '1' : '0') << '\n';
        }
        output.flush(); if (!output) throw E_FAIL;
    }
    if (!MoveFileExW(temporary.c_str(), path.c_str(), MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH)) {
        const auto error = last_error(); DeleteFileW(temporary.c_str()); throw error;
    }
}
std::filesystem::path preferences_path() {
    PWSTR folder = nullptr; check(SHGetKnownFolderPath(FOLDERID_LocalAppData, 0, nullptr, &folder));
    const std::filesystem::path result = std::filesystem::path(folder) / L"DiaTweaks" / L"preferences.ini";
    CoTaskMemFree(folder); return result;
}
}
