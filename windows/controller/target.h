#pragma once
#include "common.h"
#include <filesystem>
namespace dt {
struct Target { DWORD pid; std::filesystem::path framework; std::wstring package; };
Target find_target(DWORD requestedPid);
HRESULT attach(const Target&, const std::filesystem::path& dll, const std::wstring& initialization);
}
