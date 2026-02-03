//
//  FixedExpenseListView.swift
//  GagaeSsi
//
//  고정비 목록 화면
//

import SwiftUI

struct FixedExpenseListView: View {
    // MARK: - Properties
    @Environment(AppEventBus.self) private var eventBus
    @State private var fixedCosts: [FixedCostModel] = []
    @State private var showAddSheet = false
    @State private var editingItem: FixedCostModel?
    
    // MARK: - Body
    var body: some View {
        List {
            if fixedCosts.isEmpty {
                Text("등록된 고정비가 없습니다")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(fixedCosts) { item in
                    HStack {
                        Text(item.title)
                            .font(.system(size: 16))
                        
                        Spacer()
                        
                        Text(FormatterUtils.currencyString(from: item.amount))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.blue)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        editingItem = item
                    }
                }
                .onDelete(perform: deleteItems)
                
                // 합계
                Section {
                    HStack {
                        Text("합계")
                            .font(.system(size: 16, weight: .bold))
                        
                        Spacer()
                        
                        Text(FormatterUtils.currencyString(from: totalAmount))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.red)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("고정비 관리")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .onAppear {
            loadFixedCosts()
        }
        .sheet(isPresented: $showAddSheet) {
            FixedExpenseEditView(mode: .add) {
                loadFixedCosts()
                eventBus.notifyFixedExpenseChanged()
            }
        }
        .sheet(item: $editingItem) { item in
            FixedExpenseEditView(mode: .edit(item)) {
                loadFixedCosts()
                eventBus.notifyFixedExpenseChanged()
            }
        }
    }
    
    // MARK: - Computed
    private var totalAmount: Int {
        fixedCosts.map { $0.amount }.reduce(0, +)
    }
    
    // MARK: - Methods
    private func loadFixedCosts() {
        fixedCosts = CoreDataManager.shared.fetchFixedCosts()
    }
    
    private func deleteItems(at offsets: IndexSet) {
        for index in offsets {
            let item = fixedCosts[index]
            _ = CoreDataManager.shared.deleteFixedCost(id: item.id)
        }
        loadFixedCosts()
        eventBus.notifyFixedExpenseChanged()
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        FixedExpenseListView()
    }
    .environment(AppEventBus())
}
