//
//  SpendView.swift
//  GagaeSsi
//
//  소비 기록 화면 (Claude Design 적용)
//

import SwiftUI

struct SpendView: View {
    // MARK: - Properties
    @State private var viewModel = SpendViewModel()
    @Environment(AppEventBus.self) private var eventBus
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?
    @State private var justSaved = false

    enum Field { case title, amount }

    // MARK: - Body
    var body: some View {
        ZStack {
            GagaeBackground()

            ScrollView {
                VStack(spacing: 14) {
                    inputCard
                        .padding(.top, 8)

                    saveButton

                    spendingListSection
                        .padding(.bottom, 28)
                }
                .padding(.horizontal, 16)
            }
        }
        .navigationTitle("소비 기록")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(Color.gagaePinkGradientTop, for: .navigationBar)
        .onAppear {
            let today = Calendar.current.startOfDay(for: Date())
            viewModel.fetchSpending(on: today)
        }
        .alert("오류", isPresented: $viewModel.showErrorAlert) {
            Button("확인", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage)
        }
        .onTapGesture { focusedField = nil }
    }
}

// MARK: - Input Card
extension SpendView {

    private var inputCard: some View {
        VStack(spacing: 0) {
            // 헤더
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gagaePinkLight)
                    .frame(width: 30, height: 30)
                    .overlay(
                        Image(systemName: viewModel.isEditing ? "pencil.line" : "pencil")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.gagaePinkDark)
                    )
                Text(viewModel.isEditing ? "지출 수정 중" : "오늘 쓴 거 기록해요")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.gagaeText)
                Spacer()
                if viewModel.isEditing {
                    Button {
                        focusedField = nil
                        withAnimation { viewModel.cancelEdit() }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "xmark")
                                .font(.system(size: 11, weight: .bold))
                            Text("취소")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(.gagaeTextSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color(hex: "#F5F5F5"))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 12)

            Rectangle().fill(Color.gagaeDivider).frame(height: 0.5)
                .padding(.horizontal, 16)

            VStack(spacing: 18) {
                categoryField
                contentField
                amountField
                dateField
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 16)
        }
        .background(Color.gagaeCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .gagaeCardShadow()
    }

    private func fieldLabel(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 5) {
            Text(icon).font(.system(size: 13))
            Text(text)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.gagaeTextSecondary)
        }
    }

    /// ① 카테고리
    private var categoryField: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel("🏷", "카테고리")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(SpendingCategory.allCases, id: \.self) { category in
                        categoryChip(category)
                    }
                }
                .padding(.horizontal, 1)
                .padding(.bottom, 2)
            }
        }
    }

    private func categoryChip(_ category: SpendingCategory) -> some View {
        let isSelected = viewModel.tempCategory == category
        return Button {
            viewModel.tempCategory = category
        } label: {
            HStack(spacing: 5) {
                Text(category.emoji).font(.system(size: 14))
                Text(category.rawValue)
                    .font(.system(size: 13, weight: isSelected ? .bold : .medium, design: .rounded))
                    .foregroundStyle(isSelected ? .white : .gagaeTextSecondary)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 7)
            .background(isSelected ? category.color : Color(hex: "#F5F5F5"))
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(isSelected ? .clear : Color.gagaeDivider, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.12), value: viewModel.tempCategory)
    }

    /// ② 내용
    private var contentField: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel("📝", "내용")
            TextField("예: 점심 식사, 카페라떼", text: $viewModel.tempTitle)
                .font(.system(size: 15, design: .rounded))
                .foregroundStyle(.gagaeText)
                .focused($focusedField, equals: .title)
                .frame(height: 46)
                .padding(.horizontal, 14)
                .background(Color.gagaeSurface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(focusedField == .title ? Color.gagaePinkDark : Color.gagaeDivider,
                                lineWidth: focusedField == .title ? 1.8 : 1.5)
                )
        }
    }

    /// ③ 금액
    private var amountField: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel("₩", "금액")
            HStack(spacing: 0) {
                Text("₩")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.gagaePinkDark)
                    .frame(width: 46, height: 46)
                    .overlay(alignment: .trailing) {
                        Rectangle()
                            .fill(focusedField == .amount ? Color.gagaePinkLight : Color.gagaeDivider)
                            .frame(width: 1.5)
                    }

                TextField("0", text: $viewModel.tempAmountText)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.gagaeText)
                    .keyboardType(.numberPad)
                    .focused($focusedField, equals: .amount)
                    .padding(.horizontal, 14)
                    .onChange(of: viewModel.tempAmountText) { _, newValue in
                        viewModel.updateAmountFromText(newValue)
                    }

                if viewModel.tempAmount > 0 {
                    Text("원")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(.gagaeTextSecondary)
                        .padding(.trailing, 14)
                }
            }
            .frame(height: 46)
            .background(Color.gagaeSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(focusedField == .amount ? Color.gagaePinkDark : Color.gagaeDivider,
                            lineWidth: focusedField == .amount ? 1.8 : 1.5)
            )
        }
    }

    /// ④ 날짜
    private var dateField: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel("📅", "날짜")
            HStack {
                DatePicker("", selection: $viewModel.tempDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .tint(.gagaePinkDark)
                Spacer()
                if Calendar.current.isDateInToday(viewModel.tempDate) {
                    Text("오늘")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.gagaePinkDark)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.gagaePinkLight)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            .frame(height: 46)
            .padding(.horizontal, 14)
            .background(Color.gagaeSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gagaeDivider, lineWidth: 1.5)
            )
        }
    }
}

// MARK: - Save Button
extension SpendView {
    private var saveButton: some View {
        Button {
            focusedField = nil
            viewModel.saveSpending(eventBus: eventBus) { success in
                if success {
                    let today = Calendar.current.startOfDay(for: Date())
                    viewModel.fetchSpending(on: today)
                    viewModel.clearForm()
                    withAnimation { justSaved = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                        withAnimation { justSaved = false }
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                if justSaved {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                    Text("저장 완료!")
                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                } else {
                    ZStack {
                        Circle().stroke(.white.opacity(0.6), lineWidth: 2).frame(width: 26, height: 26)
                        Image(systemName: viewModel.isEditing ? "checkmark" : "plus")
                            .font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
                    }
                    Text(viewModel.isEditing ? "수정 완료" : "저장하기")
                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                justSaved
                    ? LinearGradient(colors: [.gagaeGood, .gagaeGood], startPoint: .leading, endPoint: .trailing)
                    : LinearGradient(colors: [.gagaePinkDark, .gagaePink], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(Capsule())
            .gagaeShadow(color: (justSaved ? Color.gagaeGood : Color.gagaePinkDark).opacity(0.32), radius: 14, y: 10)
        }
        .buttonStyle(.plain)
        .disabled(!viewModel.isValid && !justSaved)
        .opacity((viewModel.isValid || justSaved) ? 1 : 0.55)
        .animation(.easeInOut(duration: 0.25), value: justSaved)
    }
}

// MARK: - Today's List
extension SpendView {
    private var spendingListSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("오늘 지출 목록")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.gagaeText)
                Spacer()
                if !viewModel.spendingRecords.isEmpty {
                    Text("총 -" + FormatterUtils.currencyString(from: viewModel.totalSpentToday))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.gagaeDanger)
                }
            }
            .padding(.horizontal, 2)

            if viewModel.spendingRecords.isEmpty {
                VStack(spacing: 8) {
                    Text("🐷").font(.system(size: 32))
                    Text("아직 기록된 지출이 없어요")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.gagaeTextTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .background(Color.gagaeCardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .gagaeCardShadow()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(viewModel.spendingRecords.enumerated()), id: \.element.id) { index, record in
                        spendingRow(record: record)
                        if index < viewModel.spendingRecords.count - 1 {
                            Rectangle().fill(Color.gagaeDivider).frame(height: 0.5)
                                .padding(.leading, 68)
                        }
                    }
                }
                .background(Color.gagaeCardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .gagaeCardShadow()

                // 합계 요약
                HStack {
                    Text("\(viewModel.spendingRecords.count)건의 지출")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.gagaeTextSecondary)
                    Spacer()
                    Text("총 지출")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.gagaeTextSecondary)
                    Text("-" + FormatterUtils.currencyString(from: viewModel.totalSpentToday))
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(.gagaeDanger)
                }
                .padding(.horizontal, 4)
            }
        }
    }

    private func spendingRow(record: SpendingRecordModel) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(record.category.color.opacity(0.13))
                    .frame(width: 40, height: 40)
                Text(record.category.emoji).font(.system(size: 19))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(record.title.isEmpty ? record.category.rawValue : record.title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.gagaeText)
                    .lineLimit(1)
                Text(FormatterUtils.relativeDate(record.date))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.gagaeTextTertiary)
            }

            Spacer()

            Text("-" + FormatterUtils.currencyString(from: record.amount))
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.gagaeDanger)

            Button {
                focusedField = nil
                withAnimation { viewModel.beginEdit(record) }
            } label: {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gagaePinkLight)
                    .frame(width: 28, height: 28)
                    .overlay(
                        Image(systemName: "pencil")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.gagaePinkDark)
                    )
            }
            .buttonStyle(.plain)

            Button {
                viewModel.deleteSpending(id: record.id, eventBus: eventBus)
                let today = Calendar.current.startOfDay(for: Date())
                viewModel.fetchSpending(on: today)
            } label: {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(hex: "#FFF0F0"))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Image(systemName: "trash")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.gagaeDanger)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(viewModel.editingRecordId == record.id ? Color.gagaePinkLight.opacity(0.4) : Color.clear)
    }
}

// MARK: - SpendViewModel Extension
extension SpendViewModel {
    var totalSpentToday: Int {
        spendingRecords.reduce(0) { $0 + $1.amount }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        SpendView()
    }
    .environment(AppEventBus())
}
