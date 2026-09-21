import Foundation

enum StoredZip {
    struct Entry {
        var name: String
        var data: Data
    }

    enum Failure: Error {
        case corrupt
        case tooLarge
        case unsupported
    }

    static func archive(_ entries: [Entry]) -> Data {
        var local = Data()
        var central = Data()
        var records: [(entry: Entry, offset: UInt32, crc: UInt32)] = []
        for entry in entries {
            let offset = UInt32(local.count)
            let crc = CRC32.checksum(entry.data)
            records.append((entry, offset, crc))
            local.append(localHeader(entry, crc: crc))
            local.append(entry.data)
        }
        let centralOffset = UInt32(local.count)
        for record in records {
            central.append(centralHeader(record.entry, offset: record.offset, crc: record.crc))
        }
        var result = local
        result.append(central)
        result.append(endRecord(count: UInt16(records.count), size: UInt32(central.count), offset: centralOffset))
        return result
    }

    static func extract(_ data: Data, maxBytes: Int = 250_000_000) throws -> [Entry] {
        guard let eocd = findEnd(data) else { throw Failure.corrupt }
        let count = Int(readU16(data, eocd + 10))
        let size = Int(readU32(data, eocd + 12))
        let offset = Int(readU32(data, eocd + 16))
        guard count >= 0, size >= 0, offset >= 0, offset + size <= data.count else { throw Failure.corrupt }
        var cursor = offset
        var entries: [Entry] = []
        var total = 0
        for _ in 0..<count {
            guard cursor + 46 <= data.count, readU32(data, cursor) == 0x02014b50 else { throw Failure.corrupt }
            let method = readU16(data, cursor + 10)
            let compressed = Int(readU32(data, cursor + 20))
            let uncompressed = Int(readU32(data, cursor + 24))
            let nameLength = Int(readU16(data, cursor + 28))
            let extraLength = Int(readU16(data, cursor + 30))
            let commentLength = Int(readU16(data, cursor + 32))
            let localOffset = Int(readU32(data, cursor + 42))
            let nameStart = cursor + 46
            guard nameStart + nameLength <= data.count else { throw Failure.corrupt }
            let nameData = data.subdata(in: nameStart..<(nameStart + nameLength))
            guard let name = String(data: nameData, encoding: .utf8), safeName(name) else { throw Failure.corrupt }
            guard method == 0, compressed == uncompressed else { throw Failure.unsupported }
            guard localOffset + 30 <= data.count, readU32(data, localOffset) == 0x04034b50 else { throw Failure.corrupt }
            let localName = Int(readU16(data, localOffset + 26))
            let localExtra = Int(readU16(data, localOffset + 28))
            let dataStart = localOffset + 30 + localName + localExtra
            let dataEnd = dataStart + compressed
            guard dataEnd <= data.count else { throw Failure.corrupt }
            total += compressed
            if total > maxBytes { throw Failure.tooLarge }
            entries.append(Entry(name: name, data: data.subdata(in: dataStart..<dataEnd)))
            cursor = nameStart + nameLength + extraLength + commentLength
        }
        return entries
    }

    private static func safeName(_ name: String) -> Bool {
        if name.isEmpty || name.hasPrefix("/") || name.contains("..") || name.contains("\\") { return false }
        return true
    }

    private static func localHeader(_ entry: Entry, crc: UInt32) -> Data {
        let name = Data(entry.name.utf8)
        var data = Data()
        appendU32(0x04034b50, to: &data)
        appendU16(20, to: &data)
        appendU16(0x0800, to: &data)
        appendU16(0, to: &data)
        appendU16(0, to: &data)
        appendU16(0, to: &data)
        appendU32(crc, to: &data)
        appendU32(UInt32(entry.data.count), to: &data)
        appendU32(UInt32(entry.data.count), to: &data)
        appendU16(UInt16(name.count), to: &data)
        appendU16(0, to: &data)
        data.append(name)
        return data
    }

    private static func centralHeader(_ entry: Entry, offset: UInt32, crc: UInt32) -> Data {
        let name = Data(entry.name.utf8)
        var data = Data()
        appendU32(0x02014b50, to: &data)
        appendU16(20, to: &data)
        appendU16(20, to: &data)
        appendU16(0x0800, to: &data)
        appendU16(0, to: &data)
        appendU16(0, to: &data)
        appendU16(0, to: &data)
        appendU32(crc, to: &data)
        appendU32(UInt32(entry.data.count), to: &data)
        appendU32(UInt32(entry.data.count), to: &data)
        appendU16(UInt16(name.count), to: &data)
        appendU16(0, to: &data)
        appendU16(0, to: &data)
        appendU16(0, to: &data)
        appendU16(0, to: &data)
        appendU32(0, to: &data)
        appendU32(offset, to: &data)
        data.append(name)
        return data
    }

    private static func endRecord(count: UInt16, size: UInt32, offset: UInt32) -> Data {
        var data = Data()
        appendU32(0x06054b50, to: &data)
        appendU16(0, to: &data)
        appendU16(0, to: &data)
        appendU16(count, to: &data)
        appendU16(count, to: &data)
        appendU32(size, to: &data)
        appendU32(offset, to: &data)
        appendU16(0, to: &data)
        return data
    }

    private static func findEnd(_ data: Data) -> Int? {
        guard data.count >= 22 else { return nil }
        let limit = min(data.count, 22 + 65_535)
        let start = data.count - limit
        var index = data.count - 22
        while index >= start {
            if readU32(data, index) == 0x06054b50 { return index }
            index -= 1
        }
        return nil
    }

    private static func readU16(_ data: Data, _ offset: Int) -> UInt16 {
        let bytes = [UInt8](data[offset..<(offset + 2)])
        return UInt16(bytes[0]) | (UInt16(bytes[1]) << 8)
    }

    private static func readU32(_ data: Data, _ offset: Int) -> UInt32 {
        let bytes = [UInt8](data[offset..<(offset + 4)])
        return UInt32(bytes[0]) | (UInt32(bytes[1]) << 8) | (UInt32(bytes[2]) << 16) | (UInt32(bytes[3]) << 24)
    }

    private static func appendU16(_ value: UInt16, to data: inout Data) {
        data.append(UInt8(value & 0xff))
        data.append(UInt8((value >> 8) & 0xff))
    }

    private static func appendU32(_ value: UInt32, to data: inout Data) {
        data.append(UInt8(value & 0xff))
        data.append(UInt8((value >> 8) & 0xff))
        data.append(UInt8((value >> 16) & 0xff))
        data.append(UInt8((value >> 24) & 0xff))
    }
}

private enum CRC32 {
    static func checksum(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xffff_ffff
        for byte in data {
            let index = Int((crc ^ UInt32(byte)) & 0xff)
            crc = table[index] ^ (crc >> 8)
        }
        return crc ^ 0xffff_ffff
    }

    private static let table: [UInt32] = (0..<256).map { index in
        var value = UInt32(index)
        for _ in 0..<8 {
            if value & 1 == 1 {
                value = 0xEDB8_8320 ^ (value >> 1)
            } else {
                value >>= 1
            }
        }
        return value
    }
}
