//
//  EditBudgetViewModel.swift
//  GagaeSsi
//
//  Created by 조영현 on 5/30/25.
//

import Foundation

final class EditBudgetViewModel {
    var salary: Int
    var payday: Int

    var onSave: ((Int, Int) -> Void)?

    init(currentSalary: Int, currentPayday: Int) {
        self.salary = currentSalary
        self.payday = currentPayday
    }

    func save() {
        onSave?(salary, payday)
    }

    func updateSalary(_ value: Int) {
        salary = value
    }

    func updatePayday(_ value: Int) {
        payday = value
    }
}
