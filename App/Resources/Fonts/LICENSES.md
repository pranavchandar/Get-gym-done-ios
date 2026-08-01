# Bundled fonts

Both faces are SIL Open Font License 1.1, which permits bundling and redistribution.

- **Anton** — copied verbatim from `get-gym-done-web/src/assets/fonts/anton_regular.ttf`,
  the same file the web app serves, so glyph metrics are identical across the two apps.
- **Inter** (Regular/Medium/SemiBold/Bold, Latin subset) — decompressed from the WOFF2
  files shipped by `@fontsource/inter`, the package the web app uses. WOFF2 wraps an
  unmodified TrueType SFNT, so these are byte-equivalent outlines to what the browser
  renders.

PostScript names, which is what `Font.custom(_:)` matches on:
`Anton-Regular`, `Inter-Regular`, `Inter-Medium`, `Inter-SemiBold`, `Inter-Bold`.
