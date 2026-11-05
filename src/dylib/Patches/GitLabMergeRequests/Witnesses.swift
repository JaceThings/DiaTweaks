// Values of Dia's Swift types, which can't be named here, made and checked through the type's value witness table: the
// functions Dia's own code uses to copy, destroy and tag them.
import Foundation

private func load<T>(_ type: T.Type, _ pointer: UnsafeRawPointer) -> Any { pointer.load(as: T.self) }

struct Witnesses {
    let metadata: UnsafeRawPointer, table: UnsafeRawPointer
    init(_ type: Any.Type) {
        metadata = unsafeBitCast(type, to: UnsafeRawPointer.self)
        table = metadata.load(fromByteOffset: -8, as: UnsafeRawPointer.self)
    }
    var size: Int { table.load(fromByteOffset: 0x40, as: Int.self) }
    var stride: Int { table.load(fromByteOffset: 0x48, as: Int.self) }
    private var flags: UInt32 { table.load(fromByteOffset: 0x50, as: UInt32.self) }
    var alignment: Int { Int(flags & 0xff) + 1 }
    var hasEnumWitnesses: Bool { flags & 0x0020_0000 != 0 }
    private func function(_ offset: Int) -> UnsafeRawPointer { table.load(fromByteOffset: offset, as: UnsafeRawPointer.self) }

    func copy(_ to: UnsafeMutableRawPointer, _ from: UnsafeRawPointer) {
        typealias Copy = @convention(c) (UnsafeMutableRawPointer, UnsafeRawPointer, UnsafeRawPointer) -> UnsafeMutableRawPointer
        _ = unsafeBitCast(function(0x10), to: Copy.self)(to, from, metadata)
    }
    func destroy(_ value: UnsafeMutableRawPointer) {
        unsafeBitCast(function(0x08), to: (@convention(c) (UnsafeMutableRawPointer, UnsafeRawPointer) -> Void).self)(value, metadata)
    }
    func injectTag(_ value: UnsafeMutableRawPointer, _ tag: UInt32) {
        typealias Inject = @convention(c) (UnsafeMutableRawPointer, UInt32, UnsafeRawPointer) -> Void
        unsafeBitCast(function(0x68), to: Inject.self)(value, tag, metadata)
    }
    // Zeroed and aligned for one value; free with destroy, if a value was made in it, then deallocate.
    func allocate() -> UnsafeMutableRawPointer {
        let bytes = max(stride, size, 1)
        let buffer = UnsafeMutableRawPointer.allocate(byteCount: bytes, alignment: max(alignment, 8))
        buffer.initializeMemory(as: UInt8.self, repeating: 0, count: bytes)
        return buffer
    }
    // A copy of the value, to read through Mirror or describe as Dia would.
    func value(at pointer: UnsafeRawPointer) -> Any {
        func opened<T>(_ type: T.Type) -> Any { load(type, pointer) }
        return _openExistential(unsafeBitCast(metadata, to: Any.Type.self), do: opened)
    }
}

// An enum case with one payload, laid out as Swift lays it out: the payload at offset 0, then the case's tag. nil unless
// the type is an enum with room for the payload.
func enumValue(_ type: Any.Type, tag: UInt32, payloadSize: Int, payload: (UnsafeMutableRawPointer) -> Void) -> UnsafeMutableRawPointer? {
    let witnesses = Witnesses(type)
    guard witnesses.hasEnumWitnesses, witnesses.size >= payloadSize else { return nil }
    let buffer = witnesses.allocate()
    payload(buffer)
    witnesses.injectTag(buffer, tag)
    return buffer
}

// A struct's field offsets, from its metadata's field offset vector.
func fieldOffsets(_ type: Any.Type) -> [Int] {
    let metadata = unsafeBitCast(type, to: UnsafeRawPointer.self)
    let descriptor = metadata.load(fromByteOffset: 8, as: UnsafeRawPointer.self)
    let count = Int(descriptor.load(fromByteOffset: 0x14, as: UInt32.self))
    let vector = Int(descriptor.load(fromByteOffset: 0x18, as: UInt32.self))
    return (0..<count).map { Int(metadata.load(fromByteOffset: vector * 8 + $0 * 4, as: UInt32.self)) }
}
