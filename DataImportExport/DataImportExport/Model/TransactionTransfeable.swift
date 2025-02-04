//
//  TransactionTransfeable.swift
//  DataImportExport
//
//  Created by Adrian Suryo Abiyoga on 23/01/25.
//

import SwiftUI
import CryptoKit

struct TransactionTransferable: Transferable {
    var transactions: [Transaction]
    var key: String
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .data) {
            let data = try JSONEncoder().encode($0.transactions)
            guard let encryptedData = try AES.GCM.seal(data, using: .key($0.key)).combined else {
                throw EncryptionError.encryptionFailed
            }
            
            return encryptedData
        }
    }
    
    enum EncryptionError: Error {
        case encryptionFailed
    }
}

extension SymmetricKey {
    static func key(_ value: String) -> SymmetricKey {
        let keyData = value.data(using: .utf8)!
        let sha256 = SHA256.hash(data: keyData)
        
        return .init(data: sha256)
    }
}
