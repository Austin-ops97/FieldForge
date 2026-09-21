import SwiftUI

/// Quiet visual system for FieldForge: ink, one accent, hairline cards, a spacing scale.
enum ForgeTheme {
    static let copper = Color(red: 0.769, green: 0.471, blue: 0.227)
    static let navy = Color(red: 0.106, green: 0.220, blue: 0.290)
    static let paid = Color(red: 0.176, green: 0.490, blue: 0.345)
    static let overdue = Color(red: 0.70, green: 0.22, blue: 0.18)

    static let lead = Color(red: 0.36, green: 0.40, blue: 0.62)
    static let scheduled = Color(red: 0.18, green: 0.42, blue: 0.72)
    static let draft = Color(red: 0.33, green: 0.36, blue: 0.55)
    static let sent = Color(red: 0.12, green: 0.48, blue: 0.62)

    /// Brand accent. Used on the tab bar and primary actions.
    static let accent = copper
    /// Primary ink for ledger cards and selected filters.
    static let ink = navy
    static let money = navy
    static let surface = Color(.secondarySystemGroupedBackground)
    static let canvas = Color(.systemGroupedBackground)
    static let border = Color.primary.opacity(0.08)

    enum Radius {
        static let s: CGFloat = 10
        static let m: CGFloat = 14
        static let l: CGFloat = 20
    }

    enum Space {
        static let xxs: CGFloat = 8
        static let xs: CGFloat = 12
        static let s: CGFloat = 16
        static let m: CGFloat = 20
        static let l: CGFloat = 24
    }

    static func jobTint(_ status: JobStatus) -> Color {
        switch status {
        case .lead: return lead
        case .scheduled: return scheduled
        case .inProgress: return copper
        case .done: return paid
        }
    }

    static func quoteTint(_ status: QuoteStatus) -> Color {
        switch status {
        case .draft: return draft
        case .sent: return sent
        case .accepted: return paid
        case .declined: return overdue
        }
    }

    static func invoiceTint(_ status: InvoiceStatus) -> Color {
        switch status {
        case .draft: return draft
        case .sent: return sent
        case .paid: return paid
        case .overdue: return overdue
        }
    }
}

enum ForgeType {
    static let largeTitle = Font.largeTitle.weight(.bold)
    static let section = Font.title3.weight(.semibold)
    static let rowTitle = Font.body.weight(.semibold)
    static let secondary = Font.subheadline
    static let caption = Font.footnote
    static let overline = Font.caption.weight(.semibold)
    static let heroMoney = Font.largeTitle.weight(.semibold).monospacedDigit()
    static let money = Font.title2.weight(.semibold).monospacedDigit()
    static let rowMoney = Font.body.weight(.semibold).monospacedDigit()
}

extension View {
    func forgeCard(radius: CGFloat = ForgeTheme.Radius.m) -> some View {
        background(ForgeTheme.surface, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(ForgeTheme.border, lineWidth: 1)
            }
    }
}

struct ForgePressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.72 : 1)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
