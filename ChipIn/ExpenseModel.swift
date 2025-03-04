//
//  ExpenseModel.swift
//  ChipIn
//
//  Created by Andrey on 01/03/2025.
//

import Foundation
import FirebaseFirestore

// Split type enumeration
enum SplitType: String, Codable {
    case equal = "equal"             // Split equally among selected participants
    case percentage = "percentage"   // Split by custom percentages
    case fixed = "fixed"             // Split by fixed amounts
    case dynamic = "dynamic"         // Automatically adjust when members change
}

// Split item structure to hold custom splits (for percentage and fixed types)
struct SplitItem: Identifiable, Codable {
    let id: String
    let email: String
    var value: Double  // Percentage or fixed amount depending on split type
    
    init(id: String = UUID().uuidString, email: String, value: Double) {
        self.id = id
        self.email = email
        self.value = value
    }
}

struct Expense: Identifiable {
    let id: String
    let description: String
    let amount: Double
    let date: Date
    let paidByEmail: String
    let splitType: SplitType
    var splitItems: [SplitItem]?  // For percentage or fixed splits
    var splitBetweenEmails: [String]  // For equal or dynamic splits
    let categoryName: String
    let notes: String?
    let createdAt: Date
    let createdByEmail: String
    
    // Convenience initializer
    init(id: String = UUID().uuidString,
         description: String,
         amount: Double,
         date: Date = Date(),
         paidByEmail: String,
         splitType: SplitType = .dynamic,
         splitItems: [SplitItem]? = nil,
         splitBetweenEmails: [String],
         categoryName: String = "Uncategorized",
         notes: String? = nil,
         createdAt: Date = Date(),
         createdByEmail: String) {
        self.id = id
        self.description = description
        self.amount = amount
        self.date = date
        self.paidByEmail = paidByEmail
        self.splitType = splitType
        self.splitItems = splitItems
        self.splitBetweenEmails = splitBetweenEmails
        self.categoryName = categoryName
        self.notes = notes
        self.createdAt = createdAt
        self.createdByEmail = createdByEmail
    }
    
    // Convert to dictionary for Firestore
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "description": description,
            "amount": amount,
            "date": Timestamp(date: date),
            "paidByEmail": paidByEmail,
            "splitType": splitType.rawValue,
            "splitBetweenEmails": splitBetweenEmails,
            "categoryName": categoryName,
            "createdAt": Timestamp(date: createdAt),
            "createdByEmail": createdByEmail
        ]
        
        if let notes = notes {
            dict["notes"] = notes
        }
        
        if let splitItems = splitItems {
            let splitItemsArray = splitItems.map { item -> [String: Any] in
                return [
                    "id": item.id,
                    "email": item.email,
                    "value": item.value
                ]
            }
            dict["splitItems"] = splitItemsArray
        }
        
        return dict
    }
    
    // Create from Firestore document
    static func fromDictionary(_ dict: [String: Any]) -> Expense? {
        guard
            let id = dict["id"] as? String,
            let description = dict["description"] as? String,
            let amount = dict["amount"] as? Double,
            let timestamp = dict["date"] as? Timestamp,
            let paidByEmail = dict["paidByEmail"] as? String,
            let splitTypeString = dict["splitType"] as? String,
            let splitType = SplitType(rawValue: splitTypeString),
            let splitBetweenEmails = dict["splitBetweenEmails"] as? [String],
            let categoryName = dict["categoryName"] as? String,
            let createdAtTimestamp = dict["createdAt"] as? Timestamp,
            let createdByEmail = dict["createdByEmail"] as? String
        else {
            return nil
        }
        
        // Parse split items if they exist
        var splitItems: [SplitItem]?
        if let splitItemsArray = dict["splitItems"] as? [[String: Any]] {
            splitItems = splitItemsArray.compactMap { itemDict -> SplitItem? in
                guard
                    let id = itemDict["id"] as? String,
                    let email = itemDict["email"] as? String,
                    let value = itemDict["value"] as? Double
                else {
                    return nil
                }
                return SplitItem(id: id, email: email, value: value)
            }
        }
        
        let notes = dict["notes"] as? String
        
        return Expense(
            id: id,
            description: description,
            amount: amount,
            date: timestamp.dateValue(),
            paidByEmail: paidByEmail,
            splitType: splitType,
            splitItems: splitItems,
            splitBetweenEmails: splitBetweenEmails,
            categoryName: categoryName,
            notes: notes,
            createdAt: createdAtTimestamp.dateValue(),
            createdByEmail: createdByEmail
        )
    }
}

// Category enum for expense categorization
enum ExpenseCategory: String, CaseIterable, Identifiable {
    case food = "Food"
    case transportation = "Transportation"
    case housing = "Housing"
    case utilities = "Utilities"
    case entertainment = "Entertainment"
    case shopping = "Shopping"
    case health = "Health"
    case travel = "Travel"
    case education = "Education"
    case personal = "Personal"
    case other = "Other"
    case uncategorized = "Uncategorized"
    
    var id: String { self.rawValue }
}
