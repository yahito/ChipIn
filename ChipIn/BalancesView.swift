import SwiftUI

struct BalancesView: View {
    let list: ExpenseList
    let balances: [String: Double]
    @Environment(\.presentationMode) var presentationMode
    @State private var currencyCode: String = "USD"
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Individual Balances")) {
                    if balances.isEmpty {
                        Text("No balances to display")
                            .foregroundColor(.secondary)
                            .padding(.vertical, 8)
                    } else {
                        ForEach(balances.keys.sorted(), id: \.self) { email in
                            HStack {
                                Text(email)
                                    .font(.body)
                                
                                Spacer()
                                
                                Text(formattedBalance(balances[email] ?? 0))
                                    .font(.headline)
                                    .foregroundColor(balanceColor(balances[email] ?? 0))
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                
                Section(header: Text("Understanding Balances")) {
                    Text("• Positive amount (green) means others owe you money")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    
                    Text("• Negative amount (red) means you owe money to others")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    
                    Text("• Zero balance means you're all settled up")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                
                Section {
                    Button(action: {
                        // Navigate to settlements view
                        presentationMode.wrappedValue.dismiss()
                        
                        // In a real implementation, you might want to use a callback or more
                        // sophisticated navigation to show the SettlementsView
                    }) {
                        HStack {
                            Text("View Suggested Settlements")
                                .foregroundColor(.blue)
                            
                            Spacer()
                            
                            Image(systemName: "arrow.right")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Balances")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
    
    private func formattedBalance(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }
    
    private func balanceColor(_ amount: Double) -> Color {
        if amount > 0 {
            return .green
        } else if amount < 0 {
            return .red
        } else {
            return .primary
        }
    }
}

// Preview
struct BalancesView_Previews: PreviewProvider {
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
        
        return BalancesView(list: list, balances: sampleBalances)
    }
}
