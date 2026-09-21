import SwiftData
import SwiftUI

struct OnboardingView: View {
    @Environment(\.modelContext) private var context

    @State private var businessName = ""
    @State private var ownerName = ""
    @State private var trade: TradeKit = .plumbing
    @State private var phone = ""
    @State private var email = ""
    @State private var cityLine = ""
    @State private var taxBasisPoints = 825
    @State private var quoteNotes = ""
    @State private var terms = "Payment due in 14 days."
    @State private var loadDemo = false
    @State private var didFinish = false

    private var canContinue: Bool {
        businessName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            && ownerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Your name goes on every quote and invoice.")
                        .font(ForgeType.secondary)
                        .foregroundStyle(.secondary)
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
                    Text("Continuing adds a starter price book for this trade. Sample customers are optional.")
                        .font(ForgeType.caption)
                        .foregroundStyle(.secondary)
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
                }
                Section {
                    Toggle("Load sample customers and jobs", isOn: $loadDemo)
                    Button {
                        useRiversideDemo()
                    } label: {
                        Label("Load Riverside Plumbing demo", systemImage: "wrench.and.screwdriver")
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    }
                } footer: {
                    Text("The Riverside demo is Maria Chen, a draft quote, and an overdue invoice. Your own shop can start empty except for the price book.")
                }
            }
            .navigationTitle("Set up FieldForge")
            .safeAreaInset(edge: .bottom) {
                FormSaveBar(title: "Continue", enabled: canContinue) {
                    finish(demo: loadDemo)
                }
            }
        }
    }

    private func useRiversideDemo() {
        businessName = "Riverside Plumbing"
        ownerName = "Alex Rivera"
        trade = .plumbing
        phone = ""
        email = ""
        cityLine = "Austin, TX"
        taxBasisPoints = 825
        quoteNotes = ""
        terms = "Payment due in 14 days."
        loadDemo = true
        finish(demo: true)
    }

    private func finish(demo: Bool) {
        guard didFinish == false else { return }
        let name = businessName.trimmingCharacters(in: .whitespacesAndNewlines)
        let owner = ownerName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard name.isEmpty == false, owner.isEmpty == false else { return }
        didFinish = true
        let profile = BusinessProfile(
            businessName: name,
            ownerName: owner,
            trade: trade.rawValue,
            phone: phone.trimmingCharacters(in: .whitespacesAndNewlines),
            email: email.trimmingCharacters(in: .whitespacesAndNewlines),
            cityLine: cityLine.trimmingCharacters(in: .whitespacesAndNewlines),
            taxBasisPoints: taxBasisPoints,
            defaultQuoteNotes: quoteNotes.trimmingCharacters(in: .whitespacesAndNewlines),
            defaultInvoiceTerms: terms.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        context.insert(profile)
        if demo {
            SeedData.loadDemo(trade, in: context)
        } else {
            SeedData.loadPriceKit(trade, in: context)
        }
        try? context.save()
    }
}
