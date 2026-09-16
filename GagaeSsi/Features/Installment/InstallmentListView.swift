//
//  InstallmentListView.swift
//  GagaeSsi
//
//  할부 관리 화면
//

import SwiftUI

struct InstallmentListView: View {
    @Environment(AppEventBus.self) private var eventBus
    @State private var installments: [InstallmentModel] = []
    @State private var showAdd = false
    @State private var editingItem: InstallmentModel?

    private var monthlyTotal: Int {
        InstallmentModel.activeMonthlyTotal(installments, for: Date())
    }
    private var activeCount: Int {
        installments.filter { $0.isActive(for: Date()) }.count
    }

    var body: some View {
        ZStack {
            Color.gagaeBackground.ignoresSafeArea()
            ScrollView {
                VStack(spacing: GagaeSpacing.lg) {
                    summaryCard.padding(.top, GagaeSpacing.md)
                    listSection
                    Spacer(minLength: GagaeSpacing.xl)
                }
                .padding(.horizontal, GagaeSpacing.md)
            }
        }
        .navigationTitle("할부 관리")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(Color.gagaeBackground, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAdd = true } label: {
                    Image(systemName: "plus.circle.fill").font(.system(size: 20)).foregroundStyle(.gagaePinkDark)
                }
            }
        }
        .onAppear { load() }
        .sheet(isPresented: $showAdd) {
            InstallmentEditView(mode: .add) { afterChange() }
        }
        .sheet(item: $editingItem) { item in
            InstallmentEditView(mode: .edit(item)) { afterChange() }
        }
    }

    private var summaryCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: GagaeRadius.xl)
                .fill(LinearGradient(colors: [Color(hex: "#7C83FD"), Color(hex: "#5D65E8")],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .gagaeCardShadow()
            HStack {
                VStack(alignment: .leading, spacing: GagaeSpacing.xs) {
                    Text("이번 달 할부")
                        .font(.gagaeSubheadline).foregroundStyle(.white.opacity(0.85))
                    Text(FormatterUtils.currencyString(from: monthlyTotal))
                        .font(.gagaeAmountMedium).foregroundStyle(.white)
                    Text("진행 중 \(activeCount)건 · 하루 예산에서 미리 차감돼요")
                        .font(.gagaeCaption).foregroundStyle(.white.opacity(0.75))
                }
                Spacer()
                Text("💳").font(.system(size: 40))
            }
            .padding(GagaeSpacing.lg)
        }
        .frame(height: 120)
    }

    private var listSection: some View {
        VStack(spacing: GagaeSpacing.sm) {
            HStack {
                Text("할부 목록").font(.gagaeHeadline).foregroundStyle(.gagaeText)
                Spacer()
            }
            if installments.isEmpty {
                GagaeCard {
                    GagaeEmptyStateView(icon: "💳", title: "할부가 없어요",
                                        subtitle: "여러 달에 걸쳐 나가는 할부를 등록하면\n매월 하루 예산에서 미리 나눠 차감해요")
                }
            } else {
                ForEach(installments) { item in
                    installmentCard(item)
                }
            }
        }
    }

    private func installmentCard(_ item: InstallmentModel) -> some View {
        let remaining = item.remainingMonths(for: Date())
        let completed = item.isCompleted(for: Date())
        let paid = item.months - remaining
        let progress = item.months > 0 ? Double(paid) / Double(item.months) : 0
        return GagaeCard {
            VStack(alignment: .leading, spacing: GagaeSpacing.sm) {
                HStack {
                    Text(item.title).font(.gagaeCalloutMedium).foregroundStyle(.gagaeText)
                    Spacer()
                    if completed {
                        Text("완료").font(.gagaeCaptionMedium).foregroundStyle(.gagaeGood)
                    } else {
                        Text("월 \(FormatterUtils.currencyString(from: item.monthlyAmount))")
                            .font(.gagaeCalloutMedium).foregroundStyle(.gagaeDanger)
                    }
                }
                // 진행 게이지
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.gagaeDivider.opacity(0.5)).frame(height: 8)
                        Capsule().fill(Color(hex: "#5D65E8"))
                            .frame(width: max(0, geo.size.width * progress), height: 8)
                    }
                }.frame(height: 8)
                HStack {
                    Text("총 \(FormatterUtils.currencyString(from: item.totalAmount)) · \(item.months)개월")
                        .font(.gagaeCaption).foregroundStyle(.gagaeTextSecondary)
                    Spacer()
                    Text(completed ? "\(item.months)/\(item.months) 완료" : "\(paid)/\(item.months) · 남은 \(remaining)개월")
                        .font(.gagaeCaption).foregroundStyle(.gagaeTextTertiary)
                }
                HStack(spacing: GagaeSpacing.sm) {
                    Button { editingItem = item } label: {
                        Text("수정").font(.gagaeCaptionMedium).foregroundStyle(.gagaePinkDark)
                            .frame(maxWidth: .infinity).padding(.vertical, 8)
                            .background(Color.gagaePinkLight).clipShape(Capsule())
                    }.buttonStyle(.plain)
                    Button {
                        _ = CoreDataManager.shared.deleteInstallment(id: item.id)
                        afterChange()
                    } label: {
                        Text("삭제").font(.gagaeCaptionMedium).foregroundStyle(.gagaeTextSecondary)
                            .frame(maxWidth: .infinity).padding(.vertical, 8)
                            .background(Color.gagaeSurface).clipShape(Capsule())
                    }.buttonStyle(.plain)
                }
            }
        }
    }

    private func load() {
        installments = CoreDataManager.shared.fetchInstallments()
    }
    private func afterChange() {
        load()
        eventBus.notifyBudgetChanged()   // 할부는 하루 예산에 영향 → 홈 재계산
    }
}

#Preview {
    NavigationStack { InstallmentListView() }
        .environment(AppEventBus())
}
