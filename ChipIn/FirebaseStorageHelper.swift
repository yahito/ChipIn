//
//  FirebaseStorageHelper.swift
//  ChipIn
//
//  Created by Andrey on 01/03/2025.
//

import Foundation

import GoogleSignIn

import SwiftUI
import FirebaseAuth
import Firebase
import FirebaseStorage
import FirebaseFirestore
import GoogleSignIn

class FirebaseStorageHelper {
    private let db = Firestore.firestore()
    private let expenseListsCollection = "expenseLists1"
    
    init() {
        // Configure Firebase security rules programmatically
        configureFirebaseSecurity()
    }
    
    // Configure Firebase security settings
    private func configureFirebaseSecurity() {
        // Enable offline persistence for Firestore
        let settings = FirestoreSettings()
        settings.isPersistenceEnabled = false
        settings.cacheSizeBytes = FirestoreCacheSizeUnlimited
        db.settings = settings
        
        // Set metadata for Storage with custom security
        let metadata = StorageMetadata()
        metadata.contentType = "application/json"
        metadata.customMetadata = ["visibility": "private"]
        FirebaseConfiguration.shared.setLoggerLevel(.debug)


        // Log initialization
        print("Firebase Storage helper initialized with security settings")
    }
    
    // Get current Firebase user ID
    public func getCurrentUserId() -> String? {
        return Auth.auth().currentUser?.uid
    }
    
    // Get current Firebase user email
    public func getCurrentUserEmail() -> String? {
        return Auth.auth().currentUser?.email
    }
    
    // Check Firebase authentication status
    public func checkAuthStatus(completion: @escaping (Bool) -> Void) {
        if Auth.auth().currentUser != nil {
            completion(true)
        } else {
            completion(false)
        }
    }
    
    // Save expense list to Firestore with owner and shared users
    // This should be in your FirebaseStorageHelper class
    // Make sure this code correctly includes ownerId during document creation

    func saveExpenseList(expenseList: ExpenseList, completion: @escaping () -> Void) {
        checkAuthStatus { isAuthenticated in
            if isAuthenticated {
                guard let userId = self.getCurrentUserId(), let userEmail = self.getCurrentUserEmail() else {
                    print("User is not authenticated with Firebase")
                    return
                }
                
                // IMPORTANT: Make sure ownerId is set to the current user's ID
                let data: [String: Any] = [
                    "id": expenseList.id,
                    "name": expenseList.name,
                    "ownerId": userId,  // This must be the current user's Firebase Auth UID
                    "ownerEmail": userEmail,
                    "sharedEmails": expenseList.sharedEmails,
                    "timestamp": FieldValue.serverTimestamp(),
                    "visibility": "private",
                    "securityLevel": "restricted"
                ]

                // Debug: Log the document data to verify what's being written
                print("Creating document with data: \(data)")

                let collectionRef = self.db.collection(self.expenseListsCollection)
                collectionRef.document(expenseList.id).setData(data) { error in
                    if let error = error {
                        print("Error saving expense list: \(error.localizedDescription)")
                    } else {
                        DispatchQueue.main.async {
                            print("Saved expense list with ID \(expenseList.id)")
                            completion()
                        }
                    }
                }
            } else {
                print("User is not signed into Firebase")
            }
        }
    }
    
    // Fetch expense lists from Firestore that the current user has access to
    func fetchExpenseLists(completion: @escaping ([ExpenseList]) -> Void) {
        checkAuthStatus { isAuthenticated in
            if isAuthenticated {
                guard let userId = self.getCurrentUserId(), let userEmail = self.getCurrentUserEmail() else {
                    print("User is not authenticated with Firebase")
                    completion([])
                    return
                }
                
                // Query lists where user is the owner (using userId)
                let ownerQuery = self.db.collection(self.expenseListsCollection)
                    .whereField("ownerId", isEqualTo: userId)
                
                // Query lists where user's email is in shared users
                let sharedQuery = self.db.collection(self.expenseListsCollection)
                    .whereField("sharedEmails", arrayContains: userEmail)
                
                // Execute both queries and combine results
                var allLists: [ExpenseList] = []
                let group = DispatchGroup()
                
                // Get owned lists
                group.enter()
                ownerQuery.getDocuments { snapshot, error in
                    defer { group.leave() }
                    
                    if let error = error {
                        print("Error fetching owned expense lists: \(error.localizedDescription)")
                        return
                    }
                    
                    if let documents = snapshot?.documents {
                        let ownedLists = documents.compactMap { document -> ExpenseList? in
                            let data = document.data()
                            guard
                                let id = data["id"] as? String,
                                let name = data["name"] as? String,
                                let ownerId = data["ownerId"] as? String,
                                let ownerEmail = data["ownerEmail"] as? String
                            else {
                                return nil
                            }
                            
                            let sharedEmails = data["sharedEmails"] as? [String] ?? []
                            
                            return ExpenseList(
                                id: id,
                                name: name,
                                ownerId: ownerId,
                                ownerEmail: ownerEmail,
                                sharedEmails: sharedEmails,
                                isOwner: true
                            )
                        }
                        allLists.append(contentsOf: ownedLists)
                    }
                }
                
                // Get shared lists
                group.enter()
                sharedQuery.getDocuments { snapshot, error in
                    defer { group.leave() }
                    
                    if let error = error {
                        print("Error fetching shared expense lists: \(error.localizedDescription)")
                        return
                    }
                    
                    if let documents = snapshot?.documents {
                        let sharedLists = documents.compactMap { document -> ExpenseList? in
                            let data = document.data()
                            guard
                                let id = data["id"] as? String,
                                let name = data["name"] as? String,
                                let ownerId = data["ownerId"] as? String,
                                let ownerEmail = data["ownerEmail"] as? String
                            else {
                                return nil
                            }
                            
                            let sharedEmails = data["sharedEmails"] as? [String] ?? []
                            
                            return ExpenseList(
                                id: id,
                                name: name,
                                ownerId: ownerId,
                                ownerEmail: ownerEmail,
                                sharedEmails: sharedEmails,
                                isOwner: false
                            )
                        }
                        allLists.append(contentsOf: sharedLists)
                    }
                }
                
                // When both queries complete, return combined results
                group.notify(queue: .main) {
                    completion(allLists)
                }
            } else {
                // Handle unauthenticated state
                print("User is not signed into Firebase")
                completion([])
            }
        }
    }
    


    // Remove a user's access with dynamic expense adjustment
    func removeUserAccess(listId: String, email: String, completion: @escaping (Bool, String?) -> Void) {
        guard let currentUserId = getCurrentUserId(), let currentUserEmail = getCurrentUserEmail() else {
            completion(false, "Not authenticated")
            return
        }
        
        // Find the expense list and verify ownership
        let docRef = db.collection(expenseListsCollection).document(listId)
        
        docRef.getDocument { [weak self] document, error in
            guard let self = self else { return }
            
            if let error = error {
                completion(false, error.localizedDescription)
                return
            }
            
            guard let document = document, document.exists,
                  let data = document.data(),
                  let ownerId = data["ownerId"] as? String,
                  ownerId == currentUserId else {
                completion(false, "List not found or you don't own it")
                return
            }
            
            // Get current shared users and remove the specified user
            var sharedEmails = data["sharedEmails"] as? [String] ?? []
            
            // Normalize the email
            let normalizedEmail = email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            
            if let index = sharedEmails.firstIndex(of: normalizedEmail) {
                sharedEmails.remove(at: index)
                
                // Start a transaction
                self.db.runTransaction({ (transaction, errorPointer) -> Any? in
                    // 1. Update the list document with new shared emails array
                    transaction.updateData(["sharedEmails": sharedEmails], forDocument: docRef)
                    
                    // 2. Remove user from dynamic expenses
                    self.removeUserFromDynamicExpenses(transaction: transaction, listId: listId, removedEmail: normalizedEmail)
                    
                    // 3. Add audit log entry
                    let logRef = self.db.collection("activityLogs").document()
                    let auditLog = [
                        "action": "removeAccess",
                        "listId": listId,
                        "ownerId": currentUserId,
                        "removedUser": normalizedEmail,
                        "timestamp": FieldValue.serverTimestamp()
                    ]
                    transaction.setData(auditLog, forDocument: logRef)
                    
                    return nil
                }) { (_, error) in
                    if let error = error {
                        completion(false, error.localizedDescription)
                    } else {
                        completion(true, nil)
                    }
                }
            } else {
                // User doesn't have access
                completion(false, "User doesn't have access to this list")
            }
        }
    }

    // Update dynamic expenses when adding a new user
    private func updateDynamicExpenses(transaction: FirebaseFirestore.Transaction, listId: String, newEmail: String) {
        // Get reference to expenses collection
        let expensesRef = db.collection(expenseListsCollection)
            .document(listId)
            .collection("expenses")
        
        // Find all dynamic expenses with a regular query first
        let dynamicExpensesQuery = expensesRef
            .whereField("splitType", isEqualTo: SplitType.dynamic.rawValue)
        
        // We can't use transaction.getDocuments() directly with a query
        // Instead, first get the documents normally, then process them in the transaction
        dynamicExpensesQuery.getDocuments { [weak self] (snapshot, error) in
            guard let self = self else { return }
            
            if let error = error {
                print("Error getting dynamic expenses: \(error)")
                return
            }
            
            guard let documents = snapshot?.documents else {
                return
            }
            
            // Process each document within the transaction
            for document in documents {
                do {
                    // Get the document within the transaction to ensure consistency
                    let docSnapshot = try transaction.getDocument(document.reference)
                    var data = docSnapshot.data() ?? [:]
                    
                    // Add the new user to splitBetweenEmails array
                    var splitBetweenEmails = data["splitBetweenEmails"] as? [String] ?? []
                    
                    // Only add if not already included
                    if !splitBetweenEmails.contains(newEmail) {
                        splitBetweenEmails.append(newEmail)
                        transaction.updateData(["splitBetweenEmails": splitBetweenEmails], forDocument: document.reference)
                        
                        // If the expense uses splitItems and it's a percentage type, redistribute
                        if data["splitType"] as? String == SplitType.percentage.rawValue,
                           var splitItemsArray = data["splitItems"] as? [[String: Any]] {
                            
                            // Calculate new equal percentage
                            let newPercentage = 100.0 / Double(splitBetweenEmails.count)
                            
                            // Adjust all percentages to be equal
                            var newSplitItems: [[String: Any]] = []
                            
                            // First add existing users with adjusted percentage
                            for var item in splitItemsArray {
                                item["value"] = newPercentage
                                newSplitItems.append(item)
                            }
                            
                            // Add new user
                            let newItem: [String: Any] = [
                                "id": UUID().uuidString,
                                "email": newEmail,
                                "value": newPercentage
                            ]
                            newSplitItems.append(newItem)
                            
                            transaction.updateData(["splitItems": newSplitItems], forDocument: document.reference)
                        }
                    }
                } catch {
                    print("Error processing document in transaction: \(error)")
                }
            }
        }
    }

    // Remove user from dynamic expenses - also fixed to use the proper transaction approach
    private func removeUserFromDynamicExpenses(transaction: FirebaseFirestore.Transaction, listId: String, removedEmail: String) {
        // Get reference to expenses collection
        let expensesRef = db.collection(expenseListsCollection)
            .document(listId)
            .collection("expenses")
        
        // Find all dynamic expenses
        let dynamicExpensesQuery = expensesRef
            .whereField("splitType", isEqualTo: SplitType.dynamic.rawValue)
        
        // First get the documents normally, then process them in the transaction
        dynamicExpensesQuery.getDocuments { [weak self] (snapshot, error) in
            guard let self = self else { return }
            
            if let error = error {
                print("Error getting dynamic expenses: \(error)")
                return
            }
            
            guard let documents = snapshot?.documents else {
                return
            }
            
            // Process each document within the transaction
            for document in documents {
                do {
                    // Get the document within the transaction to ensure consistency
                    let docSnapshot = try transaction.getDocument(document.reference)
                    var data = docSnapshot.data() ?? [:]
                    
                    // Remove user from splitBetweenEmails array
                    var splitBetweenEmails = data["splitBetweenEmails"] as? [String] ?? []
                    
                    // Remove the email if it exists
                    if let index = splitBetweenEmails.firstIndex(of: removedEmail) {
                        splitBetweenEmails.remove(at: index)
                        transaction.updateData(["splitBetweenEmails": splitBetweenEmails], forDocument: document.reference)
                        
                        // If the expense uses splitItems and it's a percentage type, redistribute
                        if data["splitType"] as? String == SplitType.percentage.rawValue,
                           var splitItemsArray = data["splitItems"] as? [[String: Any]] {
                            
                            // Remove the item for this user
                            splitItemsArray.removeAll { ($0["email"] as? String) == removedEmail }
                            
                            // If there are still users left, redistribute percentages
                            if !splitItemsArray.isEmpty {
                                let newPercentage = 100.0 / Double(splitItemsArray.count)
                                
                                // Adjust all percentages to be equal
                                for i in 0..<splitItemsArray.count {
                                    splitItemsArray[i]["value"] = newPercentage
                                }
                                
                                transaction.updateData(["splitItems": splitItemsArray], forDocument: document.reference)
                            }
                        }
                        
                        // Special case: if this user was the payer, reassign to list owner
                        if data["paidByEmail"] as? String == removedEmail {
                            // Get the list owner email
                            let listDocRef = db.collection(expenseListsCollection).document(listId)
                            let listDoc = try transaction.getDocument(listDocRef)
                            if let ownerEmail = listDoc.data()?["ownerEmail"] as? String {
                                transaction.updateData(["paidByEmail": ownerEmail], forDocument: document.reference)
                            }
                        }
                    }
                } catch {
                    print("Error processing document in transaction: \(error)")
                }
            }
        }
    }

    // Modified shareExpenseList to work with the asynchronous helper methods
    func shareExpenseList(listId: String, withEmail: String, completion: @escaping (Bool, String?) -> Void) {
        guard let currentUserId = getCurrentUserId(), let currentUserEmail = getCurrentUserEmail() else {
            print("DEBUG: Share failed - User not authenticated")
            completion(false, "Not authenticated")
            return
        }
        
        // Find the expense list and verify ownership
        let docRef = self.db.collection(self.expenseListsCollection).document(listId)
        
        docRef.getDocument { [weak self] document, error in
            guard let self = self else { return }
            
            if let error = error {
                print("DEBUG: Error fetching document: \(error.localizedDescription)")
                completion(false, error.localizedDescription)
                return
            }
            
            guard let document = document, document.exists else {
                print("DEBUG: Document not found")
                completion(false, "List not found")
                return
            }
            
            let data = document.data()
            
            guard let ownerId = data?["ownerId"] as? String else {
                print("DEBUG: Document missing ownerId field")
                completion(false, "Document corrupted - missing owner")
                return
            }
            
            if ownerId != currentUserId {
                print("DEBUG: Permission denied - user is not the owner")
                completion(false, "You don't own this list")
                return
            }
            
            // Get current shared emails
            var sharedEmails = data?["sharedEmails"] as? [String] ?? []
            
            // Make sure the email is lowercase for consistency
            let normalizedEmail = withEmail.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            
            if !sharedEmails.contains(normalizedEmail) {
                sharedEmails.append(normalizedEmail)
                
                // Start a transaction
                self.db.runTransaction({ (transaction, errorPointer) -> Any? in
                    // 1. Update the list document with new shared emails array
                    transaction.updateData(["sharedEmails": sharedEmails], forDocument: docRef)
                    
                    // 2. Update dynamic expenses to include the new user
                    // This now happens asynchronously inside the helper method
                    self.updateDynamicExpenses(transaction: transaction, listId: listId, newEmail: normalizedEmail)
                    
                    // 3. Add audit log entry
                    let logRef = self.db.collection("activityLogs").document()
                    let auditLog = [
                        "action": "share",
                        "listId": listId,
                        "ownerId": currentUserId,
                        "sharedWith": normalizedEmail,
                        "timestamp": FieldValue.serverTimestamp()
                    ]
                    transaction.setData(auditLog, forDocument: logRef)
                    
                    return nil
                }) { (_, error) in
                    if let error = error {
                        print("DEBUG: Transaction failed: \(error.localizedDescription)")
                        completion(false, error.localizedDescription)
                    } else {
                        print("DEBUG: Sharing successful")
                        completion(true, nil)
                    }
                }
            } else {
                // User already has access
                print("DEBUG: User already has access")
                completion(true, "User already has access")
            }
        }
    }
    
    // Fetch expenses for a list
    func fetchExpenses(listId: String, completion: @escaping ([Expense]) -> Void) {
        guard getCurrentUserEmail() != nil else {
            completion([])
            return
        }
        
        let expensesRef = db.collection(expenseListsCollection)
            .document(listId)
            .collection("expenses")
            .order(by: "date", descending: true)
        
        expensesRef.getDocuments { snapshot, error in
            if let error = error {
                print("Error fetching expenses: \(error.localizedDescription)")
                completion([])
                return
            }
            
            guard let documents = snapshot?.documents else {
                completion([])
                return
            }
            
            let expenses = documents.compactMap { document -> Expense? in
                return Expense.fromDictionary(document.data())
            }
            
            completion(expenses)
        }
    }

    // Delete an expense
    func deleteExpense(listId: String, expenseId: String, completion: @escaping (Bool, String?) -> Void) {
        guard getCurrentUserEmail() != nil else {
            completion(false, "Not authenticated")
            return
        }
        
        let expenseRef = db.collection(expenseListsCollection)
            .document(listId)
            .collection("expenses")
            .document(expenseId)
        
        expenseRef.delete { error in
            if let error = error {
                print("Error deleting expense: \(error.localizedDescription)")
                completion(false, error.localizedDescription)
            } else {
                // Update list totals after deleting expense
                self.updateListTotals(listId: listId) { success, error in
                    completion(success, error)
                }
            }
        }
    }

    // Calculate balances for all members of a list
    func calculateBalances(listId: String, completion: @escaping ([String: Double]) -> Void) {
        fetchExpenses(listId: listId) { expenses in
            var balances: [String: Double] = [:]
            
            for expense in expenses {
                let paidBy = expense.paidByEmail
                let amount = expense.amount
                
                // Add the full amount to the person who paid
                balances[paidBy, default: 0] += amount
                
                // Determine how to split based on splitType
                switch expense.splitType {
                case .equal, .dynamic:
                    // Split evenly among all people in splitBetweenEmails
                    let splitBetween = expense.splitBetweenEmails
                    if !splitBetween.isEmpty {
                        let splitAmount = amount / Double(splitBetween.count)
                        for email in splitBetween {
                            balances[email, default: 0] -= splitAmount
                        }
                    }
                    
                case .percentage:
                    // Split according to percentage values
                    if let splitItems = expense.splitItems {
                        for item in splitItems {
                            let splitAmount = amount * (item.value / 100.0)
                            balances[item.email, default: 0] -= splitAmount
                        }
                    }
                    
                case .fixed:
                    // Split according to fixed amounts
                    if let splitItems = expense.splitItems {
                        for item in splitItems {
                            balances[item.email, default: 0] -= item.value
                        }
                    }
                }
            }
            
            completion(balances)
        }
    }

    // Helper method to update the list totals
    // Helper method to update the list totals
    private func updateListTotals(listId: String, completion: @escaping (Bool, String?) -> Void) {
        let listRef = db.collection(expenseListsCollection).document(listId)
        let expensesRef = listRef.collection("expenses")
        
        expensesRef.getDocuments { snapshot, error in
            if let error = error {
                print("Error fetching expenses for total: \(error.localizedDescription)")
                completion(false, error.localizedDescription)
                return
            }
            
            guard let documents = snapshot?.documents else {
                // Update with zero if no expenses
                // ONLY update the totalAmount field, nothing else
                listRef.updateData(["totalAmount": 0.0]) { error in
                    if let error = error {
                        print("Error updating total amount: \(error.localizedDescription)")
                        completion(false, error.localizedDescription)
                    } else {
                        completion(true, nil)
                    }
                }
                return
            }
            
            // Calculate total amount
            let totalAmount = documents.compactMap { document -> Double? in
                return document.data()["amount"] as? Double
            }.reduce(0.0, +)
            
            // Update ONLY the totalAmount field in the list document
            listRef.updateData(["totalAmount": totalAmount]) { error in
                if let error = error {
                    print("Error updating total amount: \(error.localizedDescription)")
                    completion(false, error.localizedDescription)
                } else {
                    completion(true, nil)
                }
            }
        }
    }

    // Add an expense to a list
    func addExpense(listId: String, expense: Expense, completion: @escaping (Bool, String?) -> Void) {
        guard let currentUserEmail = getCurrentUserEmail() else {
            completion(false, "Not authenticated")
            return
        }
        
        // Get reference to the list document
        let listRef = db.collection(expenseListsCollection).document(listId)
        
        // Create a subcollection for expenses within the list
        let expensesCollectionRef = listRef.collection("expenses")
        
        // Add the expense to the subcollection
        expensesCollectionRef.document(expense.id).setData(expense.toDictionary()) { error in
            if let error = error {
                print("Error adding expense: \(error.localizedDescription)")
                completion(false, error.localizedDescription)
            } else {
                // Update total amount in the list document
                self.updateListTotals(listId: listId) { success, error in
                    completion(success, error)
                }
            }
        }
    }
    
    
    // Updated Firebase methods to store settlements as a subcollection of expenseLists

    // Create a new settlement
    func createSettlement(listId: String, settlement: Settlement, completion: @escaping (Bool, String?) -> Void) {
        guard let currentUserEmail = getCurrentUserEmail() else {
            completion(false, "Not authenticated")
            return
        }
        
        // Create a new settlement document within the list's settlements subcollection
        let settlementRef = db.collection(expenseListsCollection)
                              .document(listId)
                              .collection("settlements")
                              .document(settlement.id)
        
        // Set the data
        settlementRef.setData(settlement.toDictionary()) { error in
            if let error = error {
                print("Error creating settlement: \(error.localizedDescription)")
                completion(false, error.localizedDescription)
            } else {
                completion(true, nil)
            }
        }
    }

    // Fetch settlements for a specific list
    func fetchSettlements(listId: String, completion: @escaping ([Settlement]) -> Void) {
        guard let currentUserEmail = getCurrentUserEmail() else {
            completion([])
            return
        }
        
        // Query settlements within the list's settlement subcollection
        // where the current user is either the sender or receiver
        let query = db.collection(expenseListsCollection)
                      .document(listId)
                      .collection("settlements")
                     
                      .order(by: "date", descending: true)
        
        query.getDocuments { snapshot, error in
            if let error = error {
                print("Error fetching settlements: \(error.localizedDescription)")
                completion([])
                return
            }
            
            guard let documents = snapshot?.documents else {
                completion([])
                return
            }
            
            let settlements = documents.compactMap { document -> Settlement? in
                return Settlement.fromDictionary(document.data())
            }
            
            completion(settlements)
        }
    }

    // Confirm a settlement
    func confirmSettlement(listId: String, settlementId: String, completion: @escaping (Bool, String?) -> Void) {
        guard let currentUserEmail = getCurrentUserEmail() else {
            completion(false, "Not authenticated")
            return
        }
        
        let settlementRef = db.collection(expenseListsCollection)
                              .document(listId)
                              .collection("settlements")
                              .document(settlementId)
        
        // Use a transaction to ensure data consistency
        db.runTransaction({ (transaction, errorPointer) -> Any? in
            do {
                let documentSnapshot = try transaction.getDocument(settlementRef)
                
                guard let data = documentSnapshot.data(),
                      let toEmail = data["toEmail"] as? String else {
                    throw NSError(domain: "AppErrorDomain", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid settlement data"])
                }
                
                // Only the recipient can confirm the settlement
                guard toEmail == currentUserEmail else {
                    throw NSError(domain: "AppErrorDomain", code: -1, userInfo: [NSLocalizedDescriptionKey: "Only the recipient can confirm the settlement"])
                }
                
                // Update the settlement
                transaction.updateData([
                    "status": Settlement.SettlementStatus.confirmed.rawValue,
                    "confirmedByEmail": currentUserEmail,
                    "confirmedDate": Timestamp(date: Date())
                ], forDocument: settlementRef)
                
                return nil
            } catch let error as NSError {
                errorPointer?.pointee = error
                return nil
            }
        }) { (_, error) in
            if let error = error {
                print("Error confirming settlement: \(error.localizedDescription)")
                completion(false, error.localizedDescription)
            } else {
                completion(true, nil)
            }
        }
    }

    // Reject a settlement
    func rejectSettlement(listId: String, settlementId: String, completion: @escaping (Bool, String?) -> Void) {
        guard let currentUserEmail = getCurrentUserEmail() else {
            completion(false, "Not authenticated")
            return
        }
        
        let settlementRef = db.collection(expenseListsCollection)
                              .document(listId)
                              .collection("settlements")
                              .document(settlementId)
        
        // Use a transaction to ensure data consistency
        db.runTransaction({ (transaction, errorPointer) -> Any? in
            do {
                let documentSnapshot = try transaction.getDocument(settlementRef)
                
                guard let data = documentSnapshot.data(),
                      let toEmail = data["toEmail"] as? String else {
                    throw NSError(domain: "AppErrorDomain", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid settlement data"])
                }
                
                // Only the recipient can reject the settlement
                guard toEmail == currentUserEmail else {
                    throw NSError(domain: "AppErrorDomain", code: -1, userInfo: [NSLocalizedDescriptionKey: "Only the recipient can reject the settlement"])
                }
                
                // Update the settlement
                transaction.updateData([
                    "status": Settlement.SettlementStatus.rejected.rawValue,
                    "confirmedByEmail": currentUserEmail,
                    "confirmedDate": Timestamp(date: Date())
                ], forDocument: settlementRef)
                
                return nil
            } catch let error as NSError {
                errorPointer?.pointee = error
                return nil
            }
        }) { (_, error) in
            if let error = error {
                print("Error rejecting settlement: \(error.localizedDescription)")
                completion(false, error.localizedDescription)
            } else {
                completion(true, nil)
            }
        }
    }

    // Calculate adjusted balances considering confirmed settlements
    func calculateAdjustedBalances(listId: String, completion: @escaping ([String: Double]) -> Void) {
        // First get the regular balances
        calculateBalances(listId: listId) { [weak self] balances in
            guard let self = self else {
                completion(balances)
                return
            }
            
            // Then fetch the settlements
            self.fetchSettlements(listId: listId) { settlements in
                var adjustedBalances = balances
                
                // Only consider confirmed settlements
                let confirmedSettlements = settlements.filter { $0.status == .confirmed }
                
                // Adjust balances based on settlements
                for settlement in confirmedSettlements {
                    // The person who paid gets credit
                    adjustedBalances[settlement.fromEmail, default: 0] += settlement.amount
                    
                    // The person who received gets debited
                    adjustedBalances[settlement.toEmail, default: 0] -= settlement.amount
                }
                
                completion(adjustedBalances)
            }
        }
    }
    
    
}
