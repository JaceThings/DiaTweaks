#include "preferences.h"
#include <utility>
namespace dt {
PreferencesSync::PreferencesSync(std::filesystem::path path) : path_(std::move(path)) {
    mask_ = load_preferences(path_);
    if (!std::filesystem::exists(path_)) save_preferences(path_, mask_);
    written_ = std::filesystem::last_write_time(path_);
}
std::optional<uint32_t> PreferencesSync::incoming(bool reset) {
    if (reset) { mask_ = 0; pending_ = true; return mask_; }
    // Editors can briefly remove a file during atomic save. Keep the connection
    // and current changes alive while the replacement is being written.
    if (!std::filesystem::exists(path_)) return {};
    const auto time = std::filesystem::last_write_time(path_);
    if (time == written_) return {};
    const auto parsed = load_preferences(path_); // Throws without changing state.
    mask_ = parsed; written_ = time; pending_ = false;
    return mask_;
}
void PreferencesSync::observed(uint32_t current) {
    if (current != mask_) { mask_ = current; pending_ = true; }
    if (!pending_) return;
    if (std::filesystem::exists(path_) && std::filesystem::last_write_time(path_) != written_) return;
    save_preferences(path_, mask_);
    written_ = std::filesystem::last_write_time(path_); pending_ = false;
}
}
