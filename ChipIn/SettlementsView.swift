import SwiftUI

struct SettlementsView: View {
    let list: ExpenseList
    let balances: [String: Double]
    @State private var simplifiedDebts: [Debt] = []
    @State private var showingSettlementList = false
    @State private var showingCreateSettlement = false
    @State private var selectedDebt: Debt?
    @State private var currencyCode: String = "USD"
    @Environment(\.presentationMode) var presentationMode
    @State private var cloudKitHelper = FirebaseStorageHelper()
    @State private var currentUserEmail: String?
    @State private var adjustedBalances: [String: Double] = [:]
    @State private var isLoadingAdjustedBalances = true
    
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
                                    Button(action: {
                                        // Only allow selecting a debt the current user owes
                                        if debt.fromEmail == currentUserEmail {
                                            selectedDebt = debt
                                            showingCreateSettlement = true
                                        }
                                    }) {
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
                                        }
                                        .foregroundColor(debt.fromEmail == currentUserEmail ? .primary : .secondary)
                                    }
                                    .padding(.vertical, 4)
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
                                Text("Tap on a payment where you're the payer to record it. The payments above represent the simplest way to settle all debts.")
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
                loadAdjustedBalances()
            }
            .sheet(isPresented: $showingSettlementList) {
                SettlementsListView(list: list)
            }
            // Use sheet with isPresented binding instead of sheet with item binding
            .sheet(isPresented: $showingCreateSettlement) {
                // This will be called when the sheet is dismissed
                loadAdjustedBalances()
            } content: {
                if let debt = selectedDebt {
                    CreateSettlementView(debt: debt, list: list, isPresented: $showingCreateSettlement)
                }
            }
        }
    }
    
    private func loadAdjustedBalances() {
        isLoadingAdjustedBalances = true
        
        cloudKitHelper.calculateAdjustedBalances(listId: list.id) { adjustedBalances in
            DispatchQueue.main.async {
                self.adjustedBalances = adjustedBalances
                self.simplifiedDebts = DebtSimplifier.simplifyDebts(balances: adjustedBalances)
                self.isLoadingAdjustedBalances = false
            }
        }
    }
    
    private func formatAmount(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }
}

// Add this extension to make Debt conform to Identifiable
extension Debt: Identifiable {
    var id: String { return "\(fromEmail)-\(toEmail)-\(amount)" }
}

// Preview
struct SettlementsView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleBalances = [
            "user1@example.com": 100.0,
            "user2@example.com": -50.0,
            "user3@example.com": -50.0
        ]
        
        let list = ExpenseList(
            id: "123",
            name: "Trip to Paris",
            ownerId: "owner123",
            ownerEmail: "user1@example.com",
            sharedEmails: ["user2@example.com", "user3@example.com"]
        )
        
        return SettlementsView(list: list, balances: sampleBalances)
    }
}
