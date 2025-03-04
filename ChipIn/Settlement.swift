import Foundation
import FirebaseFirestore

struct Settlement: Identifiable {
    let id: String
    let fromEmail: String
    let toEmail: String
    let amount: Double
    let date: Date
    let description: String
    let listId: String
    let status: SettlementStatus
    let createdByEmail: String
    let confirmedByEmail: String?
    let confirmedDate: Date?
    
    enum SettlementStatus: String, Codable {
        case pending = "pending"
        case confirmed = "confirmed"
        case rejected = "rejected"
    }
    
    // Convenience initializer for creating a new settlement
    init(id: String = UUID().uuidString,
         fromEmail: String,
         toEmail: String,
         amount: Double,
         date: Date = Date(),
         description: String = "Debt settlement",
         listId: String,
         status: SettlementStatus = .pending,
         createdByEmail: String,
         confirmedByEmail: String? = nil,
         confirmedDate: Date? = nil) {
        self.id = id
        self.fromEmail = fromEmail
        self.toEmail = toEmail
        self.amount = amount
        self.date = date
        self.description = description
        self.listId = listId
        self.status = status
        self.createdByEmail = createdByEmail
        self.confirmedByEmail = confirmedByEmail
        self.confirmedDate = confirmedDate
    }
    
    // Convert to dictionary for Firestore
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "fromEmail": fromEmail,
            "toEmail": toEmail,
            "amount": amount,
            "date": Timestamp(date: date),
            "description": description,
            "listId": listId,
            "status": status.rawValue,
            "createdByEmail": createdByEmail
        ]
        
        if let confirmedByEmail = confirmedByEmail {
            dict["confirmedByEmail"] = confirmedByEmail
        }
        
        if let confirmedDate = confirmedDate {
            dict["confirmedDate"] = Timestamp(date: confirmedDate)
        }
        
        return dict
    }
    
    // Create from Firestore document
    static func fromDictionary(_ dict: [String: Any]) -> Settlement? {
        guard
            let id = dict["id"] as? String,
            let fromEmail = dict["fromEmail"] as? String,
            let toEmail = dict["toEmail"] as? String,
            let amount = dict["amount"] as? Double,
            let dateTimestamp = dict["date"] as? Timestamp,
            let description = dict["description"] as? String,
            let listId = dict["listId"] as? String,
            let statusString = dict["status"] as? String,
            let status = SettlementStatus(rawValue: statusString),
            let createdByEmail = dict["createdByEmail"] as? String
        else {
            return nil
        }
        
        let confirmedByEmail = dict["confirmedByEmail"] as? String
        let confirmedDateTimestamp = dict["confirmedDate"] as? Timestamp
        let confirmedDate = confirmedDateTimestamp?.dateValue()
        
        return Settlement(
            id: id,
            fromEmail: fromEmail,
            toEmail: toEmail,
            amount: amount,
            date: dateTimestamp.dateValue(),
            description: description,
            listId: listId,
            status: status,
            createdByEmail: createdByEmail,
            confirmedByEmail: confirmedByEmail,
            confirmedDate: confirmedDate
        )
    }
}
