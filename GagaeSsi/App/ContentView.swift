//
//  ContentView.swift
//  GagaeSsi
//
//  메인 탭 뷰 (MainTabBarController 대체)
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
                Label("홈", systemImage: "house")
            }
            .tag(0)
            
            // 소비 탭
            NavigationStack {
                SpendView()
            }
            .tabItem {
                Label("소비", systemImage: "creditcard")
            }
            .tag(1)
            
            // 통계 탭
            NavigationStack {
                StatsView()
            }
            .tabItem {
                Label("통계", systemImage: "chart.bar")
            }
            .tag(2)
            
            // 설정 탭
            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("설정", systemImage: "gearshape")
            }
            .tag(3)
        }
    }
}

#Preview {
    ContentView()
        .environment(AppEventBus())
}
