# Design Spec: Note Glass Effect (Visual Polish)

**Date:** 2026-05-05
**Topic:** Enhancing the visual aesthetic of notes to achieve a "glassy" and translucent look.

## 1. Overview
The current implementation of notes in LucidBoard feels "too solid" due to a high opacity color fill (80%). This design introduces a **Dynamic Contrast Glass Effect** that adjusts transparency based on the note's color luminance, while leveraging SwiftUI's material effects for high-quality background blurring.

## 2. Architecture: Adaptive Styling Logic
To maintain readability across different colors and board backgrounds, the styling will be adaptive.

### 2.1 Luminance-Based Opacity
We will calculate the relative luminance of the selected note color:
- **Light Colors (Luminance > 0.5):** Use an opacity range of `0.3` to `0.4`.
- **Dark Colors (Luminance <= 0.5):** Use an opacity range of `0.5` to `0.6`.

### 2.2 Material Layering
The background will be composed of multiple layers to simulate depth:
1. **Base:** `.ultraThinMaterial` providing the system-level blur.
2. **Tint:** An adaptive color fill (using the calculated opacity).
3. **Edge Definition:** A 0.5pt inner stroke to define the shape edges clearly.

## 3. Visual Components

### 3.1 Refined Borders
- **Stroke:** A thin (1.0pt) gradient stroke that mimics light hitting the edges.
- **Gradient:** From a lighter tint of the note color to a darker one.

### 3.2 Enhanced Shadows
- **Shadow:** Increase radius to `12` but reduce opacity to `0.08` to create a "lifted" feel without looking heavy.

### 3.3 Content Readability
- **Vibrancy:** Utilize SwiftUI's `.secondary` and `.tertiary` foreground styles for control icons to ensure they contrast well against the glass material.
- **Transparency:** Ensure `TextEditor` and other content containers have hidden backgrounds to fully expose the material effect.

## 4. Success Criteria
- Notes should appear translucent and clearly blur the underlying board grid/content.
- Light-colored notes (Yellow, White) should feel airy and glass-like.
- Dark-colored notes (Blue, Purple) should remain legible with a deep material feel.
- Edges should be sharp and defined, even with high transparency.

## 5. Implementation Strategy
1. Extend `Color` with a `luminance` helper.
2. Update `NoteView.swift` to calculate adaptive opacity.
3. Refactor the `.background` modifier of the note to use the layered material architecture.
4. Verify accessibility and readability in both Light and Dark modes.
