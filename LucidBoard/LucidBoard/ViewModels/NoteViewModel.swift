//
//  NoteViewModel.swift
//  LucidBoard
//
//  Created by Gemini CLI.
//

import SwiftUI
import Combine
import PencilKit

class NoteViewModel: ObservableObject, Identifiable {
    @Published var note: Note
    @Published var isDragging: Bool = false
    @Published var drawing: PKDrawing = PKDrawing()
    
    private var cancellables = Set<AnyCancellable>()
    private let supabase = SupabaseService.shared
    
    init(note: Note) {
        self.note = note
        
        // Deserialize drawing if present
        if let drawingData = note.contentDrawing {
            do {
                self.drawing = try PKDrawing(data: drawingData)
            } catch {
                print("Error deserializing drawing: \(error)")
            }
        }
        
        // Observe drawing changes
        $drawing
            .dropFirst()
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { [weak self] newDrawing in
                self?.syncNote()
            }
            .store(in: &cancellables)
            
        // Observe note changes (content text, color, position)
        // Since we modify 'note' directly in some places, we'll use a specific publisher or just call sync manually.
    }
    
    func syncNote() {
        self.note.updatedAt = Date()
        Task {
            try? await supabase.upsertNote(self.note)
        }
    }
    
    var id: UUID { note.id }
    
    func updatePosition(to point: CGPoint) {
        note.posX = Float(point.x)
        note.posY = Float(point.y)
        // We'll sync at the end of dragging to avoid too many writes
    }
    
    func finalizePosition() {
        syncNote()
    }
}
