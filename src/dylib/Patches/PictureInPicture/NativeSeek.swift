import SwiftShims

@_silgen_name("swift_reflectionMirror_recursiveCount")
private func DPPiPFieldCount(_ type: Any.Type) -> Int
@_silgen_name("swift_reflectionMirror_recursiveChildMetadata")
private func DPPiPFieldMetadata(_ type: Any.Type, index: Int, fieldMetadata: UnsafeMutablePointer<_FieldReflectionMetadata>) -> Any.Type
@_silgen_name("swift_reflectionMirror_recursiveChildOffset")
private func DPPiPFieldOffset(_ type: Any.Type, index: Int) -> Int

typealias DPPiPSeekAction = @MainActor (Int64) throws -> Void
private struct DPPiPSeekStorage { let callback: DPPiPSeekAction }

func DPPiPReadSeek(_ media: Any) -> DPPiPSeekAction? {
    _openExistential(media, do: DPPiPReadConcreteSeek)
}

private func DPPiPReadConcreteSeek<Value>(_ media: Value) -> DPPiPSeekAction? {
    guard String(reflecting: Value.self) == "ADK2.MediaSessionProxy",
          Mirror(reflecting: media).displayStyle == .struct,
          MemoryLayout<DPPiPSeekStorage>.size == MemoryLayout<DPPiPSeekAction>.size,
          MemoryLayout<Value>.size >= MemoryLayout<DPPiPSeekStorage>.size else { return nil }
    let count = DPPiPFieldCount(Value.self)
    guard count > 0 && count <= 256 else { return nil }
    for index in 0..<count {
        var metadata = _FieldReflectionMetadata()
        let fieldType = DPPiPFieldMetadata(Value.self, index: index, fieldMetadata: &metadata)
        defer { metadata.freeFunc?(metadata.name) }
        guard let name = metadata.name, String(cString: name) == "_seek" else { continue }
        let offset = DPPiPFieldOffset(Value.self, index: index)
        guard fieldType == DPPiPSeekAction.self, metadata.isStrong,
              offset >= 0, offset % MemoryLayout<DPPiPSeekStorage>.alignment == 0,
              offset <= MemoryLayout<Value>.size - MemoryLayout<DPPiPSeekStorage>.size else { return nil }
        // Mirror erases a concrete function without its required argument conversion.
        // Copy the exact, metadata-checked field through a concrete wrapper so Swift
        // adds that conversion and retains the closure's captures. No offset is fixed.
        return withUnsafePointer(to: media) {
            let address = UnsafeRawPointer($0).advanced(by: offset)
            guard UInt(bitPattern: address) % UInt(MemoryLayout<DPPiPSeekStorage>.alignment) == 0 else { return nil }
            return address.load(as: DPPiPSeekStorage.self).callback
        }
    }
    return nil
}
