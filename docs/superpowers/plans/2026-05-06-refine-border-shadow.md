# Refine Border and Shadow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refine the border gradient and shadow for notes to enhance the "glass" look.

**Architecture:** Update `NoteView.swift` with a gradient overlay and a softer shadow. Ensure `DiamondShape` is compatible with `.strokeBorder` if needed.

**Tech Stack:** SwiftUI

---

### Task 1: Make DiamondShape Insettable

**Files:**
- Modify: `LucidBoard/LucidBoard/LucidBoard/Views/NoteTemplateView.swift`

- [ ] **Step 1: Update DiamondShape to conform to InsettableShape**

```swift
struct DiamondShape: InsettableShape {
    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let insetRect = rect.insetBy(dx: insetAmount, dy: insetAmount)
        var path = Path()
        path.move(to: CGPoint(x: insetRect.midX, y: insetRect.minY))
        path.addLine(to: CGPoint(x: insetRect.maxX, y: insetRect.midY))
        path.addLine(to: CGPoint(x: insetRect.midX, y: insetRect.maxY))
        path.addLine(to: CGPoint(x: insetRect.minY, y: insetRect.midY))
        path.closeSubpath()
        return path
    }

    func inset(by amount: CGFloat) -> some InsettableShape {
        var diamond = self
        diamond.insetAmount += amount
        return diamond
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add LucidBoard/LucidBoard/LucidBoard/Views/NoteTemplateView.swift
git commit -m "style: make DiamondShape conform to InsettableShape"
```

### Task 2: Refine NoteView Border and Shadow

**Files:**
- Modify: `LucidBoard/LucidBoard/LucidBoard/Views/NoteView.swift`

- [ ] **Step 1: Update noteShape and apply refined styling**

Update `noteShape` to avoid `AnyShape` for the overlay if necessary, or just use `stroke` if `AnyShape` is preferred for clipping.
Actually, I will use `stroke` in the overlay with `noteShape` if I can't easily get `strokeBorder` on `AnyShape`. 
Wait, if I want to follow the task EXACTLY, I should try to make `strokeBorder` work.

I'll update `NoteView.swift` to apply the requested changes. I'll use `stroke` if `strokeBorder` is unavailable on `AnyShape`, but I'll try to keep it as close to the requested code as possible. 
Actually, if I change `noteShape` to return `some InsettableShape` (if possible) or use a switch in the overlay.

- [ ] **Step 2: Apply the modifiers**

```swift
        .clipShape(noteShape)
        .overlay(
            noteShape
                .stroke(
                    LinearGradient(
                        colors: [
                            .white.opacity(adaptiveOpacity > 0.4 ? 0.3 : 0.1),
                            .black.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 6)
```
(I'll use `stroke` if `strokeBorder` is not available on `AnyShape`, or I'll fix the shape type).

- [ ] **Step 3: Verify build**

Run: `xcodebuild -project LucidBoard/LucidBoard.xcodeproj -scheme LucidBoard -destination 'platform=iOS Simulator,name=iPhone 15' build` (or use BuildProject tool)

- [ ] **Step 4: Commit**

```bash
git add LucidBoard/LucidBoard/LucidBoard/Views/NoteView.swift
git commit -m "style: add refined border gradient and soft shadow"
```
