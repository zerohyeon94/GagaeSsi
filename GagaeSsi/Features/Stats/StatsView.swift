//
//  StatsView.swift
//  GagaeSsi
//
//  통계 화면 (StatsViewController 대체)
//

import SwiftUI

struct StatsView: View {
    // MARK: - Body
    var body: some View {
        VStack {
            Spacer()
            
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text("통계 기능 준비 중")
                .font(.title2)
                .foregroundStyle(.secondary)
                .padding(.top, 16)
            
            Text("소비 통계와 분석 기능이\n곧 추가될 예정입니다")
                .font(.body)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
            
            Spacer()
        }
        .navigationTitle("통계")
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        StatsView()
    }
}
