import Foundation

struct Debt {
    let fromEmail: String
    let toEmail: String
    let amount: Double
}

class DebtSimplifier {
    
    // Simplify the debts by reducing the number of transactions
    static func simplifyDebts(balances: [String: Double]) -> [Debt] {
        // Create arrays of debtors and creditors
        var debtors: [(email: String, amount: Double)] = []
        var creditors: [(email: String, amount: Double)] = []
        
        // Separate people into debtors (negative balance) and creditors (positive balance)
        for (email, balance) in balances {
            if balance < 0 {
                debtors.append((email, -balance)) // Convert to positive amount for easier handling
            } else if balance > 0 {
                creditors.append((email, balance))
            }
            // People with zero balance are ignored
        }
        
        // Sort both arrays by amount (descending)
        debtors.sort { $0.amount > $1.amount }
        creditors.sort { $0.amount > $1.amount }
        
        // Create the simplified debts
        var simplifiedDebts: [Debt] = []
        
        // Match debtors and creditors to optimize transactions
        var i = 0 // index for debtors
        var j = 0 // index for creditors
        
        while i < debtors.count && j < creditors.count {
            let debtor = debtors[i]
            let creditor = creditors[j]
            
            // Amount to be settled is the minimum of what the debtor owes and what the creditor is owed
            let amount = min(debtor.amount, creditor.amount)
            
            if amount > 0.01 { // Only create debts for non-trivial amounts
                simplifiedDebts.append(Debt(fromEmail: debtor.email, toEmail: creditor.email, amount: amount))
            }
            
            // Update remaining amounts
            let newDebtorAmount = debtor.amount - amount
            let newCreditorAmount = creditor.amount - amount
            
            // Move to next debtor if their debt is fully settled
            if newDebtorAmount < 0.01 {
                i += 1
            } else {
                debtors[i] = (debtor.email, newDebtorAmount)
            }
            
            // Move to next creditor if they've been fully paid
            if newCreditorAmount < 0.01 {
                j += 1
            } else {
                creditors[j] = (creditor.email, newCreditorAmount)
            }
        }
        
        return simplifiedDebts
    }
    
    // Format a debt as a human-readable string
    static func formatDebt(_ debt: Debt, currencyCode: String = "USD") -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        
        let formattedAmount = formatter.string(from: NSNumber(value: debt.amount)) ?? "$\(debt.amount)"
        
        return "\(debt.fromEmail) pays \(formattedAmount) to \(debt.toEmail)"
    }
}
