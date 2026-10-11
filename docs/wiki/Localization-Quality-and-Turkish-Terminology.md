# Localization Quality and Turkish Terminology

## Policy

HWcontrol2.0 uses BCP 47 locale identifiers and keeps the English (US) catalog as the source-key reference. Locale tags follow Unicode CLDR/LDML conventions. A locale is not considered fully translated merely because a language option appears in the selector: every source key must exist, text must be reviewed for meaning and context, and the UI must be checked for truncation and accessibility.

## Turkish (Türkiye) editorial standard

The Turkish interface should use clear, natural Türkiye Turkish and established Turkish computing terms where they fit. Prefer understandable Turkish equivalents over unnecessary English wording, but do not invent awkward replacements for recognized terms, hardware standards, file formats, product names, or protocol identifiers. Keep names such as HWcontrol2.0, Piper, and ONNX intact where they identify a product or technical format.

Initial terminology decisions:
- Dashboard → **Ana ekran**
- Telemetry history → **Ölçüm geçmişi**
- RAM usage → **Bellek kullanımı**
- GPU usage → **Ekran kartı kullanımı**
- Fan / fan speed → **Soğutucu pervanesi / Soğutucu pervanesi hızı**
- Game mode → **Oyun kipi**
- Control flow → **Denetim akışı**
- Advanced telemetry → **Gelişmiş ölçümler**
- Save profile → **Ayar takımını kaydet**
- Test speech / read dashboard → **Sesli okumayı dene / Ana ekran özetini sesli oku**

These are product terminology choices, not a claim that every word of foreign origin has been removed from Turkish. User comprehension and technical accuracy take precedence over forced word substitution. Review terminology consistently across visible UI, accessibility announcements, help text, and documentation.

## Current source-catalog coverage

The source catalog currently contains 85 keys. `en-US`, `en-GB`, `tr-TR`, `ja-JP`, `de-DE`, `fr-FR`, `it-IT`, `es-ES`, and `pt-BR` now have matching key sets. The other listed locales remain partial: their missing entries may fall back to English. Do not advertise those locales as fully translated until their coverage and wording have been reviewed.

## Required review workflow

1. Use the Turkish Language Association's Current Turkish Dictionary and Foreign Words Equivalents Guide for Turkish terminology research; record a rationale for terms that have competing alternatives.
2. Use Unicode CLDR/LDML and BCP 47 conventions for locale identifiers and regional variants.
3. Translate in context, preserving placeholders, units, punctuation, product names, and technical identifiers.
4. Validate exact key parity, non-empty strings, placeholder parity, duplicate locale codes, RTL direction, and fallback behavior.
5. Run localization unit tests, Flutter analysis/tests, and visual checks for every completed locale.
6. Add new locales only with a complete, reviewed translation set; do not increase the advertised language count with English placeholders.

## Reference sources

- [TDK — Yabancı Sözlere Karşılıklar Kılavuzu](https://tdk.gov.tr/icerik/diger-icerikler/yabanc-soezlere-karlklar-klavuzu/)
- [TDK — Güncel Türkçe Sözlük](https://sozluk.tdk.gov.tr/)
- [Unicode CLDR/LDML specification](https://www.unicode.org/reports/tr35/)
- [Flutter internationalization guide](https://docs.flutter.dev/ui/internationalization/)
