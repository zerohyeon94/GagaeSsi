//
//  SpendReminderSettingView.swift
//  GagaeSsi
//
//  소비 기록 리마인더 알림 설정 — on/off + 알림 시각
//

import SwiftUI

struct SpendReminderSettingView: View {
    @Environment(AppEventBus.self) private var eventBus

    @State private var enabled = false
    @State private var time = Date()
    @State private var showDeniedAlert = false

    var body: some View {
        ZStack {
            GagaeBackground()

            ScrollView {
                VStack(spacing: GagaeSpacing.md) {
                    toggleCard
                    if enabled { timeCard }
                    explainCard
                }
                .padding(.horizontal, GagaeSpacing.md)
                .padding(.vertical, GagaeSpacing.md)
            }
        }
        .navigationTitle("소비 기록 알림")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: load)
        .alert("알림 권한이 꺼져 있어요", isPresented: $showDeniedAlert) {
            Button("취소", role: .cancel) {}
            Button("설정 열기") { openSystemSettings() }
        } message: {
            Text("시스템 설정 > 가계씨 > 알림에서 알림을 허용해주세요.")
        }
    }

    // MARK: - Cards

    private var toggleCard: some View {
        GagaeCard {
            VStack(alignment: .leading, spacing: GagaeSpacing.sm) {
                Toggle(isOn: Binding(get: { enabled }, set: { toggle($0) })) {
                    Text("소비 기록 리마인더")
                        .font(.gagaeCalloutMedium).foregroundStyle(.gagaeText)
                }
                .tint(.gagaePinkDark)

                Text("정한 시각에 오늘 소비를 기록했는지 알려드려요.\n그날 이미 기록했다면 알림이 오지 않아요.")
                    .font(.gagaeFootnote).foregroundStyle(.gagaeTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var timeCard: some View {
        GagaeCard {
            DatePicker("알림 시각", selection: $time, displayedComponents: .hourAndMinute)
                .font(.gagaeCalloutMedium)
                .foregroundStyle(.gagaeText)
                .tint(.gagaePinkDark)
                .environment(\.locale, Locale(identifier: "ko_KR"))
                .onChange(of: time) { _, _ in save() }
        }
    }

    private var explainCard: some View {
        GagaeCard {
            VStack(alignment: .leading, spacing: GagaeSpacing.sm) {
                Text("알림은 이렇게 동작해요")
                    .font(.gagaeCalloutMedium).foregroundStyle(.gagaeText)
                bullet("그날 소비를 한 건이라도 기록하면 그날 알림은 취소돼요.")
                bullet("앱을 2주 넘게 열지 않으면 알림이 끊겨요. 다시 열면 이어서 예약해요.")
                bullet("설정한 시각이 이미 지났다면 오늘은 건너뛰고 내일부터 알려드려요.")
            }
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("•").font(.gagaeCaption).foregroundStyle(.gagaeTextTertiary)
            Text(text)
                .font(.gagaeCaption).foregroundStyle(.gagaeTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Actions

    private func load() {
        let config = CoreDataManager.shared.fetchBudgetConfig()
        enabled = config?.spendReminderEnabled ?? false
        let hour = config?.spendReminderHour ?? SpendReminderSchedule.defaultHour
        let minute = config?.spendReminderMinute ?? SpendReminderSchedule.defaultMinute
        time = Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
    }

    private func toggle(_ newValue: Bool) {
        guard newValue else {
            enabled = false
            save()
            return
        }
        // 켤 때만 권한을 요청한다 (이미 거부된 상태면 시스템 설정으로 안내)
        NotificationService.shared.requestAuthorization { granted in
            if granted {
                enabled = true
                save()
            } else {
                enabled = false
                showDeniedAlert = true
            }
        }
    }

    private func save() {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: time)
        CoreDataManager.shared.updateSpendReminder(enabled: enabled,
                                                   hour: comps.hour ?? SpendReminderSchedule.defaultHour,
                                                   minute: comps.minute ?? SpendReminderSchedule.defaultMinute)
        eventBus.notifyBudgetChanged()
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

#Preview {
    NavigationStack {
        SpendReminderSettingView()
    }
    .environment(AppEventBus())
}
