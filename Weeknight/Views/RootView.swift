import SwiftUI
import UIKit

struct RootView: View {
    @State private var store = AppStore()

    var body: some View {
        @Bindable var store = store

        TabView(selection: $store.selectedTab) {
            NavigationStack {
                PlanView()
            }
            .tabItem { Label("Plan", systemImage: "calendar") }
            .tag(AppTab.plan)

            NavigationStack {
                DiscoverView()
            }
            .tabItem { Label("Discover", systemImage: "rectangle.stack") }
            .tag(AppTab.discover)

            NavigationStack {
                SavedView()
            }
            .tabItem { Label("Saved", systemImage: "bookmark") }
            .tag(AppTab.saved)

            NavigationStack {
                PreferencesView()
            }
            .tabItem { Label("Preferences", systemImage: "slider.horizontal.3") }
            .tag(AppTab.preferences)
        }
        .tint(WeeknightTheme.bottle)
        .environment(store)
        .overlay(alignment: .bottom) {
            if let message = store.confirmationMessage {
                ConfirmationToast(message: message)
                    .padding(.horizontal, WeeknightTheme.Spacing.standard)
                    .padding(.bottom, 92)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .accessibilityAddTraits(.updatesFrequently)
            }
        }
        .animation(.easeOut(duration: 0.2), value: store.confirmationMessage)
        .onChange(of: store.confirmationMessage) { _, message in
            guard let message else { return }
            UIAccessibility.post(notification: .announcement, argument: message)
        }
        .task(id: store.confirmationMessage) {
            guard store.confirmationMessage != nil else { return }
            try? await Task.sleep(nanoseconds: 2_600_000_000)
            store.confirmationMessage = nil
        }
    }
}

private struct ConfirmationToast: View {
    let message: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(WeeknightTheme.mint)
            Text(message)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(WeeknightTheme.background)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(WeeknightTheme.forest)
        .clipShape(RoundedRectangle(cornerRadius: WeeknightTheme.Radius.row, style: .continuous))
        .shadow(color: .black.opacity(0.2), radius: 16, y: 8)
    }
}
