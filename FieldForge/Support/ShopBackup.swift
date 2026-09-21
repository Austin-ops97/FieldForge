import Foundation
import SwiftData

struct BackupPreview: Sendable {
    var snapshot: ShopSnapshot
    var files: [String: Data]
    var missingMedia: Int

    var summary: String {
        let customers = snapshot.clients.count == 1 ? "1 customer" : "\(snapshot.clients.count) customers"
        let jobs = snapshot.jobs.count == 1 ? "1 job" : "\(snapshot.jobs.count) jobs"
        var text = "\(snapshot.profile.businessName). \(customers), \(jobs)."
        if missingMedia > 0 {
            let files = missingMedia == 1 ? "1 photo or voice note is missing" : "\(missingMedia) photos or voice notes are missing"
            text += " \(files) from the package and will be skipped."
        }
        return text
    }
}

struct ShopSnapshot: Codable, Sendable {
    var formatVersion: Int
    var exportedAt: Date
    var profile: ProfileRecord
    var clients: [ClientRecord]
    var jobs: [JobRecord]
    var priceBook: [PriceRecord]
}

struct ProfileRecord: Codable, Sendable {
    var businessName: String
    var ownerName: String
    var trade: String
    var phone: String
    var email: String
    var cityLine: String
    var taxBasisPoints: Int
    var defaultQuoteNotes: String
    var defaultInvoiceTerms: String
    var createdAt: Date
}

struct ClientRecord: Codable, Sendable {
    var id: String
    var name: String
    var phone: String
    var email: String
    var address: String
    var notes: String
    var createdAt: Date
}

struct JobRecord: Codable, Sendable {
    var id: String
    var clientID: String?
    var title: String
    var status: String
    var scheduledAt: Date
    var address: String
    var notes: String
    var voiceMemoCaption: String
    var completedAt: Date?
    var createdAt: Date
    var photos: [PhotoRecord]
    var voiceNotes: [VoiceRecord]
    var quotes: [QuoteRecord]
}

struct PhotoRecord: Codable, Sendable {
    var relativePath: String
    var caption: String
    var symbolName: String
    var createdAt: Date
}

struct VoiceRecord: Codable, Sendable {
    var relativePath: String
    var duration: Double
    var createdAt: Date
}

struct QuoteRecord: Codable, Sendable {
    var number: String
    var status: String
    var taxBasisPoints: Int
    var notes: String
    var createdAt: Date
    var lineItems: [LineRecord]
    var invoice: InvoiceRecord?
}

struct LineRecord: Codable, Sendable {
    var name: String
    var unit: String
    var quantity: Int
    var unitPrice: String
    var taxable: Bool
    var sortIndex: Int
}

struct InvoiceRecord: Codable, Sendable {
    var number: String
    var status: String
    var issuedAt: Date
    var dueAt: Date
    var paidAt: Date?
}

struct PriceRecord: Codable, Sendable {
    var name: String
    var detail: String
    var category: String
    var unit: String
    var unitPrice: String
    var taxable: Bool
    var createdAt: Date
}

struct RestoreReport {
    var businessName: String
    var missingMedia: Int

    var message: String {
        if missingMedia == 0 {
            return "\(businessName) is back on this iPhone, including its photos and voice notes."
        }
        let missing = missingMedia == 1 ? "1 photo or voice note was missing" : "\(missingMedia) photos or voice notes were missing"
        return "\(businessName) is back on this iPhone. \(missing) from the file, so those clips were skipped."
    }
}

enum ShopBackupError: LocalizedError, Sendable {
    case noProfile
    case unreadable
    case notABackup
    case compressed
    case tooLarge
    case corrupt
    case writeFailed

    var errorDescription: String? {
        switch self {
        case .noProfile:
            return "Set up the shop before making a backup."
        case .unreadable:
            return "That file couldn’t be opened."
        case .notABackup:
            return "That file isn’t a FieldForge backup."
        case .compressed:
            return "This backup uses compression FieldForge doesn’t read. Use a backup made in FieldForge."
        case .tooLarge:
            return "That backup is too large to restore on this iPhone."
        case .corrupt:
            return "That backup is damaged or incomplete."
        case .writeFailed:
            return "The backup couldn’t be written on this iPhone."
        }
    }
}

@MainActor
enum ShopBackup {
    nonisolated private static let version = 1
    private static let backupStamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        return formatter
    }()

    private struct ArchiveDraft: Sendable {
        var snapshot: ShopSnapshot
        var mediaPaths: [String: String]
    }

    static func makeZip(in context: ModelContext) async throws -> URL {
        guard let profile = (try? context.fetch(FetchDescriptor<BusinessProfile>()))?.first else {
            throw ShopBackupError.noProfile
        }
        let clients = (try? context.fetch(FetchDescriptor<Client>())) ?? []
        let jobs = (try? context.fetch(FetchDescriptor<Job>())) ?? []
        let prices = (try? context.fetch(FetchDescriptor<PriceBookItem>())) ?? []

        var clientIDs: [PersistentIdentifier: String] = [:]
        let clientRecords: [ClientRecord] = clients.map { client in
            let id = UUID().uuidString
            clientIDs[client.persistentModelID] = id
            return ClientRecord(
                id: id,
                name: client.name,
                phone: client.phone,
                email: client.email,
                address: client.address,
                notes: client.notes,
                createdAt: client.createdAt
            )
        }

        var mediaPaths: [String: String] = [:]
        let jobRecords: [JobRecord] = jobs.map { job in
            JobRecord(
                id: UUID().uuidString,
                clientID: job.client.flatMap { clientIDs[$0.persistentModelID] },
                title: job.title,
                status: job.statusRaw,
                scheduledAt: job.scheduledAt,
                address: job.address,
                notes: job.notes,
                voiceMemoCaption: job.voiceMemoCaption,
                completedAt: job.completedAt,
                createdAt: job.createdAt,
                photos: job.photos.sorted { $0.createdAt < $1.createdAt }.map { photo in
                    PhotoRecord(
                        relativePath: planMedia(photo.fileName, into: &mediaPaths),
                        caption: photo.caption,
                        symbolName: photo.symbolName,
                        createdAt: photo.createdAt
                    )
                },
                voiceNotes: job.voiceNotes.sorted { $0.createdAt < $1.createdAt }.map { note in
                    VoiceRecord(
                        relativePath: planMedia(note.fileName, into: &mediaPaths),
                        duration: note.duration,
                        createdAt: note.createdAt
                    )
                },
                quotes: job.quotes.sorted { $0.createdAt < $1.createdAt }.map(quoteRecord)
            )
        }

        let snapshot = ShopSnapshot(
            formatVersion: version,
            exportedAt: .now,
            profile: ProfileRecord(
                businessName: profile.businessName,
                ownerName: profile.ownerName,
                trade: profile.trade,
                phone: profile.phone,
                email: profile.email,
                cityLine: profile.cityLine,
                taxBasisPoints: profile.taxBasisPoints,
                defaultQuoteNotes: profile.defaultQuoteNotes,
                defaultInvoiceTerms: profile.defaultInvoiceTerms,
                createdAt: profile.createdAt
            ),
            clients: clientRecords,
            jobs: jobRecords,
            priceBook: prices.map { item in
                PriceRecord(
                    name: item.name,
                    detail: item.detail,
                    category: item.category,
                    unit: item.unit,
                    unitPrice: decimalString(item.unitPrice),
                    taxable: item.taxable,
                    createdAt: item.createdAt
                )
            }
        )

        let draft = ArchiveDraft(snapshot: snapshot, mediaPaths: mediaPaths)
        let stamp = backupStamp.string(from: .now)
        return try await Task.detached(priority: .userInitiated) {
            try ShopBackup.writeArchive(draft, stamp: stamp)
        }.value
    }

    static func inspect(_ url: URL) async throws -> BackupPreview {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        return try await Task.detached(priority: .userInitiated) {
            try ShopBackup.loadPreview(from: url)
        }.value
    }

    nonisolated private static func loadPreview(from url: URL) throws -> BackupPreview {
        if let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize, size > 250_000_000 {
            throw ShopBackupError.tooLarge
        }
        let data: Data
        do {
            data = try Data(contentsOf: url, options: [.mappedIfSafe])
        } catch {
            throw ShopBackupError.unreadable
        }
        let entries: [StoredZip.Entry]
        do {
            entries = try StoredZip.extract(data)
        } catch StoredZip.Failure.tooLarge {
            throw ShopBackupError.tooLarge
        } catch StoredZip.Failure.unsupported {
            throw ShopBackupError.compressed
        } catch {
            throw ShopBackupError.corrupt
        }
        guard let manifest = entries.first(where: { $0.name == "manifest.json" })?.data else {
            throw ShopBackupError.notABackup
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let snapshot: ShopSnapshot
        do {
            snapshot = try decoder.decode(ShopSnapshot.self, from: manifest)
        } catch {
            throw ShopBackupError.notABackup
        }
        guard snapshot.formatVersion == version, snapshot.profile.businessName.isEmpty == false else {
            throw ShopBackupError.notABackup
        }
        var files: [String: Data] = [:]
        for entry in entries where entry.name != "manifest.json" {
            files[entry.name] = entry.data
        }
        let missing = missingMediaCount(in: snapshot, files: files)
        return BackupPreview(snapshot: snapshot, files: files, missingMedia: missing)
    }

    @discardableResult
    static func restore(_ preview: BackupPreview, into profile: BusinessProfile, in context: ModelContext) async throws -> RestoreReport {
        let snapshot = preview.snapshot
        let doomed = OperationalData.mediaFileNames(in: context)
        let rescue = await Task.detached(priority: .userInitiated) {
            MediaFiles.duplicateFolder()
        }.value
        await Task.detached(priority: .userInitiated) {
            doomed.forEach { MediaFiles.remove($0) }
        }.value
        let staged = await Task.detached(priority: .userInitiated) {
            ShopBackup.stageMedia(preview.files)
        }.value
        OperationalData.removeShopWork(in: context, save: false, deleteFiles: false)
        apply(snapshot.profile, to: profile)

        var clients: [String: Client] = [:]
        for record in snapshot.clients {
            let client = Client(
                name: record.name,
                phone: record.phone,
                email: record.email,
                address: record.address,
                notes: record.notes,
                createdAt: record.createdAt
            )
            context.insert(client)
            clients[record.id] = client
        }

        var missing = 0
        for record in snapshot.jobs {
            let job = Job(
                title: record.title,
                status: JobStatus(rawValue: record.status) ?? .lead,
                scheduledAt: record.scheduledAt,
                address: record.address,
                notes: record.notes,
                voiceMemoCaption: record.voiceMemoCaption,
                completedAt: record.completedAt,
                createdAt: record.createdAt
            )
            context.insert(job)
            if let clientID = record.clientID {
                job.client = clients[clientID]
            }
            for photo in record.photos {
                let stored = staged[photo.relativePath]
                if photo.relativePath.isEmpty == false && stored == nil { missing += 1 }
                let item = JobPhoto(
                    caption: photo.caption,
                    symbolName: photo.symbolName.isEmpty ? "photo" : photo.symbolName,
                    fileName: stored ?? "",
                    createdAt: photo.createdAt
                )
                context.insert(item)
                item.job = job
            }
            for note in record.voiceNotes {
                guard let stored = staged[note.relativePath] else {
                    if note.relativePath.isEmpty == false { missing += 1 }
                    continue
                }
                let item = VoiceNote(fileName: stored, duration: note.duration, createdAt: note.createdAt)
                context.insert(item)
                item.job = job
            }
            for quoteRecord in record.quotes {
                let quote = Quote(
                    number: quoteRecord.number,
                    status: QuoteStatus(rawValue: quoteRecord.status) ?? .draft,
                    taxBasisPoints: quoteRecord.taxBasisPoints,
                    notes: quoteRecord.notes,
                    createdAt: quoteRecord.createdAt
                )
                context.insert(quote)
                quote.job = job
                for line in quoteRecord.lineItems {
                    let item = LineItem(
                        name: line.name,
                        unit: line.unit,
                        quantity: line.quantity,
                        unitPrice: decimal(line.unitPrice),
                        taxable: line.taxable,
                        sortIndex: line.sortIndex
                    )
                    context.insert(item)
                    item.quote = quote
                }
                if let invoiceRecord = quoteRecord.invoice {
                    let invoice = Invoice(
                        number: invoiceRecord.number,
                        status: InvoiceStatus(rawValue: invoiceRecord.status) ?? .sent,
                        issuedAt: invoiceRecord.issuedAt,
                        dueAt: invoiceRecord.dueAt,
                        paidAt: invoiceRecord.paidAt
                    )
                    context.insert(invoice)
                    invoice.quote = quote
                    quote.invoice = invoice
                }
            }
        }

        for item in snapshot.priceBook {
            let price = PriceBookItem(
                name: item.name,
                detail: item.detail,
                category: item.category,
                unit: item.unit,
                unitPrice: decimal(item.unitPrice),
                taxable: item.taxable,
                createdAt: item.createdAt
            )
            context.insert(price)
        }

        do {
            try context.save()
            if let rescue {
                try? FileManager.default.removeItem(at: rescue)
            }
        } catch {
            context.rollback()
            if let rescue, MediaFiles.replaceFolder(with: rescue) {
                try? FileManager.default.removeItem(at: rescue)
            }
            throw ShopBackupError.writeFailed
        }
        return RestoreReport(businessName: profile.businessName, missingMedia: missing)
    }

    private static func apply(_ record: ProfileRecord, to profile: BusinessProfile) {
        profile.businessName = record.businessName
        profile.ownerName = record.ownerName
        profile.trade = record.trade
        profile.phone = record.phone
        profile.email = record.email
        profile.cityLine = record.cityLine
        profile.taxBasisPoints = record.taxBasisPoints
        profile.defaultQuoteNotes = record.defaultQuoteNotes
        profile.defaultInvoiceTerms = record.defaultInvoiceTerms
        profile.createdAt = record.createdAt
    }

    private static func quoteRecord(_ quote: Quote) -> QuoteRecord {
        QuoteRecord(
            number: quote.number,
            status: quote.statusRaw,
            taxBasisPoints: quote.taxBasisPoints,
            notes: quote.notes,
            createdAt: quote.createdAt,
            lineItems: quote.lineItems.sorted { $0.sortIndex < $1.sortIndex }.map { line in
                LineRecord(
                    name: line.name,
                    unit: line.unit,
                    quantity: line.quantity,
                    unitPrice: decimalString(line.unitPrice),
                    taxable: line.taxable,
                    sortIndex: line.sortIndex
                )
            },
            invoice: quote.invoice.map { invoice in
                InvoiceRecord(
                    number: invoice.number,
                    status: invoice.statusRaw,
                    issuedAt: invoice.issuedAt,
                    dueAt: invoice.dueAt,
                    paidAt: invoice.paidAt
                )
            }
        )
    }

    private static func planMedia(_ fileName: String, into planned: inout [String: String]) -> String {
        guard fileName.isEmpty == false else { return "" }
        let url = MediaFiles.url(for: fileName)
        guard FileManager.default.fileExists(atPath: url.path) else { return "" }
        let safe = sanitized(fileName)
        var path = "media/\(safe)"
        var bump = 2
        while planned[path] != nil {
            path = "media/\(bump)-\(safe)"
            bump += 1
        }
        planned[path] = url.path
        return path
    }

    nonisolated private static func writeArchive(_ draft: ArchiveDraft, stamp: String) throws -> URL {
        var files: [String: Data] = [:]
        for (path, diskPath) in draft.mediaPaths {
            if let data = readBounded(diskPath) {
                files[path] = data
            }
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let manifest = try? encoder.encode(draft.snapshot) else { throw ShopBackupError.writeFailed }
        var entries = [StoredZip.Entry(name: "manifest.json", data: manifest)]
        for (path, data) in files.sorted(by: { $0.key < $1.key }) {
            entries.append(StoredZip.Entry(name: path, data: data))
        }
        let archive = StoredZip.archive(entries)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("FieldForge-Backup-\(stamp).zip")
        do {
            try archive.write(to: url, options: .atomic)
            return url
        } catch {
            throw ShopBackupError.writeFailed
        }
    }

    /// One oversized or unreadable clip is left out. The rest of the shop still archives.
    nonisolated private static func readBounded(_ path: String) -> Data? {
        let maxBytes = 32 * 1024 * 1024
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: path),
              let size = attributes[.size] as? NSNumber,
              size.intValue > 0,
              size.intValue <= maxBytes else { return nil }
        return try? Data(contentsOf: URL(fileURLWithPath: path), options: [.mappedIfSafe])
    }

    nonisolated private static func stageMedia(_ files: [String: Data]) -> [String: String] {
        let maxBytes = 32 * 1024 * 1024
        var staged: [String: String] = [:]
        var used: Set<String> = []
        for (path, data) in files where data.isEmpty == false && data.count <= maxBytes {
            var base = sanitized((path as NSString).lastPathComponent)
            var bump = 2
            while used.contains(base) {
                base = "\(bump)-\(sanitized((path as NSString).lastPathComponent))"
                bump += 1
            }
            guard MediaFiles.install(data, fileName: base) else { continue }
            used.insert(base)
            staged[path] = base
        }
        return staged
    }

    nonisolated private static func missingMediaCount(in snapshot: ShopSnapshot, files: [String: Data]) -> Int {
        var missing = 0
        for job in snapshot.jobs {
            for photo in job.photos where photo.relativePath.isEmpty == false && files[photo.relativePath] == nil {
                missing += 1
            }
            for note in job.voiceNotes where note.relativePath.isEmpty == false && files[note.relativePath] == nil {
                missing += 1
            }
        }
        return missing
    }

    nonisolated private static func sanitized(_ name: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
        let cleaned = String(name.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" })
        let trimmed = cleaned.trimmingCharacters(in: CharacterSet(charactersIn: "-."))
        return trimmed.isEmpty ? "file.bin" : trimmed
    }

    private static func decimalString(_ value: Decimal) -> String {
        NSDecimalNumber(decimal: value).stringValue
    }

    private static func decimal(_ string: String) -> Decimal {
        Decimal(string: string, locale: Locale(identifier: "en_US_POSIX")) ?? 0
    }
}
