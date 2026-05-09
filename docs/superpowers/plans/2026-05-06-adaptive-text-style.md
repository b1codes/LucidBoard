# Adaptive Text Color & Style Consistency Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ensure text and icons in `NoteView` are readable on any background color and modernize the codebase by using `.foregroundStyle`.

**Architecture:** Add a computed property `contentForegroundColor` to `NoteView` that chooses between white and primary based on the note's luminance. Apply this color to all text and icon elements, standardizing on `.foregroundStyle`.

**Tech Stack:** SwiftUI

---

### Task 1: Refine NoteView Styles

**Files:**
- Modify: `LucidBoard/LucidBoard/Views/NoteView.swift`

- [ ] **Step 1: Update adaptive foreground color and opacity**

Ensure `contentForegroundColor` is present and update the secondary icon opacities to `.opacity(0.8)` as requested.

```swift
    private var contentForegroundColor: Color {
        let baseColor = Color(hex: viewModel.note.color)
        // If note is dark, use white text. If note is light, use primary (which adapts to dark/light mode background)
        return baseColor.luminance < 0.4 ? .white : .primary
    }
```

Update the buttons and icons in the `HStack`:

```swift
            HStack {
                Button(action: { mode = .text }) {
                    Image(systemName: "text.alignleft")
                        .foregroundStyle(mode == .text ? contentForegroundColor : contentForegroundColor.opacity(0.8))
                }
                Button(action: { mode = .drawing }) {
                    Image(systemName: "pencil.tip")
                        .foregroundStyle(mode == .drawing ? contentForegroundColor : contentForegroundColor.opacity(0.8))
                }
                
                Menu {
                    Section("Templates") {
                        Button("Plain") { viewModel.updateTemplate(.plain) }
                        Button("Checklist") { viewModel.updateTemplate(.checklist) }
                        Button("Lined") { viewModel.updateTemplate(.lined) }
                        Button("Circle") { viewModel.updateTemplate(.circle) }
                        Button("Diamond") { viewModel.updateTemplate(.diamond) }
                    }
                } label: {
                    Image(systemName: "doc.richtext.fill")
                        .foregroundStyle(contentForegroundColor.opacity(0.8))
                }
                
                Spacer()
                ColorPicker("", selection: colorBinding, supportsOpacity: false)
                    .labelsHidden()
                    .frame(width: 28, height: 28)
                Image(systemName: "hand.tap")
                    .foregroundStyle(viewModel.isDragging ? .blue : contentForegroundColor.opacity(0.8))
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundStyle(.red.opacity(0.8))
                }
            }
```

- [ ] **Step 2: Verify and standardize .foregroundStyle**

Ensure `TextEditor` uses `.foregroundStyle(contentForegroundColor)` and that no `.foregroundColor` calls remain in the file.

- [ ] **Step 3: Verify build**

Run: `XcodeBuild` or check for issues in the file.

- [ ] **Step 4: Commit**

```bash
git add LucidBoard/LucidBoard/Views/NoteView.swift
git commit -m "style: implement adaptive text contrast and standardize style modifiers"
```

### Task 2: Standardize NoteTemplateView Styles (Bonus/Consistency)

While the task specifically mentioned `NoteView.swift`, the `ChecklistContentView` in `NoteTemplateView.swift` still uses `.foregroundColor`. To maintain style consistency across the note content, I will update it as well.

**Files:**
- Modify: `LucidBoard/LucidBoard/Views/NoteTemplateView.swift`

- [ ] **Step 1: Pass contentForegroundColor to NoteTemplateView**

Modify `NoteView.swift` to pass the color:
```swift
NoteTemplateView(viewModel: viewModel, mode: mode, contentForegroundColor: contentForegroundColor)
```

- [ ] **Step 2: Update NoteTemplateView and ChecklistContentView**

Update `NoteTemplateView.swift` to accept the color and use `.foregroundStyle`.

```swift
struct NoteTemplateView: View {
    @ObservedObject var viewModel: NoteViewModel
    var mode: NoteView.NoteMode
    var contentForegroundColor: Color
    ...
```

And update `ChecklistContentView` to use `contentForegroundColor` for the text and `.foregroundStyle` for everything else.

- [ ] **Step 3: Commit**

```bash
git add LucidBoard/LucidBoard/Views/NoteView.swift LucidBoard/LucidBoard/Views/NoteTemplateView.swift
git commit -m "style: standardize on .foregroundStyle in NoteTemplateView and apply adaptive colors"
```
