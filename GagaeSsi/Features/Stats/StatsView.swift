//
//  StatsView.swift
//  GagaeSsi
//
//  Created by 조영현 on 2/3/26.
//

import SwiftUI

struct StatsView: View {
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

#Preview {
    NavigationStack {
        StatsView()
    }
}
