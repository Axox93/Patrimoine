import SwiftUI

enum Palette {
    static let background = Color(uiColor: .systemGroupedBackground)
    static let surface = Color(uiColor: .secondarySystemGroupedBackground)
    static let accent = Color("AccentColor")
    static let positive = Color("PositiveColor")
}

struct FinancialCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 16) { content }
            .padding(20).frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(.primary.opacity(0.04), lineWidth: 1))
    }
}

struct MoneyText: View {
    let value: Decimal?
    var currency = "EUR"
    @AppStorage("privacy.hideAmounts") private var hidden = false
    var body: some View {
        Text(hidden ? "••••" : value.map { $0.formatted(.currency(code: currency)) } ?? "Indisponible")
            .monospacedDigit().contentTransition(.numericText())
            .accessibilityLabel(hidden ? "Montant masqué" : value.map { $0.formatted(.currency(code: currency)) } ?? "Valorisation indisponible")
    }
}

struct PerformanceBadge: View {
    let value: Decimal
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: value >= 0 ? "arrow.up.right" : "arrow.down.right")
            MoneyText(value: value)
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(value >= 0 ? Palette.positive : .red)
        .padding(.horizontal, 11).padding(.vertical, 7)
        .background((value >= 0 ? Palette.positive : .red).opacity(0.12), in: Capsule())
    }
}

struct EmptyStateView: View {
    let title: String
    let message: String
    var symbol = "square.stack.3d.up"
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: symbol).font(.system(size: 36, weight: .light)).foregroundStyle(Palette.accent)
                .frame(width: 80, height: 80).background(Palette.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 25))
            Text(title).font(.title3.weight(.semibold))
            Text(message).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }.padding(.vertical, 30).frame(maxWidth: .infinity)
    }
}

struct InlineIssue: View {
    let message: String
    var body: some View {
        Label(message, systemImage: "exclamationmark.circle")
            .font(.footnote).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
    }
}

struct SectionHeading: View {
    let title: String
    var detail: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.title3.weight(.semibold))
            if let detail { Text(detail).font(.caption).foregroundStyle(.secondary) }
        }
    }
}

struct MetricRow: View {
    let title: String
    let value: Decimal?
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).foregroundStyle(.secondary)
            Spacer(minLength: 16)
            MoneyText(value: value).fontWeight(.medium)
        }.font(.subheadline)
    }
}

struct ErrorMessage: Identifiable {
    let id = UUID()
    let text: String
    init(_ error: Error) { text = error.localizedDescription }
}
