#pragma once
#include "page.h"
#include <winrt/Microsoft.UI.Xaml.Media.h>
#include <functional>
namespace dt {
inline winrt::Microsoft::UI::Xaml::DependencyObject find_visual(
    const winrt::Microsoft::UI::Xaml::DependencyObject& root,
    const std::function<bool(const winrt::Microsoft::UI::Xaml::FrameworkElement&)>& match, unsigned depth = 0) {
    using namespace winrt::Microsoft::UI::Xaml;
    if (!root || depth > 64) return nullptr;
    if (auto element = root.try_as<FrameworkElement>(); element && match(element)) return element;
    const int count = Media::VisualTreeHelper::GetChildrenCount(root);
    for (int i = 0; i < count; ++i)
        if (auto result = find_visual(Media::VisualTreeHelper::GetChild(root, i), match, depth + 1)) return result;
    return nullptr;
}
}
