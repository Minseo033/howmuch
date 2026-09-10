# Bundled Korean font

`NotoSansKR-Variable.ttf` is Noto Sans KR (weights 100–900), distributed
under the SIL Open Font License in `OFL-NotoSansKR.txt`.

Source: https://github.com/google/fonts/tree/b38c5c93af322c45f633e17ac440ec1e6c94d489/ofl/notosanskr

The original full font is preserved, including all 11,172 modern Hangul
syllables, Korean jamo, Latin, punctuation, and the source font's CJK coverage.
Do not subset it to current screen text: notice titles, store names and user
content arrive dynamically.

Flutter's font manifest loads this asset during engine initialization, before
the first frame. `web/index.html` preloads the same URL and uses the same font
for HTML map labels. CSS font loading alone does not register a font with
Flutter's CanvasKit renderer.
