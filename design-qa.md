# Design QA

## Source Visual Truth

- Moon Tide: `/Users/fanr/.codex/generated_images/01a053ab-8341-7e82-8085-06ede96e3aaf/exec-e9e05f88-24b2-4ad8-b695-db15ed4550fb.png`
- Prism Ledger: `/Users/fanr/.codex/generated_images/01a053ab-8341-7e82-8085-06ede96e3aaf/exec-74c0bf5e-f1e2-4b29-9af1-67045fab19b2.png`

## Implementation Evidence

- Moon Tide: `/tmp/pulse-theme-qa/moon-tide-final.png`
- Moon Tide checked state: `/tmp/pulse-theme-qa/moon-tide-checked-disc-ink-final.png`
- Moon Tide compact checked layout: `/tmp/pulse-theme-qa/moon-tide-checked-compact-nav.png`
- Moon Tide unobstructed photo action: `/tmp/pulse-theme-qa/moon-tide-photo-unobstructed.png`
- Prism Ledger: `/tmp/pulse-theme-qa/prism-ledger-final.png`
- Prism Ledger action color: `/tmp/pulse-theme-qa/prism-ledger-action-color.png`
- Prism Ledger split action: `/tmp/pulse-theme-qa/prism-ledger-action-split.png`
- Prism Ledger flat action with purple circle: `/tmp/pulse-theme-qa/prism-ledger-flat-purple-circle.png`
- Viewport: iPhone 17 Pro simulator, 390 x 844 points, iOS 26.5, Simplified Chinese, pending check-in state.
- Source images: 853 x 1844 pixels, normalized to 390 x 844 points.
- Implementation captures: 1206 x 2622 pixels at simulator density, normalized to 390 x 844 points.
- CSS size: not applicable; this is native SwiftUI.

## Full-view Comparison

- Moon Tide preserves the selected oversized date, right-side weekday, indigo night field, upper moon, water reflection, sweeping tide, circular moon check-in control, translucent note surface, curved week rail, and two-column footer. Native status chrome and live product copy are expected implementation differences.
- Prism Ledger preserves the selected oversized date, modular grid, translucent violet and coral intersections, wide violet check-in control, ruled note surface, aligned week rail, and split footer.

## Focused Region Comparison

- Typography: native rounded and default system faces match the references' hierarchy and optical weight closely; Chinese copy remains readable and does not clip.
- Spacing and layout rhythm: header, hero, action, note, week rail, rhythm status, and persistent navigation remain visible at the target viewport. Moon Tide uses tighter vertical spacing so the circular action does not push the rhythm status below the fold.
- Colors and tokens: Moon Tide uses deep indigo, moon silver, and cyan; Prism Ledger uses cool lilac, ultramarine, and one coral accent. Contrast is maintained for primary content and states.
- Image quality: the Moon Tide background and moon-disc assets are clean raster assets with matching art direction. The moon disc retains alpha without a rectangular matte. Prism Ledger correctly remains code-native geometry.
- Copy and content: all text comes from the existing product String Catalog and real pending-state data. No capability or paid-boundary drift was introduced.
- Checked-state moon typography: the completed time and state use the dedicated moon-surface blue-gray token with multiply blending, preserving readable contrast while allowing crater texture to remain visible through the lettering.
- Interactions and accessibility: theme selection, Today/History navigation, settings access, check-in control semantics, optional note input, and seven-day state remain exposed through the accessibility tree.

## Comparison History

1. P0: the first full-width navigation implementation expanded over the entire screen and visually hid the main content. Fixed by constraining the ledger navigation to its explicit height; post-fix evidence is both final simulator captures.
2. P1: the first Moon Tide implementation replaced the selected moon and tide artwork with abstract SwiftUI bands. Fixed by adding the dedicated background asset and transparent moon-disc action asset. Before evidence: `/tmp/pulse-theme-qa/moon-tide-today.png`; after evidence: `/tmp/pulse-theme-qa/moon-tide-final.png`.
3. P2: the first circular Moon Tide action pushed the rhythm status below the initial viewport. Fixed by tightening Moon Tide-only vertical spacing and reducing the action frame to 208 points; the final Moon Tide capture shows the rhythm status and persistent navigation together.
4. P3: completed-state moon text read as flat black against the lunar texture. Fixed with `PulseMoonDiscInk` and checked-only multiply blending; post-fix evidence is `/tmp/pulse-theme-qa/moon-tide-checked-disc-ink-final.png`.
5. P2: the checked-state photo row and 88-point ledger navigation pushed the seven-day rail and streak status behind the initial viewport. Fixed by moving the photo action onto the moon's lower-right edge, reducing the ledger navigation to 76 points with a 44-point glyph, and tightening checked-only Moon Tide gaps. Post-fix evidence is `/tmp/pulse-theme-qa/moon-tide-checked-compact-nav.png`.
6. P2: the first floating photo placement overlapped the following journal card, whose later draw order covered the button's lower edge. Fixed by raising the photo action 28 points, shifting it slightly inward, and giving the check-in region explicit foreground z-order. Post-fix evidence is `/tmp/pulse-theme-qa/moon-tide-photo-unobstructed.png`.
7. P2: Prism Ledger's flat pure-blue action and near-white target disc felt detached from the theme's layered violet material. Fixed with a deep-indigo-to-prism-violet action gradient, a lavender target disc, and a deep-violet glyph/checkmark. Post-fix evidence is `/tmp/pulse-theme-qa/prism-ledger-action-color.png`.
8. P3: the filled right side still read as a separate opaque control rather than part of the pale prism field. Fixed by ending the filled surface at 74%, making the right 26% transparent, and retaining one unified hit area and outer border. Post-fix evidence is `/tmp/pulse-theme-qa/prism-ledger-action-split.png`.
9. P2: user review rejected both the gradient and transparent split as less coherent than the original. Restored the original flat prism-purple action and limited the change to the circular target: lavender fill, prism-purple ring, and prism-purple glyph/checkmark. Removed the unused gradient-only color asset. Final evidence is `/tmp/pulse-theme-qa/prism-ledger-flat-purple-circle.png`.

## Findings

No actionable P0, P1, or P2 mismatches remain.

## Follow-up Polish

- P3: the generated moon-disc glow is slightly brighter than the concept. This is acceptable at the current size and improves action recognition against the live background.
- P3: mock copy and streak values differ from the simulator because the implementation intentionally shows the real pending state instead of baked sample data.

final result: passed
