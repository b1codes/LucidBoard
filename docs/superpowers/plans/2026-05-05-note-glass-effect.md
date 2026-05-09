# Note Glass Effect Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enhance the visual aesthetic of notes by implementing an adaptive "glass" effect using material blurs and luminance-based opacity.

**Architecture:** Extend `Color` with luminance calculation, then use this in `NoteView` to dynamically set opacity for a layered background (Material + Tint + Border).

**Tech Stack:** SwiftUI

---

### Task 1: Add Luminance Helper to Color

**Files:**
- Modify: `LucidBoard/LucidBoard/Views/NoteView.swift` (or a dedicated extension file if available)

- [ ] **Step 1: Implement luminance calculation**

Add this extension to `Color` in `NoteView.swift`:

```swift
extension Color {
    var luminance: Double {
        let uiColor = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        
        // standard relative luminance formula
        return 0.2126 * Double(r) + 0.7152 * Double(g) + 0.0722 * Double(b)
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add LucidBoard/LucidBoard/Views/NoteView.swift
git commit -m "style: add luminance helper to Color"
```

---

### Task 2: Implement Adaptive Opacity Logic in NoteView

**Files:**
- Modify: `LucidBoard/LucidBoard/Views/NoteView.swift`

- [ ] **Step 1: Define adaptive opacity property**

Inside `struct NoteView`, add a computed property:

```swift
    private var adaptiveOpacity: Double {
        let baseColor = Color(hex: viewModel.note.color)
        return baseColor.luminance > 0.5 ? 0.35 : 0.55
    }
```

- [ ] **Step 2: Update background layering**

Replace the current `.background` modifier in `NoteView.swift` (around line 95):

```swift
        .background(
            ZStack {
                noteShape
                    .fill(.ultraThinMaterial)
                noteShape
                    .fill(Color(hex: viewModel.note.color).opacity(adaptiveOpacity))
            }
        )
```

- [ ] **Step 3: Commit**

```bash
git add LucidBoard/LucidBoard/Views/NoteView.swift
git commit -m "style: implement adaptive opacity and layered background material"
```

---

### Task 3: Refine Border and Shadow

**Files:**
- Modify: `LucidBoard/LucidBoard/Views/NoteView.swift`

- [ ] **Step 1: Update border and shadow**

Update the styling modifiers in `NoteView.swift`:

```swift
        .clipShape(noteShape)
        .overlay(
            noteShape
                .strokeBorder(
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

- [ ] **Step 2: Commit**

```bash
git add LucidBoard/LucidBoard/Views/NoteView.swift
git commit -m "style: add refined border gradient and soft shadow"
```

---

### Task 4: Content Readability Polish

**Files:**
- Modify: `LucidBoard/LucidBoard/Views/NoteView.swift`

- [ ] **Step 1: Update icon styles for vibrancy**

Update the header icons in `NoteView.swift` to use `.secondary` more consistently:

```swift
                Button(action: { mode = .text }) {
                    Image(systemName: "text.alignleft")
                        .foregroundStyle(mode == .text ? .primary : .secondary)
                }
                Button(action: { mode = .drawing }) {
                    Image(systemName: "pencil.tip")
                        .foregroundStyle(mode == .drawing ? .primary : .secondary)
                }
```

- [ ] **Step 2: Verify TextEditor transparency**

Ensure `TextEditor` has `scrollContentBackground(.hidden)` (already present, but verify it works with the new background).

- [ ] **Step 3: Commit**

```bash
git add LucidBoard/LucidBoard/Views/NoteView.swift
git commit -m "style: polish content readability with secondary foreground styles"
```

---

### Task 5: Adaptive Text Color & Style Consistency

**Files:**
- Modify: `LucidBoard/LucidBoard/Views/NoteView.swift`

- [ ] **Step 1: Define adaptive foreground color**

Inside `struct NoteView`, add:

```swift
    private var contentForegroundColor: Color {
        let baseColor = Color(hex: viewModel.note.color)
        // If note is dark, use white text. If note is light, use primary (which adapts to dark/light mode background)
        return baseColor.luminance < 0.4 ? .white : .primary
    }
```

- [ ] **Step 2: Apply adaptive color to text and icons**

Update `NoteView.swift` to use `contentForegroundColor` for the `TextEditor` and header buttons.

- [ ] **Step 3: Standardize on .foregroundStyle**

Replace any remaining `.foregroundColor` with `.foregroundStyle` in `NoteView.swift` for consistency.

- [ ] **Step 4: Commit**

```bash
git add LucidBoard/LucidBoard/Views/NoteView.swift
git commit -m "style: implement adaptive text contrast and standardize style modifiers"
```
