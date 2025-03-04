import SwiftUI

struct CreateSettlementView: View {
    let debt: Debt
    let list: ExpenseList
    @Binding var isPresented: Bool
    @State private var cloudKitHelper = FirebaseStorageHelper()
    @State private var description = "Debt settlement"
    @State private var date = Date()
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var isProcessing = false
    @State private var isCheckingExistingSettlements = true
    @State private var existingSettlements: [Settlement] = []
    @Environment(\.presentationMode) var presentationMode
    
    private var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD" // Could be made configurable
        return formatter.string(from: NSNumber(value: debt.amount)) ?? "$\(debt.amount)"
    }
    
    private var hasExistingSettlement: Bool {
        return existingSettlements.contains { settlement in
            // Check if there's a pending or confirmed settlement between the same people for the same amount
            return settlement.fromEmail == debt.fromEmail &&
                   settlement.toEmail == debt.toEmail &&
                   abs(settlement.amount - debt.amount) < 0.01 &&
                   (settlement.status == .pending || settlement.status == .confirmed)
        }
    }
    
    var body: some View {
        NavigationView {
            Group {
                if isCheckingExistingSettlements {
                    VStack {
                        ProgressView("Checking existing settlements...")
                        Text("Please wait...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                    }
                    .padding()
                } else if hasExistingSettlement {
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.orange)
                        
                        Text("A settlement already exists")
                            .font(.title)
                            .multilineTextAlignment(.center)
                        
                        Text("There is already a pending or confirmed settlement for this debt. Please check your settlement history for details.")
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button("View Settlement History") {
                            // In a real app, you would navigate to the settlement history screen
                            isPresented = false
                            self.presentationMode.wrappedValue.dismiss()
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        
                        Button("Cancel") {
                            isPresented = false
                            self.presentationMode.wrappedValue.dismiss()
                        }
                        .padding(.top)
                    }
                    .padding()
                } else {
                    Form {
                        Section(header: Text("Settlement Details")) {
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
                            
                            DatePicker("Date", selection: $date, displayedComponents: .date)
                            
                            TextField("Description", text: $description)
                        }
                        
                        Section(header: Text("Information")) {
                            Text("When you record this settlement, a notification will be sent to the recipient to confirm the payment. The settlement won't be reflected in balances until it's confirmed.")
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
                }
            }
            .navigationTitle("Record Settlement")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                        self.presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !isCheckingExistingSettlements && !hasExistingSettlement {
                        Button("Record") {
                            recordSettlement()
                        }
                        .disabled(isProcessing)
                    }
                }
            }
            .alert(isPresented: $showingAlert) {
                Alert(
                    title: Text(alertTitle),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK")) {
                        if alertTitle == "Success" {
                            isPresented = false
                            self.presentationMode.wrappedValue.dismiss()
                        }
                    }
                )
            }
            .onAppear {
                checkExistingSettlements()
            }
        }
    }
    
    private func checkExistingSettlements() {
        isCheckingExistingSettlements = true
        
        // Update to use list ID parameter
        cloudKitHelper.fetchSettlements(listId: list.id) { settlements in
            DispatchQueue.main.async {
                self.existingSettlements = settlements
                self.isCheckingExistingSettlements = false
            }
        }
    }
    
    private func recordSettlement() {
        guard let currentUserEmail = cloudKitHelper.getCurrentUserEmail() else {
            alertTitle = "Authentication Error"
            alertMessage = "You must be signed in to record a settlement."
            showingAlert = true
            return
        }
        
        // Only allow recording a settlement if the current user is the one who owes money
        guard currentUserEmail == debt.fromEmail else {
            alertTitle = "Permission Error"
            alertMessage = "Only the person who owes money can record paying it."
            showingAlert = true
            return
        }
        
        // Double-check for existing settlements
        if hasExistingSettlement {
            alertTitle = "Duplicate Settlement"
            alertMessage = "A settlement for this debt already exists."
            showingAlert = true
            return
        }
        
        isProcessing = true
        
        // Create the settlement
        let settlement = Settlement(
            fromEmail: debt.fromEmail,
            toEmail: debt.toEmail,
            amount: debt.amount,
            date: date,
            description: description,
            listId: list.id,
            status: .pending,
            createdByEmail: currentUserEmail
        )
        
        // Save the settlement - update to use list ID parameter
        cloudKitHelper.createSettlement(listId: list.id, settlement: settlement) { success, error in
            isProcessing = false
            
            if success {
                alertTitle = "Success"
                alertMessage = "Settlement recorded successfully. The recipient will need to confirm it."
                showingAlert = true
            } else {
                alertTitle = "Error"
                alertMessage = error ?? "Failed to record settlement."
                showingAlert = true
            }
        }
    }
}
