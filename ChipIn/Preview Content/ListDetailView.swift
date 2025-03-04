import SwiftUI

struct ListDetailView: View {
    let list: ExpenseList
    @StateObject private var viewModel: ExpensesViewModel
    @State private var isShowingAddExpense = false
    @State private var isShowingBalances = false
    @State private var isShowingSettlements = false
    
    init(list: ExpenseList, cloudKitHelper: FirebaseStorageHelper = FirebaseStorageHelper()) {
        self.list = list
        _viewModel = StateObject(wrappedValue: ExpensesViewModel(cloudKitHelper: cloudKitHelper, listId: list.id))
    }
    
    var body: some View {
        VStack {
            if viewModel.isLoading {
                ProgressView("Loading expenses...")
            } else {
                if viewModel.expenses.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "tray")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("No expenses yet")
                            .font(.title2)
                            .foregroundColor(.gray)
                        
                        Text("Add your first expense by tapping the + button")
                            .font(.body)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top, 60)
                } else {
                    List {
                        Section(header: Text("Expenses")) {
                            ForEach(viewModel.expenses) { expense in
                                ExpenseRow(expense: expense)
                            }
                            .onDelete(perform: viewModel.deleteExpense)
                        }
                    }
                    .listStyle(InsetGroupedListStyle())
                }
            }
            
            Spacer()
        }
        .navigationTitle(list.name)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    Menu {
                        Button(action: {
                            isShowingBalances = true
                        }) {
                            Label("View Balances", systemImage: "creditcard")
                        }
                        
                        Button(action: {
                            isShowingSettlements = true
                        }) {
                            Label("Settle Up", systemImage: "arrow.triangle.swap")
                        }
                    } label: {
                        Image(systemName: "dollarsign.circle")
                    }
                    
                    NavigationLink(destination: ShareListView(viewModel: ShareListViewModel(list: list, cloudKitHelper: FirebaseStorageHelper()))) {
                        Image(systemName: "person.crop.circle.badge.plus")
                    }
                    .disabled(!list.isOwner) // Only the owner can share
                    
                    Button(action: {
                        isShowingAddExpense = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $isShowingAddExpense) {
            AddExpenseView(viewModel: viewModel, list: list, isPresented: $isShowingAddExpense)
        }
        .sheet(isPresented: $isShowingBalances) {
            BalancesView(list: list, balances: viewModel.balances)
        }
        .sheet(isPresented: $isShowingSettlements) {
            SettlementsView(list: list, balances: viewModel.balances)
        }
        .onAppear {
            viewModel.loadExpenses()
        }
    }
}

struct ExpenseRow: View {
    let expense: Expense
    
    private var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD" // You might want to make this configurable
        return formatter.string(from: NSNumber(value: expense.amount)) ?? "$\(expense.amount)"
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: expense.date)
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                VStack(alignment: .leading) {
                    Text(expense.description)
                        .font(.headline)
                    
                    Text(formattedDate)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(formattedAmount)
                    .font(.headline)
                    .foregroundColor(.blue)
            }
            
            HStack {
                Text("Paid by: \(expense.paidByEmail)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(expense.categoryName)
                    .font(.caption)
                    .padding(4)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(4)
            }
            .padding(.top, 2)
        }
        .padding(.vertical, 4)
    }
}
