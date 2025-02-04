//
//  ContentView.swift
//  DataImportExport
//
//  Created by Adrian Suryo Abiyoga on 23/01/25.
//

import SwiftUI
import SwiftData
import CryptoKit

struct ContentView: View {
    @Query(sort: [.init(\Transaction.transactionDate, order: .reverse)], animation: .snappy)
    private var transactions: [Transaction]
    @Environment(\.modelContext) private var context
    /// View Properties
    @State private var showAlertTF: Bool = false
    @State private var keyTF: String = ""
    @State private var isLoading: Bool = false
    /// Exporter Properties
    @State private var exportItem: TransactionTransferable?
    @State private var showFileExporter: Bool = false
    /// Importer Properties
    @State private var showFileImporter: Bool = false
    @State private var importedURL: URL?
    /// Alert Properties
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    var body: some View {
        NavigationStack {
            List {
                ForEach(transactions) {
                    TransactionView($0)
                }
            }
            .navigationTitle("Transactions")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAlertTF.toggle()
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showFileImporter.toggle()
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                    }
                }
                
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        if transactions.isEmpty {
                            addDummyData("Apple Studio Display", amount: 1799)
                            addDummyData("Mac Studio", amount: 2199)
                            addDummyData("iPhone 15 (Pink)", amount: 799)
                            addDummyData("Apple Watch", amount: 499)
                        } else {
                            let transaction = Transaction(
                                transactionName: "Project",
                                transactionDate: .now,
                                transactionAmount: 1399,
                                transactionCategory: .income
                            )
                            context.insert(transaction)
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
        }
        .overlay {
            LoadingScreen()
        }
        .alert("Enter Key", isPresented: $showAlertTF) {
            TextField("Key", text: $keyTF)
                .autocorrectionDisabled()
            
            Button("Cancel", role: .cancel) {
                keyTF = ""
                importedURL = nil
            }
            
            Button(importedURL != nil ? "Import" : "Export") {
                if importedURL != nil {
                    importData()
                } else {
                    exportData()
                }
            }
        }
        .alert(alertMessage, isPresented: $showAlert) {  }
        .fileExporter(isPresented: $showFileExporter, item: exportItem, contentTypes: [.data], defaultFilename: "Transactions") { result in
            switch result {
            case .success(_):
                print("Success")
            case .failure(let error):
                print(error.localizedDescription)
            }
            
            exportItem = nil
        } onCancellation: {
            exportItem = nil
        }
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.data]) { result in
            switch result {
            case .success(let url):
                importedURL = url
                showAlertTF.toggle()
            case .failure(let error):
                print(error.localizedDescription)
            }
        }
    }
    
    @ViewBuilder
    func TransactionView(_ transaction: Transaction) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.transactionName)
                    .font(.callout)
                    .fontWeight(.semibold)
                
                Text(transaction.transactionDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundStyle(.gray)
            }
            .lineLimit(1)
            
            Spacer(minLength: 0)
            
            Text("$ \(Int(transaction.transactionAmount))")
                .font(.callout)
                .overlay(alignment: .leading) {
                    Image(systemName: "arrow.up")
                        .font(.caption)
                        .rotationEffect(.init(degrees: transaction.transactionCategory == .expense ? 0 : 180))
                        .offset(x: -15)
                }
                .fontWeight(.semibold)
                .foregroundStyle(transaction.transactionCategory == .expense ? .red : .green)
        }
    }
    
    @ViewBuilder
    func LoadingScreen() -> some View {
        ZStack {
            if isLoading {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .overlay {
                        ProgressView()
                            .frame(width: 35, height: 35)
                            .background(.background, in: .rect(cornerRadius: 10))
                    }
                    .ignoresSafeArea()
                    .transition(.opacity)
            }
        }
        .animation(.snappy(duration: 0.25, extraBounce: 0), value: isLoading)
    }
    
    private func exportData() {
        Task.detached(priority: .background) {
            do {
                await toggleLoading(true)
                
                let container = try ModelContainer(for: Transaction.self)
                let context = ModelContext(container)
                
                let descriptor = FetchDescriptor(sortBy: [
                    .init(\Transaction.transactionDate, order: .reverse)
                ])
                
                let allObjects = try context.fetch(descriptor)
                let exportItem = await TransactionTransferable(transactions: allObjects, key: keyTF)
                /// UI Must be on Main Thread
                await MainActor.run {
                    self.exportItem = exportItem
                    showFileExporter = true
                    keyTF = ""
                }
                
                await toggleLoading(false)
            } catch {
                print(error.localizedDescription)
                
                await MainActor.run {
                    showAlertMessage("Exporting Failed!")
                }
            }
        }
    }
    
    private func importData() {
        guard let url = importedURL else { return }
        Task.detached(priority: .background) {
            do {
                guard url.startAccessingSecurityScopedResource() else { return }
                
                await toggleLoading(true)
                
                let container = try ModelContainer(for: Transaction.self)
                let context = ModelContext(container)
                
                let encryptedData = try Data(contentsOf: url)
                let decryptedData = try await AES.GCM.open(.init(combined: encryptedData), using: .key(keyTF))
                
                let allTransactions = try JSONDecoder().decode([Transaction].self, from: decryptedData)
                
                for transaction in allTransactions {
                    context.insert(transaction)
                }
                
                try context.save()
                
                await toggleLoading(false)
                
                url.stopAccessingSecurityScopedResource()
            } catch {
                print(error.localizedDescription)
                
                await MainActor.run {
                    showAlertMessage("Import Failed, Check whether the key is typed correctly.")
                }
            }
        }
    }
    
    private func toggleLoading(_ status: Bool) async {
        await MainActor.run {
            isLoading = status
        }
    }
    
    private func showAlertMessage(_ message: String) {
        alertMessage = message
        showAlert.toggle()
        isLoading = false
        keyTF = ""
    }
    
    private func addDummyData(_ name: String, amount: Double) {
        let transaction = Transaction(
            transactionName: name,
            transactionDate: .now,
            transactionAmount: amount,
            transactionCategory: .expense
        )
        
        context.insert(transaction)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Transaction.self)
}
