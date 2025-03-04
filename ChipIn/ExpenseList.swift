//
//  ExpenseList.swift
//  ChipIn
//
//  Created by Andrey on 01/03/2025.
//

import Foundation
import FirebaseAuth

// Hybrid ExpenseList model that uses both userId for ownership and emails for sharing
struct ExpenseList: Identifiable {
    let id: String
    let name: String
    let ownerId: String        // Keep ownerId for Firebase rules
    let ownerEmail: String     // Store owner email for display
    let sharedEmails: [String] // Share directly with emails
    let isOwner: Bool
    
    // Convenience initializer for creating new lists
    init(id: String, name: String,
         ownerId: String = Auth.auth().currentUser?.uid ?? "",
         ownerEmail: String = Auth.auth().currentUser?.email ?? "",
         sharedEmails: [String] = [],
         isOwner: Bool = true) {
        self.id = id
        self.name = name
        self.ownerId = ownerId
        self.ownerEmail = ownerEmail
        self.sharedEmails = sharedEmails
        self.isOwner = isOwner
    }
}
