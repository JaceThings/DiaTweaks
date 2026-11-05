// Calls a Swift closure taking two borrowed values (pointers) and returning nothing, with its context in the register Swift
// keeps it in (x20). For CreateTab.swift, which checks the closure is the one it expects before calling.
#import <Foundation/Foundation.h>

typedef void (*DPSwiftClosure2)(const void *, const void *, void *__attribute__((swift_context))) __attribute__((swiftcall));

__attribute__((visibility("default"))) void DPGitLabCallSwiftClosure2(uintptr_t function, uintptr_t context, const void *first, const void *second) {
    ((DPSwiftClosure2)function)(first, second, (void *)context);
}

typedef void (*DPSwiftClosure1)(uintptr_t, void *__attribute__((swift_context))) __attribute__((swiftcall));

// The same for a closure taking one value passed directly in a register, such as a Set.
__attribute__((visibility("default"))) void DPGitLabCallSwiftClosure1(uintptr_t function, uintptr_t context, uintptr_t argument) {
    ((DPSwiftClosure1)function)(argument, (void *)context);
}
