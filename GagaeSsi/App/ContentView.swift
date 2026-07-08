//
//  ContentView.swift
//  GagaeSsi
//
//  메인 탭 뷰
//

import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState
        TabView(selection: $appState.selectedTab) {
            // 홈 탭
            NavigationStack {
                HomeView()
            }
            .tabItem {
                Label("홈", systemImage: appState.selectedTab == 0 ? "house.fill" : "house")
            }
            .tag(0)

            // 소비 탭
            NavigationStack {
                SpendView()
            }
            .tabItem {
                Label("기록", systemImage: appState.selectedTab == 1 ? "pencil.circle.fill" : "pencil.circle")
            }
            .tag(1)

            // 통계 탭
            NavigationStack {
                StatsView()
            }
            .tabItem {
                Label("통계", systemImage: appState.selectedTab == 2 ? "chart.bar.fill" : "chart.bar")
            }
            .tag(2)

            // 설정 탭
            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("설정", systemImage: appState.selectedTab == 3 ? "gearshape.fill" : "gearshape")
            }
            .tag(3)
        }
        .tint(.gagaePinkDark)
    }
}

#Preview {
    ContentView()
        .environment(AppEventBus())
        .environment(AppState())
}
