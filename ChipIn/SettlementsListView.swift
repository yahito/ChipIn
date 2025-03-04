import SwiftUI

struct SettlementsListView: View {
    let list: ExpenseList
    @State private var settlements: [Settlement] = []
    @State private var isLoading = true
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var selectedSettlement: Settlement?
    @State private var showingActionSheet = false
    @State private var debugMessage = "" // For debugging issues
    @Environment(\.presentationMode) var presentationMode
    @State private var cloudKitHelper = FirebaseStorageHelper()
    @State private var currentUserEmail: String?
    @State private var filterStatus: SettlementFilterStatus = .all
    
    enum SettlementFilterStatus: String, CaseIterable, Identifiable {
        case all = "All"
        case pending = "Pending"
        case confirmed = "Confirmed"
        case rejected = "Rejected"
        
        var id: String { self.rawValue }
        
        func matches(_ status: Settlement.SettlementStatus) -> Bool {
            switch self {
            case .all:
                return true
            case .pending:
                return status == .pending
            case .confirmed:
                return status == .confirmed
            case .rejected:
                return status == .rejected
            }
        }
    }
    
    var filteredSettlements: [Settlement] {
        if filterStatus == .all {
            return settlements
        } else {
            return settlements.filter { settlement in
                switch filterStatus {
                case .pending:
                    return settlement.status == .pending
                case .confirmed:
                    return settlement.status == .confirmed
                case .rejected:
                    return settlement.status == .rejected
                case .all:
                    return true
                }
            }
        }
    }
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("Loading settlements...")
                } else if !debugMessage.isEmpty {
                    // Display debug information
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.orange)
                        
                        Text("Debug Information")
                            .font(.title2)
                            .foregroundColor(.primary)
                        
                        Text(debugMessage)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top, 60)
                } else if settlements.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "tray")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("No settlements yet")
                            .font(.title2)
                            .foregroundColor(.gray)
                        
                        Text("Settlements will appear here when someone records a payment")
                            .font(.body)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top, 60)
                } else {
                    VStack {
                        Picker("Filter", selection: $filterStatus) {
                            ForEach(SettlementFilterStatus.allCases) { status in
                                Text(status.rawValue).tag(status)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding(.horizontal)
                        
                        if filteredSettlements.isEmpty {
                            VStack(spacing: 20) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 40))
                                    .foregroundColor(.gray)
                                
                                Text("No \(filterStatus.rawValue.lowercased()) settlements")
                                    .font(.headline)
                                    .foregroundColor(.gray)
                            }
                            .padding(.top, 60)
                        } else {
                            List {
                                ForEach(filteredSettlements) { settlement in
                                    SettlementRow(settlement: settlement, currentUserEmail: currentUserEmail ?? "")
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            if settlement.status == .pending && settlement.toEmail == currentUserEmail {
                                                selectedSettlement = settlement
                                                showingActionSheet = true
                                            }
                                        }
                                }
                            }
                            .listStyle(InsetGroupedListStyle())
                        }
                    }
                }
            }
            .navigationTitle("Settlements")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Refresh") {
                        loadSettlements()
                    }
                }
            }
            .onAppear {
                currentUserEmail = cloudKitHelper.getCurrentUserEmail()
                print("Current user email: \(currentUserEmail ?? "none")")
                print("List ID: \(list.id)")
                loadSettlements()
            }
            .alert(isPresented: $showingAlert) {
                Alert(
                    title: Text(alertTitle),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
            .actionSheet(isPresented: $showingActionSheet) {
                ActionSheet(
                    title: Text("Confirm Settlement"),
                    message: Text("This will mark the settlement as confirmed and update the balances."),
                    buttons: [
                        .default(Text("Confirm Payment")) {
                            confirmSettlement()
                        },
                        .destructive(Text("Reject Payment")) {
                            rejectSettlement()
                        },
                        .cancel()
                    ]
                )
            }
        }
    }
    
    private func loadSettlements() {
        isLoading = true
        print("Loading settlements for list: \(list.id)")
        
        // Use the list ID parameter when fetching settlements
        cloudKitHelper.fetchSettlements(listId: list.id) { fetchedSettlements in
            DispatchQueue.main.async {
                print("Settlements fetched: \(fetchedSettlements.count)")
                
                if fetchedSettlements.isEmpty {
                    // Check if current user is null
                    if currentUserEmail == nil {
                        debugMessage = "Authentication issue: Not logged in or email not available."
                    } else {
                        // No debug message needed, just normal empty state
                    }
                }
                
                self.settlements = fetchedSettlements.sorted { $0.date > $1.date } // Sort newest first
                self.isLoading = false
            }
        }
    }
    
    private func confirmSettlement() {
        guard let settlement = selectedSettlement else { return }
        
        // Use list ID parameter when confirming settlement
        cloudKitHelper.confirmSettlement(listId: list.id, settlementId: settlement.id) { success, error in
            DispatchQueue.main.async {
                if success {
                    alertTitle = "Success"
                    alertMessage = "The settlement has been confirmed."
                    showingAlert = true
                    loadSettlements() // Reload to update the list
                } else {
                    alertTitle = "Error"
                    alertMessage = error ?? "Failed to confirm settlement."
                    showingAlert = true
                }
            }
        }
    }
    
    private func rejectSettlement() {
        guard let settlement = selectedSettlement else { return }
        
        // Use list ID parameter when rejecting settlement
        cloudKitHelper.rejectSettlement(listId: list.id, settlementId: settlement.id) { success, error in
            DispatchQueue.main.async {
                if success {
                    alertTitle = "Settlement Rejected"
                    alertMessage = "The settlement has been marked as rejected."
                    showingAlert = true
                    loadSettlements() // Reload to update the list
                } else {
                    alertTitle = "Error"
                    alertMessage = error ?? "Failed to reject settlement."
                    showingAlert = true
                }
            }
        }
    }
}


struct SettlementRow: View {
    let settlement: Settlement
    let currentUserEmail: String
    
    private var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD" // Could be made configurable
        return formatter.string(from: NSNumber(value: settlement.amount)) ?? "$\(settlement.amount)"
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: settlement.date)
    }
    
    private var statusColor: Color {
        switch settlement.status {
        case .pending: return .orange
        case .confirmed: return .green
        case .rejected: return .red
        }
    }
    
    private var isOutgoing: Bool {
        return settlement.fromEmail == currentUserEmail
    }
    
    private var isExternal: Bool {
        // External settlements are created and confirmed by the same person (the recipient)
        return settlement.status == .confirmed &&
               settlement.confirmedByEmail != nil &&
               settlement.createdByEmail == settlement.confirmedByEmail &&
               settlement.toEmail == settlement.createdByEmail
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                VStack(alignment: .leading) {
                    if isOutgoing {
                        Text("You paid \(settlement.toEmail)")
                            .font(.headline)
                    } else {
                        Text("\(settlement.fromEmail) paid you")
                            .font(.headline)
                    }
                    
                    Text(formattedDate)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text(formattedAmount)
                        .font(.headline)
                        .foregroundColor(.blue)
                    
                    HStack(spacing: 4) {
                        if isExternal {
                            Text("External")
                                .font(.caption)
                                .padding(4)
                                .background(Color.purple.opacity(0.2))
                                .foregroundColor(.purple)
                                .cornerRadius(4)
                        }
                        
                        Text(settlement.status.rawValue.capitalized)
                            .font(.caption)
                            .padding(4)
                            .background(statusColor.opacity(0.2))
                            .foregroundColor(statusColor)
                            .cornerRadius(4)
                    }
                }
            }
            
            if !settlement.description.isEmpty {
                Text(settlement.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
            
            if settlement.status == .pending && settlement.toEmail == currentUserEmail {
                Text("Tap to confirm or reject")
                    .font(.caption)
                    .foregroundColor(.blue)
                    .padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
    }
}
