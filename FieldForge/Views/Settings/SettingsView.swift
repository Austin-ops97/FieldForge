import SwiftData
import SwiftUI

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
    @State private var showSync = false

    private var canSave: Bool {
        businessName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            && ownerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    var body: some View {
        Form {
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
                Button {
                    SyncStub.markEverythingSynced(in: context)
                    showSync = true
                } label: {
                    Label("Mark changes synced", systemImage: "checkmark.icloud")
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
            } header: {
                Text("Shop")
            } footer: {
                Text("Sync only clears the on-device waiting marks. Nothing is uploaded.")
            }
            Section {
                Button("Reset demo data", role: .destructive) {
                    confirmReset = true
                }
                .frame(minHeight: 44)
            } footer: {
                Text("Replaces customers, jobs, quotes, invoices, photos, voice notes, and the price book with the \(trade.label) sample. Your business profile stays.")
            }
            Section("About") {
                LabeledContent("Version", value: version)
                Text("FieldForge keeps this shop on the iPhone. GPS, texting, QuickBooks, and card payments are not part of this build.")
                    .font(ForgeType.secondary)
                    .foregroundStyle(.secondary)
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
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Customers, jobs, quotes, invoices, and the price book on this iPhone are replaced with the \(trade.label) sample.")
        }
        .alert("Sync", isPresented: $showSync) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Changes on this iPhone are marked synced.")
        }
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
