//
//  ContentView.swift
//  GagaeSsi
//
//  메인 탭 뷰
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // 홈 탭
            NavigationStack {
                HomeView()
            }
            .tabItem {
                Label("홈", systemImage: selectedTab == 0 ? "house.fill" : "house")
            }
            .tag(0)

            // 소비 탭
            NavigationStack {
                SpendView()
            }
            .tabItem {
                Label("기록", systemImage: selectedTab == 1 ? "pencil.circle.fill" : "pencil.circle")
            }
            .tag(1)

            // 통계 탭
            NavigationStack {
                StatsView()
            }
            .tabItem {
                Label("통계", systemImage: selectedTab == 2 ? "chart.bar.fill" : "chart.bar")
            }
            .tag(2)

            // 설정 탭
            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("설정", systemImage: selectedTab == 3 ? "gearshape.fill" : "gearshape")
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
