#pragma once
#include "feature_state.h"
#include <filesystem>
#include <istream>
#include <optional>
namespace dt {
uint32_t parse_preferences(std::istream&);
uint32_t load_preferences(const std::filesystem::path&);
void save_preferences(const std::filesystem::path&, uint32_t);
std::filesystem::path preferences_path();
class PreferencesSync {
    std::filesystem::path path_;
    std::filesystem::file_time_type written_;
    uint32_t mask_ = 0;
    bool pending_ = false;
public:
    explicit PreferencesSync(std::filesystem::path);
    uint32_t mask() const { return mask_; }
    std::optional<uint32_t> incoming(bool reset);
    void observed(uint32_t);
};
}
