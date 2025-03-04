//
//  ShareListView.swift
//  ChipIn
//
//  Created by Andrey on 01/03/2025.
//

import Foundation
import SwiftUI

struct ShareListView: View {
    @ObservedObject var viewModel: ShareListViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var email = ""
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    
    var body: some View {
        VStack {
            List {
                Section(header: Text("Share With User")) {
                    TextField("Enter email address", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    Button("Share") {
                        // Normalize the email before sharing
                        let normalizedEmail = email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                        viewModel.shareList(withEmail: normalizedEmail) { success, message in
                            alertTitle = success ? "Success" : "Error"
                            alertMessage = message ?? (success ? "List shared successfully" : "Failed to share list")
                            showingAlert = true
                            
                            if success {
                                email = ""
                            }
                        }
                    }
                    .disabled(email.isEmpty)
                }
                
                if !viewModel.sharedEmails.isEmpty {
                    Section(header: Text("Shared With")) {
                        ForEach(viewModel.sharedEmails, id: \.self) { email in
                            HStack {
                                Text(email)
                                    .font(.headline)
                                Spacer()
                                if viewModel.isOwner {
                                    Button {
                                        viewModel.removeAccess(forEmail: email) { success, message in
                                            if !success {
                                                alertTitle = "Error"
                                                alertMessage = message ?? "Failed to remove user"
                                                showingAlert = true
                                            }
                                        }
                                    } label: {
                                        Image(systemName: "person.crop.circle.badge.minus")
                                            .foregroundColor(.red)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Share List")
            .alert(isPresented: $showingAlert) {
                Alert(
                    title: Text(alertTitle),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
        .onAppear {
            viewModel.loadSharedEmails()
        }
    }
}

class ShareListViewModel: ObservableObject {
    @Published var sharedEmails: [String] = []
    let list: ExpenseList
    let cloudKitHelper: FirebaseStorageHelper
    var isOwner: Bool
    
    init(list: ExpenseList, cloudKitHelper: FirebaseStorageHelper) {
        self.list = list
        self.cloudKitHelper = cloudKitHelper
        self.isOwner = list.isOwner
        
        // Load shared emails on init
        loadSharedEmails()
    }
    
    func loadSharedEmails() {
        // Directly use the emails from the ExpenseList model
        self.sharedEmails = list.sharedEmails
    }
    
    func shareList(withEmail email: String, completion: @escaping (Bool, String?) -> Void) {
        // Validate the email format
        if !isValidEmail(email) {
            completion(false, "Invalid email format")
            return
        }
        
        cloudKitHelper.shareExpenseList(listId: list.id, withEmail: email) { [weak self] success, message in
            if success {
                // Update the local array if sharing was successful
                DispatchQueue.main.async {                    
                    if !(self?.sharedEmails.contains(email) ?? false) {
                        self?.sharedEmails.append(email)
                    }
                }
            }
            completion(success, message)
        }
    }
    
    func removeAccess(forEmail email: String, completion: @escaping (Bool, String?) -> Void) {
        cloudKitHelper.removeUserAccess(listId: list.id, email: email) { [weak self] success, message in
            if success {
                // Update the local array if removal was successful
                DispatchQueue.main.async {
                    self?.sharedEmails.removeAll { $0 == email }
                }
            }
            completion(success, message)
        }
    }
    
    // Email validation helper
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }
}
