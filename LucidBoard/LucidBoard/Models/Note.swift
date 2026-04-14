//
//  Note.swift
//  LucidBoard
//
//  Created by Gemini CLI.
//

import Foundation

struct Note: Identifiable, Codable, Equatable {
    let id: UUID
    let boardId: UUID
    let userId: UUID
    var contentText: String?
    var contentDrawing: Data?
    var color: String
    var posX: Float
    var posY: Float
    var zIndex: Int
    var createdAt: Date
    var updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case boardId = "board_id"
        case userId = "user_id"
        case contentText = "content_text"
        case contentDrawing = "content_drawing"
        case color
        case posX = "pos_x"
        case posY = "pos_y"
        case zIndex = "z_index"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
