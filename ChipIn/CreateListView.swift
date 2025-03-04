import SwiftUI
import FirebaseAuth
import Firebase
import GoogleSignIn

import SwiftUI
import FirebaseAuth
import Firebase
import FirebaseStorage
import FirebaseFirestore
import GoogleSignIn



struct HomeView: View {
    @State private var expenseLists: [ExpenseList] = []
    @State private var isShowingCreateList = false
    @State private var isLoggedIn = false
    @State private var email = ""
    @State private var password = ""
    @State private var isShowingLogin = false
    @State private var errorMessage = ""
    let cloudKitHelper = FirebaseStorageHelper()

    var body: some View {
        NavigationView {
            if isLoggedIn {
                // Main content (expense lists)
                VStack {
                    List(expenseLists) { list in
                        NavigationLink(destination: ListDetailView(list: list)) {
                            Text(list.name)
                                .font(.headline)
                        }
                    }
                    .listStyle(InsetGroupedListStyle())

                    Button(action: {
                        isShowingCreateList = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Create New List")
                                .font(.headline)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding(.horizontal)
                    }
                }
                .navigationTitle("Expense Lists")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Log Out") {
                            logout()
                        }
                    }
                }
                .sheet(isPresented: $isShowingCreateList) {
                                  CreateListView(isPresented: $isShowingCreateList, expenseLists: $expenseLists, cloudKitHelper: cloudKitHelper)
                              }
                              .onAppear {
                                  cloudKitHelper.fetchExpenseLists { lists in
                                      self.expenseLists = lists
                                  }
                              }
            } else {
                // Login screen
                VStack {
                    Text("Expense Splitter")
                        .font(.largeTitle)
                        .padding()

                    TextField("Email", text: $email)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding()

                    SecureField("Password", text: $password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding()

                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .padding()
                    }

                    Button(action: {
                        login()
                    }) {
                        Text("Log In")
                            .font(.headline)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)

                    Button(action: {
                        register()
                    }) {
                        Text("Register")
                            .font(.headline)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                    
                    Button(action: {
                        signInWithGoogle()
                    }) {
                        HStack {
                            Image(systemName: "g.circle.fill")
                            Text("Sign in with Google")
                                .font(.headline)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding(.horizontal)
                    }
                }
                .padding()
            }
        }
        .onAppear {
            checkAuth()
        }
    }
    



    // Check if the user is already logged in
    private func checkAuth() {
        if Auth.auth().currentUser != nil {
            isLoggedIn = true
        }
    }

    // Log in with Firebase
    private func login() {
        Auth.auth().signIn(withEmail: email, password: password) { result, error in
            if let error = error {
                errorMessage = error.localizedDescription
            } else {
                isLoggedIn = true
                errorMessage = ""
            }
        }
    }

    // Register a new user with Firebase
    private func register() {
        Auth.auth().createUser(withEmail: email, password: password) { result, error in
            if let error = error {
                errorMessage = error.localizedDescription
            } else {
                isLoggedIn = true
                errorMessage = ""
            }
        }
    }

    // Log out
    private func logout() {
        do {
            try Auth.auth().signOut()
            isLoggedIn = false
            email = ""
            password = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    public func signInWithGoogle() {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            errorMessage = "Firebase client ID not found."
            return
        }

        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        guard let rootViewController = UIApplication.shared.windows.first?.rootViewController else {
            return
        }

        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { result, error in
            if let error = error {
                errorMessage = error.localizedDescription
                return
            }

            guard let user = result?.user, let idToken = user.idToken?.tokenString else {
                errorMessage = "Google Sign-In failed."
                return
            }

            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: user.accessToken.tokenString)

            Auth.auth().signIn(with: credential) { authResult, error in
                if let error = error {
                    errorMessage = error.localizedDescription
                } else {
                    isLoggedIn = true
                }
            }
        }
    }
}

struct CreateListView: View {
    @Binding var isPresented: Bool
    @Binding var expenseLists: [ExpenseList]
    var cloudKitHelper: FirebaseStorageHelper
    @State private var newListName = ""

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("List Name")) {
                    TextField("Enter list name", text: $newListName)
                }
            }
            .navigationTitle("New List")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let newList = ExpenseList(id: UUID().uuidString, name: newListName)
                        cloudKitHelper.saveExpenseList(expenseList: newList) {
                            expenseLists.append(newList)
                        }
                        isPresented = false
                    }
                    .disabled(newListName.isEmpty)
                }
            }
        }
    }
}


struct SharedUser {
    let id: String
    let email: String
    let name: String
}

// Preview
struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}
