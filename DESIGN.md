---
name: Rook
description: Route markers for a native iPhone workout record.
colors:
  accent-light: "rgb(45% 29% 7%)"
  accent-dark: "rgb(100% 83.5% 51%)"
  on-accent-light: "rgb(100% 100% 100%)"
  on-accent-dark: "rgb(6.3% 11.4% 18.8%)"
  canvas-light: "rgb(93% 95% 97%)"
  canvas-dark: "rgb(6.3% 11.4% 18.8%)"
  surface-light: "rgb(100% 100% 100%)"
  surface-dark: "rgb(9.8% 16.1% 25.1%)"
  secondary-light: "rgb(31% 38% 47%)"
  secondary-dark: "rgb(70% 77% 85%)"
  track-light: "rgb(76% 81% 87%)"
  track-dark: "rgb(21% 28% 37%)"
typography:
  title:
    fontFamily: "-apple-system, BlinkMacSystemFont, sans-serif"
    fontWeight: 700
  title2:
    fontFamily: "-apple-system, BlinkMacSystemFont, sans-serif"
    fontWeight: 700
  title3:
    fontFamily: "-apple-system, BlinkMacSystemFont, sans-serif"
    fontWeight: 700
  headline:
    fontFamily: "-apple-system, BlinkMacSystemFont, sans-serif"
  body:
    fontFamily: "-apple-system, BlinkMacSystemFont, sans-serif"
  subheadline:
    fontFamily: "-apple-system, BlinkMacSystemFont, sans-serif"
  caption:
    fontFamily: "-apple-system, BlinkMacSystemFont, sans-serif"
  footnote:
    fontFamily: "-apple-system, BlinkMacSystemFont, sans-serif"
  numeric:
    fontFamily: "-apple-system, BlinkMacSystemFont, sans-serif"
    fontFeature: "'tnum' 1"
spacing:
  tight: "3pt"
  detail: "5pt"
  marker: "6pt"
  row: "8pt"
  section: "12pt"
  privacy: "16pt"
  introduction: "18pt"
components:
  button-primary-light:
    backgroundColor: "{colors.accent-light}"
    textColor: "{colors.on-accent-light}"
  button-primary-dark:
    backgroundColor: "{colors.accent-dark}"
    textColor: "{colors.on-accent-dark}"
  action-bordered-light:
    textColor: "{colors.accent-light}"
  action-bordered-dark:
    textColor: "{colors.accent-dark}"
  numeric-field:
    typography: "{typography.numeric}"
  completion-marker-light:
    backgroundColor: "{colors.accent-light}"
    textColor: "{colors.on-accent-light}"
  completion-marker-dark:
    backgroundColor: "{colors.accent-dark}"
    textColor: "{colors.on-accent-dark}"
  incomplete-marker-light:
    backgroundColor: "{colors.track-light}"
  incomplete-marker-dark:
    backgroundColor: "{colors.track-dark}"
---

<!-- markdownlint-disable MD025 MD026 MD036 -->

# Design System: Rook

## Overview

**Creative North Star: "Route markers"**

Rook is a native iPhone Operate interface for recording sets between efforts. Route markers makes completed work and the next editable set easy to find through adaptive navy/slate surfaces, warm amber interaction tint, and clear completion marks.

Native SF typography, Dynamic Type, lists, controls, and navigation carry the interface. Brand expression stays in adaptive roles and meaningful markers; decorative motivation, rings, and dense dashboard chrome do not belong in the active-workout surface.

**Key Characteristics:**

- Adaptive navy/slate surfaces with amber interaction tint.
- System SF text styles, tabular training values, and generous touch targets.
- Native list hierarchy and explicit incomplete/completed set markers.

This documents the built SwiftUI implementation, not a proposed redesign. The six native source files listed under Components are the implementation authority.

## Colors

The palette pairs cool adaptive surfaces with an amber interaction role; light and dark are role variants, not a generated color ramp.

Frontmatter percentages preserve the UIColor RGB fractions in `apple/Rook/Theme.swift` exactly: each channel is multiplied by 100, alpha remains opaque, and UIColor.white maps to full RGB channels. The suffix selects the native appearance variant. These are serialized descriptions of the native colors, not a stylesheet to replace adaptive UIColor providers.

### Primary

- **Amber interaction — `accent-light` / `accent-dark`:** global tint, prominent actions, rest actions, exercise progress, completed markers, and separate Progress chart marks.
- **On amber — `on-accent-light` / `on-accent-dark`:** foreground for `rookPrimary()` and completed-set controls. Keep it paired with the matching appearance's accent.

### Neutral

- **Navy/slate canvas — `canvas-light` / `canvas-dark`:** root, list background with hidden default scroll background, and privacy cover.
- **Raised list surface — `surface-light` / `surface-dark`:** routine, workout, history, and form rows. Transparent narrative rows expose the canvas.
- **Secondary slate text — `secondary-light` / `secondary-dark`:** elapsed/count metadata, previous values, explanations, and the active-workout exercise footer. That footer explicitly uses `RookColor.secondary`.
- **Incomplete track — `track-light` / `track-dark`:** incomplete completion-button tint. It is not an extracted specification for the system ProgressView track.
- **System primary and status:** ordinary primary text and incomplete-marker foreground remain SwiftUI `Color.primary`; native destructive roles and the chart's `.red` error text remain system-managed. No fixed RGB substitute is defined.

**The Native Foreground Rule.** Keep primary text system-managed and pair each adaptive accent with its matching on-accent foreground.

## Typography

The font-family serialization means Apple's native system SF family. It is not a shipped web font stack. Typography keys describe SwiftUI semantic styles, not a fixed-size type scale; the title weights reflect explicit `.bold()` in source.

- **Title:** `.title.bold()` for the active routine, rest clock, and privacy title; `.title2.bold()` for the routine empty-state invitation; `.title3.bold()` for routine names.
- **Headline:** exercise headings, set labels in the accessibility layout, resume labels, and history routine names.
- **Body:** normal text and numeric editing. The compact set index uses `.body.bold()`.
- **Subheadline:** elapsed/count metadata and history summaries.
- **Caption:** compact column labels and previous-set values.
- **Footnote:** quieter routine, history, and settings explanations.
- **Numeric:** `.monospacedDigit()` overlays the relevant semantic style for weights, repetitions, clocks, counts, and history values; it is tabular SF, not a separate monospace font.
- **Large Title and controls:** native navigation and SF Symbol display moments retain their system styles. Toolbar titles, buttons, and form controls are not assigned a new fixed font.

**The Dynamic Type Rule.** Use semantic SwiftUI text styles and let Dynamic Type change both text and layout instead of freezing a point-size scale.

## Layout

Native `List`, `Form`, `Section`, `TabView`, and `NavigationStack` define the structure. `rookList()` hides the default scroll-content background and applies the canvas and accent; section rows use the surface. Keep system safe areas, list insets, row sizing, and scrolling rather than introducing web containers or breakpoints.

Spacing tokens record actual explicit SwiftUI point measurements, not overrides for platform-default `.padding()` or implicit stack spacing. Section spacing organizes workout summaries and routine content; marker spacing separates per-exercise progress; row spacing organizes compact set rows; detail spacing separates routine/resume labels; tight spacing groups the rest label and clock. Privacy and introduction spacing belong to their corresponding source stacks, not a universal grid.

Explicit workout text-field and completion-control frames provide minimum 44 pt targets; rest and Add set actions also have minimum 44 pt height, and routine menus use minimum 44 pt width and height. Preserve those minima and native controls' own hit areas without treating them as fixed heights.

At accessibility Dynamic Type sizes, workout set rows become labeled vertical groups, previous values remain visible, and the compact column header disappears. `ViewThatFits` moves rest text and actions from a horizontal arrangement to a vertical one when needed. These are content/text-size adaptations, not device-width breakpoints.

## Elevation & Depth

Depth comes from canvas/surface contrast, native list grouping, and system presentations. The supplied sources define no custom shadow, elevation scale, blur, or animated transition. Bars, sheets, full-screen covers, and alerts retain platform geometry and motion; do not infer custom motion tokens from timer updates.

**The Platform Depth Rule.** Let native grouping and presentation establish depth instead of adding custom shadows or web-style glass.

## Shapes

SwiftUI owns button corners, rounded-border text fields, list rows, segmented pickers, steppers, menus, and alerts. There is no app-defined radius scale. Completion uses SF Symbols `circle` and `checkmark`; per-exercise completion uses native linear `ProgressView`. Keep these recognizable native forms rather than replacing them with decorative rings or bespoke control silhouettes.

## Components

### Primary button

`rookPrimary()` combines `.borderedProminent`, adaptive accent tint, and matching on-accent foreground. It appears on Create a routine, Start workout, and startup Try again. Start workout expands its label across the available row and is disabled while a workout is already active. Preserve native pressed, disabled, focus, and accessibility behavior; no app hover grammar exists.

### Bordered action

`.buttonStyle(.bordered)` carries secondary actions such as Add an example routine, Restore a backup, +30 sec, and Skip. Global/list tint supplies the adaptive accent; SwiftUI supplies the border, fill, radius, and state treatment. Do not derive a new background or border-color token from that system treatment.

### Numeric field

Workout weight/repetition fields use `.roundedBorder`, centered body text with tabular digits, decimal/number keyboards, and explicit contextual accessibility labels. The native keyboard toolbar provides Done. Previous values come only from matching completed stored sets; absence displays an em dash. Accessibility rows expose weight units and repetition labels separately. Routine-editor numeric fields instead retain trailing-aligned native Form presentation.

### Native navigation and forms

Four native tabs—Routines, History, Progress, Settings—each contain a `NavigationStack` and SF Symbol tab item. The workout opens in a full-screen cover with an inline Workout title and Close/Finish toolbar actions; Close leaves it resumable. Routine editing and backup restore use sheets; detail and backup pages use inline titles. Keep system back/navigation gestures, native presentation motion, and existing dismissal guards, rather than introducing custom navigation chrome.

`RoutineEditor.swift` and `BackupsSettings.swift` retain native text/secure fields, steppers, pickers, toggles, file dialogs, and confirmation alerts. Busy state disables relevant controls. Destructive delete/discard/restore actions keep explicit native confirmation and truthful consequences.

### Route progress and completion

The active-workout summary shows elapsed time, completed/total sets, and one native progress indicator per exercise, with exercise/count accessibility labels. A set's incomplete button uses track tint and system primary foreground; completion switches to accent/on-accent and a checkmark. Labels and accessibility values identify the state without relying on color alone. Completion commits the set and starts rest; the rest block offers +30 sec and Skip.

The inline active-workout chart is deferred. Separate Progress remains a native Swift Charts view with a native exercise picker, segmented measure picker, accent-colored line/circle marks for top weight or bars for repetitions, and recorded-value rows. History, empty states, and charts use stored completed work, not fabricated history.

### Source authority and evidence

- `apple/Rook/Theme.swift`: adaptive role definitions; list, prominent-action, privacy-cover, and alert-host modifiers.
- `apple/Rook/WorkoutView.swift`: workout hierarchy, explicit secondary footer, accessibility reflow, rest controls, numeric fields, progress and completion states.
- `apple/Rook/RookApp.swift`: application tint, native tab/stack/presentation hierarchy, routine and empty-state patterns.
- `apple/Rook/RoutineEditor.swift`: native routine form, numeric presentation, steppers, save/error states.
- `apple/Rook/HistoryProgress.swift`: stored-record lists/details, separate native charts, segmented measurement selection, honest empty/error states.
- `apple/Rook/BackupsSettings.swift`: settings form, backup secure fields, native file presentation, busy and destructive confirmation states.

Provided native captures are `.impeccable/review/phone-light.png`, `phone-dark.png`, `phone-large.png`, and `phone-empty.png`, identified as iPhone 16 Pro / iOS 18.2; large is dark accessibility XXXL. This documentation pass did not run the app or inspect/review those captures. The supplied finish verdict `disposition: ship` resolves only the footer contrast fix, reported at light 5.63:1 / dark 9.52:1; it does not establish security, physical-hardware, or VoiceOver verification.

Sidecar HTML/CSS is a panel-only illustrative adapter, not shipped web components, native geometry specifications, or a substitute for simulator evidence. Adapter layout maps source point measurements to CSS pixels for legibility only; browser controls and semantic foregrounds stand in for native controls and dynamic primary text. The native source remains authoritative, including SF Symbols and all system-managed states.

## Do's and Don'ts

### Do:

- Do preserve Route markers, adaptive navy/slate surfaces, amber interaction tint, and explicit completion states.
- Do keep system primary text, SF text styles, Dynamic Type, and native control geometry.
- Do preserve explicit minimum 44 pt workout targets and accessibility-size vertical set rows.
- Do retain the explicit secondary-text role on the active-workout exercise footer.
- Do use stored completed sets for previous values, history, and separate Progress.
- Do keep native navigation, presentation motion, and destructive confirmations.

### Don't:

- Don't introduce a new metaphor, decorative rings, or dense dashboard chrome into the active-workout surface.
- Don't turn system controls into fixed-size web components or invent app radii, shadows, breakpoints, or hover behavior.
- Don't add the deferred inline workout chart or fabricate previous values or workout history.
- Don't treat illustrative panel previews as shipped UI or simulator evidence.
- Don't extend the footer-only ship disposition into security, hardware, or VoiceOver assurance, trademark clearance, or delivered HealthKit/Watch support.
