import SwiftUI

struct SettlementsView: View {
    let list: ExpenseList
    let balances: [String: Double]
    @State private var simplifiedDebts: [Debt] = []
    @State private var showingSettlementList = false
    @State private var showingCreateSettlement = false
    @State private var showingMarkExternalSettlement = false  // New state for external settlements
    @State private var selectedDebt: Debt?
    @State private var currencyCode: String = "USD"
    @Environment(\.presentationMode) var presentationMode
    @State private var cloudKitHelper = FirebaseStorageHelper()
    @State private var currentUserEmail: String?
    @State private var adjustedBalances: [String: Double] = [:]
    @State private var isLoadingAdjustedBalances = true
    @State private var existingSettlements: [Settlement] = []
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoadingAdjustedBalances {
                    ProgressView("Calculating balances...")
                        .padding()
                } else {
                    if simplifiedDebts.isEmpty {
                        Text("Everyone is settled up!")
                            .font(.headline)
                            .padding()
                    } else {
                        List {
                            Section(header: Text("Optimal Payments")) {
                                ForEach(0..<simplifiedDebts.count, id: \.self) { index in
                                    let debt = simplifiedDebts[index]
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(debt.fromEmail)
                                                .font(.headline)
                                            Text("pays")
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Spacer()
                                        
                                        Text(formatAmount(debt.amount))
                                            .font(.headline)
                                            .foregroundColor(.blue)
                                        
                                        VStack(alignment: .trailing) {
                                            Text("to")
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                            Text(debt.toEmail)
                                                .font(.headline)
                                        }
                                        
                                        Menu {
                                            // Option for payer to record payment
                                            if debt.fromEmail == currentUserEmail {
                                                Button(action: {
                                                    selectedDebt = debt
                                                    // Check if there's already a pending settlement
                                                    if !hasExistingSettlement(for: debt) {
                                                        showingCreateSettlement = true
                                                    } else {
                                                        // Show alert about existing settlement
                                                        // In a real app, you'd want to show a proper alert here
                                                    }
                                                }) {
                                                    Label("I Paid This", systemImage: "checkmark.circle")
                                                }
                                            }
                                            
                                            // Option for recipient to mark as externally settled
                                            if debt.toEmail == currentUserEmail {
                                                Button(action: {
                                                    selectedDebt = debt
                                                    showingMarkExternalSettlement = true
                                                }) {
                                                    Label("Mark as Paid", systemImage: "arrow.triangle.2.circlepath")
                                                }
                                            }
                                        } label: {
                                            Image(systemName: "ellipsis.circle")
                                                .foregroundColor(.blue)
                                        }
                                    }
                                    .padding(.vertical, 4)
                                    .foregroundColor(isUserInvolved(in: debt) ? .primary : .secondary)
                                }
                            }
                            
                            Section(header: Text("Actions")) {
                                Button(action: {
                                    showingSettlementList = true
                                }) {
                                    HStack {
                                        Image(systemName: "list.bullet")
                                        Text("View Settlement History")
                                    }
                                }
                            }
                            
                            Section(header: Text("Information")) {
                                Text("Use the menu (⋯) next to a payment to record it. As a payer, choose 'I Paid This'. As a recipient, choose 'Mark as Paid' if you received payment outside the app.")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                                
                                Text("Note: These calculations already take confirmed settlements into account.")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Settle Up")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .onAppear {
                currentUserEmail = cloudKitHelper.getCurrentUserEmail()
                loadData()
            }
            .sheet(isPresented: $showingSettlementList) {
                SettlementsListView(list: list)
            }
            // Use sheet with isPresented binding for normal settlements
            .sheet(isPresented: $showingCreateSettlement) {
                // This will be called when the sheet is dismissed
                loadData()
            } content: {
                if let debt = selectedDebt {
                    CreateSettlementView(debt: debt, list: list, isPresented: $showingCreateSettlement)
                }
            }
            // Use sheet for external settlements
            .sheet(isPresented: $showingMarkExternalSettlement) {
                loadData()
            } content: {
                if let debt = selectedDebt {
                    ExternalSettlementView(debt: debt, list: list, isPresented: $showingMarkExternalSettlement)
                }
            }
        }
    }
    
    private func isUserInvolved(in debt: Debt) -> Bool {
        guard let email = currentUserEmail else { return false }
        return debt.fromEmail == email || debt.toEmail == email
    }
    
    private func hasExistingSettlement(for debt: Debt) -> Bool {
        return existingSettlements.contains { settlement in
            // Check if there's a pending or confirmed settlement between the same people for the same amount
            return settlement.fromEmail == debt.fromEmail &&
                   settlement.toEmail == debt.toEmail &&
                   abs(settlement.amount - debt.amount) < 0.01 &&
                   (settlement.status == .pending || settlement.status == .confirmed)
        }
    }
    
    private func loadData() {
        isLoadingAdjustedBalances = true
        
        // Create a group to wait for both operations
        let group = DispatchGroup()
        
        // First load all settlements
        group.enter()
        cloudKitHelper.fetchSettlements(listId: list.id) { settlements in
            DispatchQueue.main.async {
                self.existingSettlements = settlements
                group.leave()
            }
        }
        
        // Then calculate adjusted balances
        group.enter()
        cloudKitHelper.calculateAdjustedBalances(listId: list.id) { adjustedBalances in
            DispatchQueue.main.async {
                self.adjustedBalances = adjustedBalances
                self.simplifiedDebts = DebtSimplifier.simplifyDebts(balances: adjustedBalances)
                group.leave()
            }
        }
        
        // When both are done, update UI
        group.notify(queue: .main) {
            self.isLoadingAdjustedBalances = false
        }
    }
    
    private func formatAmount(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }
}

// New view for marking external settlements
struct ExternalSettlementView: View {
    let debt: Debt
    let list: ExpenseList
    @Binding var isPresented: Bool
    @State private var cloudKitHelper = FirebaseStorageHelper()
    @State private var description = "External payment received"
    @State private var date = Date()
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var isProcessing = false
    
    private var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD" // Could be made configurable
        return formatter.string(from: NSNumber(value: debt.amount)) ?? "$\(debt.amount)"
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("External Payment Details")) {
                    HStack {
                        Text("From")
                        Spacer()
                        Text(debt.fromEmail)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("To")
                        Spacer()
                        Text(debt.toEmail)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Amount")
                        Spacer()
                        Text(formattedAmount)
                            .foregroundColor(.blue)
                    }
                    
                    DatePicker("Date Received", selection: $date, displayedComponents: .date)
                    
                    TextField("Description", text: $description)
                }
                
                Section(header: Text("Information")) {
                    Text("By marking this as paid, you confirm that you've received payment outside the app. This settlement will be immediately marked as confirmed.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                
                if isProcessing {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView()
                                .padding()
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Mark as Paid")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Confirm") {
                        createExternalSettlement()
                    }
                    .disabled(isProcessing)
                }
            }
            .alert(isPresented: $showingAlert) {
                Alert(
                    title: Text(alertTitle),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK")) {
                        if alertTitle == "Success" {
                            isPresented = false
                        }
                    }
                )
            }
        }
    }
    
    private func createExternalSettlement() {
        guard let currentUserEmail = cloudKitHelper.getCurrentUserEmail() else {
            alertTitle = "Authentication Error"
            alertMessage = "You must be signed in to record a settlement."
            showingAlert = true
            return
        }
        
        // Only allow if the current user is the one who is owed money
        guard currentUserEmail == debt.toEmail else {
            alertTitle = "Permission Error"
            alertMessage = "Only the person who is owed money can mark it as paid."
            showingAlert = true
            return
        }
        
        isProcessing = true
        
        // Create the settlement that's automatically confirmed
        let settlement = Settlement(
            fromEmail: debt.fromEmail,
            toEmail: debt.toEmail,
            amount: debt.amount,
            date: date,
            description: description,
            listId: list.id,
            status: .confirmed, // Automatically confirmed
            createdByEmail: currentUserEmail,
            confirmedByEmail: currentUserEmail,
            confirmedDate: date
        )
        
        // Save the settlement
        cloudKitHelper.createSettlement(listId: list.id, settlement: settlement) { success, error in
            isProcessing = false
            
            if success {
                alertTitle = "Success"
                alertMessage = "Payment has been marked as received."
                showingAlert = true
            } else {
                alertTitle = "Error"
                alertMessage = error ?? "Failed to record settlement."
                showingAlert = true
            }
        }
    }
}

// Add this extension to make Debt conform to Identifiable
extension Debt: Identifiable {
    var id: String { return "\(fromEmail)-\(toEmail)-\(amount)" }
}
