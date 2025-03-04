import SwiftUI

struct AddExpenseView: View {
    @ObservedObject var viewModel: ExpensesViewModel
    var list: ExpenseList
    @Binding var isPresented: Bool
    
    // Remove the earlier binding to expenses array
    // @Binding var expenses: [Expense] // This line should be removed
    
    @State private var cloudKitHelper = FirebaseStorageHelper()
    
    @State private var description = ""
    @State private var amount = ""
    @State private var date = Date()
    @State private var category = ExpenseCategory.uncategorized
    @State private var notes = ""
    @State private var paidByEmail = ""
    @State private var selectedSplitType: SplitType = .dynamic
    @State private var selectedSplitEmails: [String] = []
    @State private var splitItems: [SplitItem] = []
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    
    var allParticipants: [String] {
        var participants = [list.ownerEmail]
        participants.append(contentsOf: list.sharedEmails)
        return participants
    }
    
    var formIsValid: Bool {
        // Basic validation
        guard !description.isEmpty,
              !amount.isEmpty,
              let amountValue = Double(amount), amountValue > 0,
              !paidByEmail.isEmpty else {
            return false
        }
        
        // Split-specific validation
        switch selectedSplitType {
        case .equal, .dynamic:
            return !selectedSplitEmails.isEmpty
        case .percentage:
            return !splitItems.isEmpty && validatePercentages()
        case .fixed:
            return !splitItems.isEmpty && validateFixedAmounts()
        }
    }
    
    func validatePercentages() -> Bool {
        let totalPercentage = splitItems.reduce(0) { $0 + $1.value }
        return abs(totalPercentage - 100.0) < 0.1 // Allow small floating point error
    }
    
    func validateFixedAmounts() -> Bool {
        guard let amountValue = Double(amount) else { return false }
        let totalFixed = splitItems.reduce(0) { $0 + $1.value }
        return abs(totalFixed - amountValue) < 0.01 // Allow small floating point error
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Form sections remain the same...
                Section(header: Text("Basic Information")) {
                    TextField("Description", text: $description)
                    
                    TextField("Amount", text: $amount)
                        .keyboardType(.decimalPad)
                    
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    
                    Picker("Category", selection: $category) {
                        ForEach(ExpenseCategory.allCases) { category in
                            Text(category.rawValue).tag(category)
                        }
                    }
                }
                
                // Rest of the form content remains the same
                // ...
            }
            .navigationTitle("Add Expense")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveExpense()
                    }
                    .disabled(!formIsValid)
                }
            }
            .onAppear {
                // Initial setup
                setupDefaultValues()
            }
            .alert(isPresented: $showingAlert) {
                Alert(
                    title: Text(alertTitle),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
    
    private func setupDefaultValues() {
        // Select all participants by default
        selectedSplitEmails = allParticipants
        
        // Set current user as the payer by default
        if let currentEmail = cloudKitHelper.getCurrentUserEmail(), allParticipants.contains(currentEmail) {
            paidByEmail = currentEmail
        } else if !allParticipants.isEmpty {
            paidByEmail = allParticipants[0]
        }
        
        // Initialize split items for percentage (equal percentage initially)
        initializePercentageSplit()
    }
    
    private func initializePercentageSplit() {
        // Create split items with equal percentages
        splitItems = []
        let equalPercentage = 100.0 / Double(allParticipants.count)
        
        for email in allParticipants {
            splitItems.append(SplitItem(
                email: email,
                value: equalPercentage
            ))
        }
    }
    
    private func initializeFixedSplit() {
        // Create split items with equal fixed amounts
        splitItems = []
        if let amountValue = Double(amount), !allParticipants.isEmpty {
            let equalAmount = amountValue / Double(allParticipants.count)
            
            for email in allParticipants {
                splitItems.append(SplitItem(
                    email: email,
                    value: equalAmount
                ))
            }
        }
    }
    
    private func saveExpense() {
        guard let amountValue = Double(amount) else {
            alertTitle = "Invalid Amount"
            alertMessage = "Please enter a valid number for the amount."
            showingAlert = true
            return
        }
        
        guard let currentUserEmail = cloudKitHelper.getCurrentUserEmail() else {
            alertTitle = "Authentication Error"
            alertMessage = "You must be signed in to add expenses."
            showingAlert = true
            return
        }
        
        // Validate based on split type
        switch selectedSplitType {
        case .equal, .dynamic:
            if selectedSplitEmails.isEmpty {
                alertTitle = "Invalid Split"
                alertMessage = "You must select at least one person to split with."
                showingAlert = true
                return
            }
        case .percentage:
            if !validatePercentages() {
                alertTitle = "Invalid Percentages"
                alertMessage = "The percentages must sum to 100%."
                showingAlert = true
                return
            }
        case .fixed:
            if !validateFixedAmounts() {
                alertTitle = "Invalid Fixed Amounts"
                alertMessage = "The fixed amounts must sum to the total expense amount."
                showingAlert = true
                return
            }
        }
        
        // Create the expense
        let newExpense = Expense(
            description: description,
            amount: amountValue,
            date: date,
            paidByEmail: paidByEmail,
            splitType: selectedSplitType,
            splitItems: (selectedSplitType == .percentage || selectedSplitType == .fixed) ? splitItems : nil,
            splitBetweenEmails: selectedSplitEmails,
            categoryName: category.rawValue,
            notes: notes.isEmpty ? nil : notes,
            createdAt: Date(),
            createdByEmail: currentUserEmail
        )
        
        // Save the expense using the view model
        viewModel.addExpense(newExpense) { success, error in
            if success {
                // Dismiss the sheet if saving was successful
                DispatchQueue.main.async {
                    isPresented = false
                }
            } else {
                // Show error
                DispatchQueue.main.async {
                    alertTitle = "Error"
                    alertMessage = error ?? "Failed to save expense"
                    showingAlert = true
                }
            }
        }
    }
}
