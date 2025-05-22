//
//  ViewController.swift
//  GagaeSsi
//
//  Created by 조영현 on 5/21/25.
//

import UIKit
import CoreData

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        let context = CoreDataManager.shared.context

        let config = NSEntityDescription.insertNewObject(forEntityName: "BudgetConfig", into: context) as! NSManagedObject
        config.setValue(NSDecimalNumber(value: 3000000), forKey: "salary")
        config.setValue(Date(), forKey: "payday")

        do {
            try context.save()
            print("✅ BudgetConfig 저장 성공")
        } catch {
            print("❌ 저장 실패: \(error)")
        }
        
        let request = NSFetchRequest<NSManagedObject>(entityName: "BudgetConfig")
        do {
            let results = try context.fetch(request)
            if let saved = results.first {
                print("💾 저장된 월급: \(saved.value(forKey: "salary") ?? "없음")")
            }
        } catch {
            print("❌ 불러오기 실패: \(error)")
        }


    }
}

