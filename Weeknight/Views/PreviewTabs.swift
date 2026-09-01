import SwiftUI

struct SavedPreviewView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Saved")
                    .font(.largeTitle.weight(.heavy))
                    .foregroundStyle(WeeknightTheme.primaryText)
                StatusPill(
                    text: "Milestone 1 preview",
                    color: WeeknightTheme.bottle,
                    background: WeeknightTheme.wash,
                    systemImage: "hammer.fill"
                )
                VStack(alignment: .leading, spacing: 10) {
                    Image(systemName: "bookmark")
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundStyle(WeeknightTheme.bottle)
                    Text("Saved recipes arrive in Milestone 2")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(WeeknightTheme.primaryText)
                    Text("This preview intentionally contains no inactive search, filter, or save controls. Discover and Add to week are fully functional now.")
                        .font(.body)
                        .foregroundStyle(WeeknightTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(22)
                .weeknightCard()
            }
            .padding(WeeknightTheme.Spacing.gutter)
        }
        .background(WeeknightTheme.background.ignoresSafeArea())
        .navigationBarHidden(true)
    }
}

struct PreferencesPreviewView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Your setup")
                    .font(.largeTitle.weight(.heavy))
                    .foregroundStyle(WeeknightTheme.primaryText)
                Text("Preferences editing is planned for a later milestone. These values describe the active fixture and are read-only here.")
                    .font(.body)
                    .foregroundStyle(WeeknightTheme.secondaryText)

                VStack(alignment: .leading, spacing: 8) {
                    Text("PLANNING FOR")
                        .font(.caption.weight(.bold))
                        .tracking(1.3)
                        .foregroundStyle(WeeknightTheme.background.opacity(0.62))
                    Text("1 person · 5 dinners a week · \(store.plan.budget.formatted()) at \(store.plan.storeName)")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(WeeknightTheme.background)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(WeeknightTheme.deepPine)
                .clipShape(RoundedRectangle(cornerRadius: WeeknightTheme.Radius.card, style: .continuous))

                VStack(spacing: 0) {
                    staticRow("Supermarket", value: store.plan.storeName, effect: "Prices")
                    Divider().padding(.leading, 16)
                    staticRow("Cooking days", value: "Mon, Tue, Wed, Thu, Fri", effect: "Plan")
                    Divider().padding(.leading, 16)
                    staticRow("Weekly budget", value: store.plan.budget.formatted(), effect: "Budget")
                }
                .weeknightCard()

                Button {
                    store.resetFixture()
                } label: {
                    Label("Reset demo week", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(ForestActionButtonStyle())
                .accessibilityHint("Restores the canonical three-dinner fixture and shopping progress")
                .accessibilityIdentifier("reset-fixture")
            }
            .padding(WeeknightTheme.Spacing.gutter)
        }
        .background(WeeknightTheme.background.ignoresSafeArea())
        .navigationBarHidden(true)
    }

    private func staticRow(_ title: String, value: String, effect: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(WeeknightTheme.primaryText)
                Text(effect.uppercased())
                    .font(.caption2.weight(.bold))
                    .tracking(0.8)
                    .foregroundStyle(WeeknightTheme.bottle)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(WeeknightTheme.wash)
                    .clipShape(Capsule())
            }
            Text(value)
                .font(.body)
                .foregroundStyle(WeeknightTheme.secondaryText)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

