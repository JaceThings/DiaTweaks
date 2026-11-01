#pragma once
#include "common.h"
#include <atomic>
namespace dt {
struct BackgroundRunner {
    std::atomic<bool> stop{false}, reset{false};
    HWND window = nullptr;
    static constexpr UINT Status = WM_APP + 42;
    DWORD run() noexcept;
};
}
