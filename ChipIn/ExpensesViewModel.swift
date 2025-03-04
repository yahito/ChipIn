import SwiftUI
import Combine

// Complete implementation of the ExpensesViewModel class
class ExpensesViewModel: ObservableObject {
    @Published var expenses: [Expense] = []
    @Published var balances: [String: Double] = [:]
    @Published var isLoading = true
    private var cloudKitHelper: FirebaseStorageHelper
    private let listId: String
    
    init(cloudKitHelper: FirebaseStorageHelper, listId: String) {
        self.cloudKitHelper = cloudKitHelper
        self.listId = listId
        loadExpenses()
    }
    
    func loadExpenses() {
        isLoading = true
        
        cloudKitHelper.fetchExpenses(listId: listId) { [weak self] fetchedExpenses in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.expenses = fetchedExpenses
                
                // Calculate balances
                self.cloudKitHelper.calculateBalances(listId: self.listId) { calculatedBalances in
                    DispatchQueue.main.async {
                        self.balances = calculatedBalances
                        self.isLoading = false
                    }
                }
            }
        }
    }
    
    func deleteExpense(at offsets: IndexSet) {
        for index in offsets {
            let expense = expenses[index]
            cloudKitHelper.deleteExpense(listId: listId, expenseId: expense.id) { [weak self] success, _ in
                if success {
                    DispatchQueue.main.async {
                        self?.loadExpenses() // Reload to get updated balances
                    }
                }
            }
        }
    }
    
    func addExpense(_ expense: Expense, completion: @escaping (Bool, String?) -> Void) {
        cloudKitHelper.addExpense(listId: listId, expense: expense) { [weak self] success, error in
            if success {
                DispatchQueue.main.async {
                    self?.loadExpenses() // Reload expenses to reflect the changes
                    completion(true, nil)
                }
            } else {
                completion(false, error)
            }
        }
    }
    
    // Get all participants (owner + shared users) for this list
    func getParticipants() -> [String] {
        // Find the list in the expenses
        if let expense = expenses.first, !expense.splitBetweenEmails.isEmpty {
            return expense.splitBetweenEmails
        } else {
            // Fallback if no expenses yet - this will be calculated when expenses are added
            return []
        }
    }
    
    // Get optimized settlement transactions
    func getSettlementDebts() -> [Debt] {
        return DebtSimplifier.simplifyDebts(balances: balances)
    }
}
