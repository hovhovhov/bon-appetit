import SwiftUI
import UIKit
import Observation

enum AppTab: Hashable {
    case plans
    case meals
    case preferences
    case settings
}

enum MealsSection: String, CaseIterable, Identifiable {
    case forYou = "For You"
    case saved = "Saved"

    var id: Self { self }
}

@MainActor
@Observable
final class AppNavigation {
    var selectedTab: AppTab
    var mealsSection: MealsSection
    let showsLegacyDiscoverFeed: Bool

    init(arguments: [String] = ProcessInfo.processInfo.arguments) {
        if arguments.contains("--start-preferences") {
            selectedTab = .preferences
        } else if arguments.contains("--start-settings") {
            selectedTab = .settings
        } else if arguments.contains("--start-discover") || arguments.contains("--start-saved") {
            selectedTab = .meals
        } else {
            selectedTab = .plans
        }
        mealsSection = arguments.contains("--start-saved") ? .saved : .forYou
#if DEBUG
        showsLegacyDiscoverFeed = arguments.contains("--legacy-discover-feed")
#else
        showsLegacyDiscoverFeed = false
#endif
    }

    func showPlans() {
        selectedTab = .plans
    }

    func showMeals(_ section: MealsSection = .forYou) {
        mealsSection = section
        selectedTab = .meals
    }

    func showPreferences() {
        selectedTab = .preferences
    }
}

struct RootView: View {
    @State private var store = AppStore()
    @State private var navigation = AppNavigation()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(red: 251 / 255, green: 248 / 255, blue: 236 / 255, alpha: 1)
        appearance.shadowColor = UIColor(red: 235 / 255, green: 227 / 255, blue: 210 / 255, alpha: 1)
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        @Bindable var store = store
        @Bindable var navigation = navigation

        TabView(selection: $navigation.selectedTab) {
            NavigationStack {
                PlanView()
            }
            .toolbarBackground(WeeknightTheme.background, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
            .tabItem { Label("Plans", systemImage: "calendar") }
            .tag(AppTab.plans)

            NavigationStack {
                MealsView()
            }
            .toolbarBackground(WeeknightTheme.background, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
            .tabItem { Label("Meals", systemImage: "fork.knife") }
            .tag(AppTab.meals)

            NavigationStack {
                PreferencesView()
            }
            .toolbarBackground(WeeknightTheme.background, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
            .tabItem { Label("Preferences", systemImage: "slider.horizontal.3") }
            .tag(AppTab.preferences)

            NavigationStack {
                SettingsView()
            }
            .toolbarBackground(WeeknightTheme.background, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
            .tabItem { Label("Settings", systemImage: "gearshape") }
            .tag(AppTab.settings)
        }
        .tint(WeeknightTheme.forest)
        .environment(store)
        .environment(navigation)
        .overlay(alignment: .bottom) {
            if let message = store.confirmationMessage {
                ConfirmationToast(message: message)
                    .padding(.horizontal, WeeknightTheme.Spacing.standard)
                    .padding(.bottom, 92)
                    .allowsHitTesting(false)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .accessibilityAddTraits(.updatesFrequently)
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: store.confirmationMessage)
        .onChange(of: store.confirmationMessage) { _, message in
            guard let message else { return }
            UIAccessibility.post(notification: .announcement, argument: message)
        }
        .task(id: store.confirmationMessage) {
            guard store.confirmationMessage != nil else { return }
            try? await Task.sleep(nanoseconds: 2_600_000_000)
            store.confirmationMessage = nil
        }
        .task {
            await store.connectBackendIfNeeded()
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
