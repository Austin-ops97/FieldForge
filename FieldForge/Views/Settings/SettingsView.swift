import SwiftData
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @Query private var profiles: [BusinessProfile]

    var body: some View {
        Group {
            if let profile = profiles.first {
                SettingsForm(profile: profile)
            } else {
                ContentUnavailableView("No business profile", systemImage: "building.2", description: Text("Set up the shop to edit it here."))
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct SettingsForm: View {
    @Environment(\.modelContext) private var context
    @Environment(AppLock.self) private var appLock
    @Bindable var profile: BusinessProfile

    @State private var businessName = ""
    @State private var ownerName = ""
    @State private var trade: TradeKit = .plumbing
    @State private var phone = ""
    @State private var email = ""
    @State private var cityLine = ""
    @State private var taxBasisPoints = 825
    @State private var quoteNotes = ""
    @State private var terms = ""
    @State private var didLoad = false
    @State private var confirmKit = false
    @State private var confirmReset = false
    @State private var shareURL: URL?
    @State private var shareFailed = false
    @State private var showImporter = false
    @State private var pendingRestore: BackupPreview?
    @State private var confirmRestore = false
    @State private var noticeTitle = ""
    @State private var noticeMessage = ""
    @State private var noticeOffersSettings = false
    @State private var showNotice = false
    @State private var lockOn = false
    @State private var remindersOn = false
    @State private var reminderCount = 0
    @State private var lockBusy = false
    @State private var remindersBusy = false

    private var canSave: Bool {
        businessName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            && ownerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    var body: some View {
        Form {
            Section {
                Button {
                    backupShop()
                } label: {
                    Label("Backup", systemImage: "arrow.down.doc")
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
                .accessibilityLabel("Backup")
                Button {
                    showImporter = true
                } label: {
                    Label("Restore", systemImage: "arrow.up.doc")
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
                .accessibilityLabel("Restore")
                Toggle(isOn: lockBinding) {
                    Label("App Lock", systemImage: "lock")
                }
                .accessibilityLabel("App Lock")
                Toggle(isOn: remindersBinding) {
                    Label("Overdue reminders", systemImage: "bell")
                }
                .accessibilityLabel("Overdue reminders")
                if remindersOn {
                    Text(reminderCaption)
                        .font(ForgeType.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("On this iPhone")
            } footer: {
                Text("All data stays on this device. There is no account. FieldForge works offline, including in airplane mode. Backup makes one file you can keep in Files. Restore replaces the shop on this iPhone. App Lock uses Face ID, Touch ID, or the passcode, and asks again after you leave. A short switch stays unlocked. Overdue reminders are 8:00 AM notifications scheduled on this iPhone.")
            }
            Section("Business") {
                TextField("Company name", text: $businessName)
                TextField("Your name", text: $ownerName)
                TextField("Phone", text: $phone)
                    .keyboardType(.phonePad)
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                TextField("City", text: $cityLine)
            }
            Section("Trade") {
                ChipFlow(spacing: 8) {
                    ForEach(TradeKit.allCases) { item in
                        FilterChip(title: item.label, selected: trade == item, tint: ForgeTheme.ink) {
                            trade = item
                        }
                    }
                }
                .padding(.vertical, 4)
                Button {
                    confirmKit = true
                } label: {
                    Label("Replace price book with \(trade.label) kit", systemImage: "book.closed")
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
            }
            Section("Tax and terms") {
                Stepper(value: $taxBasisPoints, in: 0...1_500, step: 25) {
                    Text("Tax \(FieldFormat.taxPercent(basisPoints: taxBasisPoints))")
                }
                .frame(minHeight: 44)
                TextField("Default note on new quotes", text: $quoteNotes, axis: .vertical)
                    .lineLimit(2...4)
                TextField("Terms on quotes and invoices", text: $terms, axis: .vertical)
                    .lineLimit(2...4)
                Text("New quotes pick up this tax rate and note. Quotes you already sent keep their own numbers.")
                    .font(ForgeType.caption)
                    .foregroundStyle(.secondary)
            }
            Section {
                NavigationLink {
                    ReportsView()
                } label: {
                    Label("Money reports", systemImage: "chart.bar")
                        .frame(minHeight: 44, alignment: .leading)
                }
            } header: {
                Text("Shop")
            }
            Section {
                Button("Reset demo data", role: .destructive) {
                    confirmReset = true
                }
                .frame(minHeight: 44)
            } footer: {
                Text("Replaces customers, jobs, quotes, invoices, photos, voice notes, and the price book with the \(trade.label) sample. Your business profile stays.")
            }
            Section("Privacy") {
                Text("FieldForge does not send customers, jobs, quotes, invoices, photos, or voice notes anywhere. The camera, microphone, and photo library are used only on this iPhone. A PDF, CSV, or backup leaves the device only when you share it.")
                    .font(ForgeType.secondary)
                    .foregroundStyle(.secondary)
            }
            Section("About") {
                LabeledContent("App", value: "FieldForge")
                LabeledContent("Version", value: version)
                Text("FieldForge stays on this iPhone. No account. No network.")
                    .font(ForgeType.secondary)
                    .foregroundStyle(.secondary)
                Button {
                    openSystemSettings()
                } label: {
                    Label("Camera, microphone, and photos", systemImage: "gear")
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
                .accessibilityLabel("Camera, microphone, and photos")
            }
        }
        .safeAreaInset(edge: .bottom) {
            FormSaveBar(enabled: canSave, action: saveProfile)
        }
        .onAppear(perform: load)
        .confirmationDialog(
            "Replace the price book?",
            isPresented: $confirmKit,
            titleVisibility: .visible
        ) {
            Button("Replace with \(trade.label)") {
                guard canSave else { return }
                saveProfile()
                SeedData.replacePriceBook(with: trade, in: context)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Starter \(trade.label) prices replace the current price book. Jobs, quotes, and invoices stay.")
        }
        .confirmationDialog(
            "Reset demo data?",
            isPresented: $confirmReset,
            titleVisibility: .visible
        ) {
            Button("Replace sample data", role: .destructive) {
                guard canSave else { return }
                saveProfile()
                OperationalData.removeShopWork(in: context)
                SeedData.loadDemo(trade, in: context)
                Task { reminderCount = await InvoiceReminders.reschedule(in: context) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Customers, jobs, quotes, invoices, and the price book on this iPhone are replaced with the \(trade.label) sample.")
        }
        .confirmationDialog("Replace this shop?", isPresented: $confirmRestore, titleVisibility: .visible) {
            Button("Replace with backup", role: .destructive) {
                applyRestore()
            }
            Button("Cancel", role: .cancel) {
                pendingRestore = nil
            }
        } message: {
            Text("This removes the customers, jobs, quotes, invoices, photos, voice notes, and price book on this iPhone, and replaces the business profile. \(pendingRestore?.summary ?? "")")
        }
        .alert(noticeTitle, isPresented: $showNotice) {
            if noticeOffersSettings {
                Button("Open Settings") { openSystemSettings() }
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text(noticeMessage)
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.zip], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    inspectBackup(url)
                }
            case .failure:
                presentNotice("Couldn’t restore", "That file couldn’t be opened.")
            }
        }
        .fileShareSheet(
            url: $shareURL,
            failed: $shareFailed,
            failureTitle: "Couldn’t make the backup",
            failureMessage: "The shop is still on this iPhone. Try Backup again."
        )
    }

    private func backupShop() {
        do {
            shareURL = try ShopBackup.makeZip(in: context)
        } catch {
            presentNotice("Couldn’t make the backup", error.localizedDescription)
        }
    }

    private func setLock(_ enabled: Bool) async {
        guard lockBusy == false else { return }
        lockBusy = true
        defer { lockBusy = false }
        if let message = await appLock.setEnabled(enabled) {
            lockOn = appLock.isEnabled
            presentNotice("App Lock stayed off", message)
            return
        }
        lockOn = appLock.isEnabled
    }

    private func setReminders(_ enabled: Bool) async {
        guard remindersBusy == false else { return }
        remindersBusy = true
        defer { remindersBusy = false }
        do {
            reminderCount = try await InvoiceReminders.setEnabled(enabled, in: context)
            remindersOn = InvoiceReminders.isEnabled
            if enabled {
                presentNotice("Reminders on", reminderCaption)
            }
        } catch let error as InvoiceReminders.EnableFailure {
            remindersOn = InvoiceReminders.isEnabled
            presentNotice("Reminders stay off", error.localizedDescription, offerSettings: error.opensSettings)
        } catch {
            remindersOn = InvoiceReminders.isEnabled
            presentNotice("Reminders stay off", error.localizedDescription)
        }
    }

    private var reminderCaption: String {
        if reminderCount == 0 {
            return "No invoice needs a reminder right now. FieldForge schedules one for 8:00 AM when an invoice is due or overdue."
        }
        if reminderCount == 1 {
            return "1 reminder is scheduled for 8:00 AM on this iPhone."
        }
        return "\(reminderCount) reminders are scheduled for 8:00 AM on this iPhone."
    }

    private func presentNotice(_ title: String, _ message: String, offerSettings: Bool = false) {
        noticeTitle = title
        noticeMessage = message
        noticeOffersSettings = offerSettings
        showNotice = true
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func inspectBackup(_ url: URL) {
        Task { @MainActor in
            do {
                let preview = try ShopBackup.inspect(url)
                try? await Task.sleep(for: .milliseconds(400))
                pendingRestore = preview
                confirmRestore = true
            } catch {
                pendingRestore = nil
                presentNotice("Couldn’t restore", error.localizedDescription)
            }
        }
    }

    private var lockBinding: Binding<Bool> {
        Binding(
            get: { lockOn },
            set: { newValue in
                lockOn = newValue
                Task { await setLock(newValue) }
            }
        )
    }

    private var remindersBinding: Binding<Bool> {
        Binding(
            get: { remindersOn },
            set: { newValue in
                remindersOn = newValue
                Task { await setReminders(newValue) }
            }
        )
    }

    private func applyRestore() {
        guard let preview = pendingRestore else { return }
        pendingRestore = nil
        do {
            let report = try ShopBackup.restore(preview, into: profile, in: context)
            reloadForm()
            presentNotice("Restored", report.message)
            Task { reminderCount = await InvoiceReminders.reschedule(in: context) }
        } catch {
            presentNotice("Couldn’t restore", error.localizedDescription)
        }
    }

    private func reloadForm() {
        businessName = profile.businessName
        ownerName = profile.ownerName
        trade = profile.tradeKit
        phone = profile.phone
        email = profile.email
        cityLine = profile.cityLine
        taxBasisPoints = profile.taxBasisPoints
        quoteNotes = profile.defaultQuoteNotes
        terms = profile.defaultInvoiceTerms
    }

    private var version: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(short) (\(build))"
    }

    private func load() {
        guard didLoad == false else { return }
        didLoad = true
        businessName = profile.businessName
        ownerName = profile.ownerName
        trade = profile.tradeKit
        phone = profile.phone
        email = profile.email
        cityLine = profile.cityLine
        taxBasisPoints = profile.taxBasisPoints
        quoteNotes = profile.defaultQuoteNotes
        terms = profile.defaultInvoiceTerms
        lockOn = appLock.isEnabled
        remindersOn = InvoiceReminders.isEnabled
        Task { reminderCount = await InvoiceReminders.pendingCount() }
    }

    private func saveProfile() {
        profile.businessName = businessName.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.ownerName = ownerName.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.trade = trade.rawValue
        profile.phone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.cityLine = cityLine.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.taxBasisPoints = taxBasisPoints
        profile.defaultQuoteNotes = quoteNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.defaultInvoiceTerms = terms.trimmingCharacters(in: .whitespacesAndNewlines)
        try? context.save()
    }
}
