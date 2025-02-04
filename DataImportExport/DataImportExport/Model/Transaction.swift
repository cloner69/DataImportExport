//
//  Transaction.swift
//  CustomFileExtension
//
//  Created by Adrian Suryo Abiyoga on 23/01/25.
//

import SwiftUI
import SwiftData

/// Swift Data Model
@Model
class Transaction: Codable {
    var transactionName: String
    var transactionDate: Date
    var transactionAmount: Double
    var transactionCategory: TransactionCategory
    
    init(transactionName: String, transactionDate: Date, transactionAmount: Double, transactionCategory: TransactionCategory) {
        self.transactionName = transactionName
        self.transactionDate = transactionDate
        self.transactionAmount = transactionAmount
        self.transactionCategory = transactionCategory
    }
    
    enum CodingKeys: CodingKey {
        case transactionName
        case transactionDate
        case transactionAmount
        case transactionCategory
    }
    
    required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        transactionName = try container.decode(String.self, forKey: .transactionName)
        transactionDate = try container.decode(Date.self, forKey: .transactionDate)
        transactionAmount = try container.decode(Double.self, forKey: .transactionAmount)
        transactionCategory = try container.decode(TransactionCategory.self, forKey: .transactionCategory)
    }
    
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(transactionName, forKey: .transactionName)
        try container.encode(transactionDate, forKey: .transactionDate)
        try container.encode(transactionAmount, forKey: .transactionAmount)
        try container.encode(transactionCategory, forKey: .transactionCategory)
    }
}

enum TransactionCategory: String, Codable {
    case income = "Income"
    case expense = "Expense"
}
