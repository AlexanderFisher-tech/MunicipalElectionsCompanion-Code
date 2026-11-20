//
//  MainView.swift
//  Municipal Elections Companion
//
//  Created by Alexander Fisher
//

import SwiftUI

/// The signed-in app. Uses a tab bar of `NavigationStack`s in compact width (iPhone) and a
/// `NavigationSplitView` sidebar in regular width (iPad). Navigation state lives in `AppRouter`,
/// so switching between the two (rotation, multitasking) keeps the user's place.
struct MainView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        if horizontalSizeClass == .regular {
            SplitLayout()
        } else {
            TabLayout()
        }
    }
}

// MARK: - iPhone

private struct TabLayout: View {
    @Environment(AppRouter.self) private var router
    @Environment(SelectionsViewModel.self) private var selections

    var body: some View {
        @Bindable var router = router

        TabView(selection: $router.section) {
            Tab(AppSection.home.title, systemImage: AppSection.home.systemImage, value: .home) {
                NavigationStack {
                    HomeView()
                }
            }

            Tab(AppSection.candidates.title, systemImage: AppSection.candidates.systemImage, value: .candidates) {
                NavigationStack(path: $router.candidatesPath) {
                    CandidateDirectoryView()
                }
            }

            Tab(AppSection.selections.title, systemImage: AppSection.selections.systemImage, value: .selections) {
                NavigationStack(path: $router.selectionsPath) {
                    MySelectionsView()
                }
            }
            .badge(selections.selections.count)

            Tab(AppSection.profile.title, systemImage: AppSection.profile.systemImage, value: .profile) {
                NavigationStack {
                    ProfileView()
                }
            }
        }
    }
}

// MARK: - iPad

private struct SplitLayout: View {
    @Environment(AppRouter.self) private var router
    @Environment(SessionViewModel.self) private var session
    @Environment(SelectionsViewModel.self) private var selections

    var body: some View {
        @Bindable var router = router

        NavigationSplitView {
            List(selection: sidebarSelection) {
                Section {
                    ForEach(AppSection.allCases) { section in
                        NavigationLink(value: section) {
                            Label(section.title, systemImage: section.systemImage)
                                .badge(section == .selections ? selections.selections.count : 0)
                        }
                    }
                } header: {
                    CityLabel(city: session.cityName)
                        .textCase(nil)
                }
            }
            .navigationTitle("Elections Companion")
        } detail: {
            switch router.section {
            case .home:
                NavigationStack { HomeView() }
            case .candidates:
                NavigationStack(path: $router.candidatesPath) { CandidateDirectoryView() }
            case .selections:
                NavigationStack(path: $router.selectionsPath) { MySelectionsView() }
            case .profile:
                NavigationStack { ProfileView() }
            }
        }
    }

    /// The sidebar List needs an optional selection; the router always has one.
    private var sidebarSelection: Binding<AppSection?> {
        Binding(
            get: { router.section },
            set: { if let newValue = $0 { router.section = newValue } }
        )
    }
}
