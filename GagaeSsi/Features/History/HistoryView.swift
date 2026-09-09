//
//  HistoryView.swift
//  GagaeSsi
//
//  소비 내역 (월간 캘린더 + 날짜별 목록)
//

import SwiftUI

struct HistoryView: View {
    @Environment(AppEventBus.self) private var eventBus
    @State private var viewModel = HistoryViewModel()
    @State private var editingRecord: SpendingRecordModel?

    private let cols = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)
    private let weekdays = ["일", "월", "화", "수", "목", "금", "토"]

    var body: some View {
        ZStack {
            GagaeBackground()
            ScrollView {
                VStack(spacing: 14) {
                    largeTitle
                    monthNavigator
                    calendarCard
                    dayListCard
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
            }
        }
        .navigationBarHidden(true)
        .onAppear { viewModel.load() }
        .onChange(of: eventBus.spendingAddedTrigger) { viewModel.load() }
        .sheet(item: $editingRecord) { record in
            HistorySpendEditView(record: record) {
                viewModel.afterEdit(eventBus: eventBus)
            }
        }
    }
}

// MARK: - Sections
private extension HistoryView {
    var largeTitle: some View {
        HStack {
            Text("내역").font(.system(size: 34, weight: .heavy, design: .rounded)).foregroundStyle(.gagaeText)
            Spacer()
        }
        .padding(.top, 8)
    }

    var monthNavigator: some View {
        HStack {
            Button { viewModel.goPrevMonth() } label: {
                Image(systemName: "chevron.left").font(.system(size: 15, weight: .bold)).foregroundStyle(.gagaePinkDark)
                    .frame(width: 36, height: 36).background(Color.gagaeCardBackground).clipShape(Circle())
            }
            Spacer()
            VStack(spacing: 2) {
                Text(viewModel.monthLabel).font(.system(size: 17, weight: .bold, design: .rounded)).foregroundStyle(.gagaeText)
                Text("소비 " + FormatterUtils.currencyString(from: viewModel.monthTotal))
                    .font(.system(size: 12, weight: .medium, design: .rounded)).foregroundStyle(.gagaeTextSecondary)
            }
            Spacer()
            Button { viewModel.goNextMonth() } label: {
                Image(systemName: "chevron.right").font(.system(size: 15, weight: .bold))
                    .foregroundStyle(viewModel.canGoNext ? .gagaePinkDark : Color.gagaeDivider)
                    .frame(width: 36, height: 36).background(Color.gagaeCardBackground).clipShape(Circle())
            }
            .disabled(!viewModel.canGoNext)
        }
    }

    var calendarCard: some View {
        VStack(spacing: 8) {
            HStack(spacing: 2) {
                ForEach(Array(weekdays.enumerated()), id: \.offset) { i, w in
                    Text(w)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(i == 0 ? .gagaeDanger : (i == 6 ? .gagaePinkDark : .gagaeTextTertiary))
                        .frame(maxWidth: .infinity)
                }
            }
            LazyVGrid(columns: cols, spacing: 2) {
                ForEach(Array(viewModel.monthGrid().enumerated()), id: \.offset) { _, date in
                    if let date { dayCell(date) } else { Color.clear.frame(height: 44) }
                }
            }
        }
        .padding(14)
        .background(Color.gagaeCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .gagaeCardShadow()
    }

    func dayCell(_ date: Date) -> some View {
        let selected = viewModel.isSelected(date)
        let future = viewModel.isFuture(date)
        return Button {
            if !future { viewModel.select(date) }
        } label: {
            VStack(spacing: 3) {
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.system(size: 13, weight: selected ? .heavy : .medium, design: .rounded))
                    .foregroundStyle(future ? Color.gagaeDivider : (selected ? .white : .gagaeText))
                if viewModel.hasRecord(on: date) {
                    Circle().fill(selected ? Color.white : statusColor(viewModel.status(on: date))).frame(width: 5, height: 5)
                } else {
                    Circle().fill(.clear).frame(width: 5, height: 5)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                Group {
                    if selected { Capsule().fill(Color.gagaePinkDark) }
                    else if viewModel.isToday(date) { Capsule().stroke(Color.gagaePinkDark, lineWidth: 1.5) }
                }
            )
        }
        .buttonStyle(.plain)
        .disabled(future)
    }

    func statusColor(_ s: Int) -> Color {
        switch s { case 2: return .gagaeDanger; case 1: return Color(hex: "#FB8B1A"); default: return .gagaeGood }
    }

    var dayListCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(viewModel.selectedDateLabel).font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(.gagaeText)
                Spacer()
                if !viewModel.selectedRecords.isEmpty {
                    Text(FormatterUtils.currencyString(from: viewModel.selectedRecords.reduce(0) { $0 + $1.myShare }))
                        .font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(.gagaeDanger)
                }
            }

            // 그날 실제로 넘겼는지 — 소비액만 봐서는 이월 때문에 판단할 수 없다
            if viewModel.selectedOverspentAmount > 0 {
                HStack(spacing: 6) {
                    Text("⚠️").font(.system(size: 12))
                    Text("이 날 \(FormatterUtils.currencyString(from: viewModel.selectedOverspentAmount)) 초과했어요")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.gagaeDanger)
                    Spacer()
                    Text("쓸 수 있던 \(FormatterUtils.currencyString(from: viewModel.selectedAvailable))")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.gagaeTextSecondary)
                }
                .padding(.horizontal, 10).padding(.vertical, 7)
                .background(Color.gagaeDanger.opacity(0.09))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            if viewModel.selectedRecords.isEmpty {
                Text("이 날은 소비 기록이 없어요")
                    .font(.system(size: 13, design: .rounded)).foregroundStyle(.gagaeTextTertiary)
                    .frame(maxWidth: .infinity).padding(.vertical, 20)
            } else {
                ForEach(viewModel.selectedRecords) { record in
                    recordRow(record)
                    if record.id != viewModel.selectedRecords.last?.id {
                        Rectangle().fill(Color.gagaeDivider).frame(height: 0.5).padding(.leading, 46)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.gagaeCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .gagaeCardShadow()
    }

    func recordRow(_ record: SpendingRecordModel) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(record.category.color.opacity(0.13)).frame(width: 34, height: 34)
                Text(record.category.emoji).font(.system(size: 16))
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(record.title.isEmpty ? record.category.rawValue : record.title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundStyle(.gagaeText).lineLimit(1)
                if record.expectedPayback > 0 {
                    Text(record.paybackReceived ? "✅ 환급 완료" : "💳 환급 예정 \(FormatterUtils.currencyString(from: record.expectedPayback))")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(record.paybackReceived ? .gagaeGood : .gagaePinkDark)
                }
                // 모아둔 지갑에서 나간 소비는 그날 예산을 줄이지 않았다 — 구분해서 보여준다
                if record.wishItemId != nil {
                    Text("🎁 모아둔 위시에서 씀")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(.gagaeGood)
                }
            }
            Spacer()
            Text("-" + FormatterUtils.currencyString(from: record.amount))
                .font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.gagaeDanger)
            Menu {
                Button("수정") { editingRecord = record }
                Button("삭제", role: .destructive) { viewModel.delete(record, eventBus: eventBus) }
            } label: {
                Image(systemName: "ellipsis").font(.system(size: 15, weight: .bold)).foregroundStyle(.gagaeTextTertiary)
                    .frame(width: 28, height: 28)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture { editingRecord = record }
    }
}

#Preview {
    NavigationStack { HistoryView() }
        .environment(AppEventBus())
}
