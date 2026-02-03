//
//  FixedExpenseListView.swift
//  GagaeSsi
//
//  Created by 조영현 on 2/3/26.
//

import SwiftUI

struct FixedExpenseListView: View {
    @State private var fixedCosts: [FixedCostModel] = []
    @State private var showAddSheet = false
    @State private var editingItem: FixedCostModel?
    
    var body: some View {
        List {
            ForEach(fixedCosts) { item in
                HStack {
                    Text(item.title)
                    Spacer()
                    Text(FormatterUtils.currencyString(from: item.amount))
                        .foregroundStyle(.blue)
                }
                .contentShape(Rectangle())
                .onTapGesture { editingItem = item }
            }
            .onDelete(perform: deleteItems)
        }
        .navigationTitle("고정비 관리")
        .toolbar {
            Button { showAddSheet = true } label: {
                Image(systemName: "plus")
            }
        }
        .onAppear { loadFixedCosts() }
        .sheet(isPresented: $showAddSheet) {
            FixedExpenseEditView(mode: .add) {
                loadFixedCosts()
            }
        }
        .sheet(item: $editingItem) { item in
            FixedExpenseEditView(mode: .edit(item)) {
                loadFixedCosts()
            }
        }
    }
    
    private func loadFixedCosts() {
        fixedCosts = CoreDataManager.shared.fetchFixedCosts()
    }
    
    private func deleteItems(at offsets: IndexSet) {
        for index in offsets {
            _ = CoreDataManager.shared.deleteFixedCost(id: fixedCosts[index].id)
        }
        loadFixedCosts()
        AppEventBus.shared.notifyFixedExpenseChanged()
    }
}

#Preview {
    NavigationStack {
        FixedExpenseListView()
    }
}
