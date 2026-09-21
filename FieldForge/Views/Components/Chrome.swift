import SwiftUI

struct StatusChip: View {
    var title: String
    var tint: Color

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(tint)
                .frame(width: 8, height: 8)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(tint.opacity(0.12), in: Capsule())
        .fixedSize(horizontal: true, vertical: false)
        .layoutPriority(1)
        .accessibilityLabel("Status \(title)")
    }
}

struct FilterChip: View {
    var title: String
    var selected: Bool
    var tint: Color = ForgeTheme.ink
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .background(selected ? tint : Color(.secondarySystemFill), in: Capsule())
                .foregroundStyle(selected ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
    }
}

struct PrimaryButton: View {
    var title: String
    var systemImage: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.roundedRectangle(radius: ForgeTheme.Radius.m))
        .tint(ForgeTheme.accent)
    }
}

struct QuietActionButton: View {
    var title: String
    var systemImage: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .foregroundStyle(ForgeTheme.ink)
                .frame(maxWidth: .infinity, minHeight: 52)
                .padding(.horizontal, ForgeTheme.Space.xs)
                .background(ForgeTheme.surface, in: RoundedRectangle(cornerRadius: ForgeTheme.Radius.m, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: ForgeTheme.Radius.m, style: .continuous)
                        .strokeBorder(ForgeTheme.border, lineWidth: 1)
                }
        }
        .buttonStyle(ForgePressStyle())
    }
}

struct FormSaveBar: View {
    var title: String = "Save"
    var enabled: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 48)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.roundedRectangle(radius: ForgeTheme.Radius.m))
        .tint(ForgeTheme.accent)
        .disabled(enabled == false)
        .padding(.horizontal, ForgeTheme.Space.s)
        .padding(.top, ForgeTheme.Space.xs)
        .padding(.bottom, ForgeTheme.Space.xxs)
        .background(.ultraThinMaterial)
    }
}

/// Wraps status chips onto extra lines so long labels stay intact at larger type sizes.
struct ChipFlow: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let width = proposal.width ?? 320
        let rows = rows(in: width, subviews: subviews)
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        let rows = rows(in: bounds.width, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            for index in row.indexes {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(
                    at: CGPoint(x: x, y: y),
                    proposal: ProposedViewSize(width: size.width, height: size.height)
                )
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indexes: [Int]
        var height: CGFloat
    }

    private func rows(in width: CGFloat, subviews: Subviews) -> [Row] {
        var result: [Row] = []
        var indexes: [Int] = []
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = indexes.isEmpty ? size.width : rowWidth + spacing + size.width
            if needed > width, indexes.isEmpty == false {
                result.append(Row(indexes: indexes, height: rowHeight))
                indexes = [index]
                rowWidth = size.width
                rowHeight = size.height
            } else {
                indexes.append(index)
                rowWidth = needed
                rowHeight = max(rowHeight, size.height)
            }
        }
        if indexes.isEmpty == false {
            result.append(Row(indexes: indexes, height: rowHeight))
        }
        return result
    }
}

struct EmptyHint: View {
    var title: String
    var message: String
    var systemImage: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(message)
        } actions: {
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension View {
    func forgeRoutes() -> some View {
        navigationDestination(for: ForgeRoute.self) { route in
            ForgeDestination(route: route)
        }
    }
}
