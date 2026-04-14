//
//  Board.swift
//  LucidBoard
//
//  Created by Gemini CLI.
//

import Foundation

struct Board: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case title
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
