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

The English (US) ARB template currently contains 233 message keys across 40 locale catalogs. Automated checks verify locale identifiers, required-key coverage, ICU placeholder parity, metadata consistency, the generated compatibility adapter, and the absence of runtime references to the removed JSON localization asset. Thirteen newer security/update status messages are currently supplied in English and Turkish; other locales use the English template fallback for those messages. The ICU plural messages for anomaly counts and benchmark iterations are present in all 40 catalogs. This is structural validation, not proof of native-quality translation: every locale still needs contextual linguistic review, regional terminology review, and UI layout/accessibility checks. Do not describe all 40 as professionally reviewed or fully quality-assured until those steps are completed.

## Required review workflow

1. For Turkish (Türkiye), consult TDK's Güncel Türkçe Sözlük, Yazım Kılavuzu, and Yabancı Sözlere Karşılıklar Kılavuzu. Record why a term was selected when alternatives compete.
2. For each other locale, prefer the relevant official language institution, national terminology database, statutory spelling council, or recognized academic normative dictionary. Confirm that the source applies to the actual regional locale (for example, es-MX vs es-ES and pt-PT vs pt-BR). Not every language has a single government-mandated authority; do not label a private dictionary as an official government source.
3. Use Unicode CLDR/LDML and BCP 47 conventions for locale identifiers, regional variants, plural rules, number/date formats, and text direction.
4. Translate in context, preserving placeholders, units, punctuation, product names, and technical identifiers. Hardware terms should be understandable to ordinary users but remain technically precise.
5. Validate exact key parity, non-empty strings, placeholder parity, duplicate locale codes, RTL direction, fallback behavior, and suspicious untranslated English strings. An identical string is acceptable for a product name, standard, protocol, or common technical acronym; it should be reviewed rather than automatically rejected.
6. Run localization unit tests, Flutter analysis/tests, and visual checks for truncation and accessibility for every completed locale.
7. Add new locales only with a complete translation set; do not increase the advertised language count with English placeholders.

## Language-authority research register

Use these as primary starting points, not as an automated substitute for a native-language review. Record the date and the term checked when adopting a terminology decision.

| Locale / language | Preferred reference | Scope |
| --- | --- | --- |
| tr-TR — Turkish (Türkiye) | [TDK Current Turkish Dictionary](https://sozluk.tdk.gov.tr/), [TDK spelling guide](https://yazim.tdk.gov.tr/), [Foreign Words Equivalents Guide](https://tdk.gov.tr/icerik/diger-icerikler/yabanc-soezlere-karlklar-klavuzu/) | Spelling, established words, Turkish equivalents |
| es-ES / es-MX — Spanish | [RAE / ASALE Dictionary of Doubts](https://www.rae.es/dpd/) | Shared Spanish guidance; check regional usage rather than assuming Spain-only wording |
| fr-FR — French | [FranceTerme / French terminology resources](https://www.culture.fr/franceterme), [Académie française dictionary and terminology resources](https://www.academie-francaise.fr/la-langue-francaise/terminologie) | French technical terminology and normative usage |
| de-DE — German | [Council for German Orthography](https://www.rechtschreibrat.com/) and its current official rules | Standard spelling and punctuation |
| ja-JP — Japanese | [Agency for Cultural Affairs: Japanese language policy](https://www.bunka.go.jp/english/policy/japanese_language/) | Government language policy and writing references |
| ca-ES — Catalan | [Institut d'Estudis Catalans — DIEC](https://dlc.iec.cat/) | Normative Catalan lexicon |
| pt-PT — Portuguese (Portugal) | [Academia das Ciências de Lisboa — VOLP](https://vocabulario.acad-ciencias.pt/) | Portuguese spelling and lexical forms for the Portugal variety |
| pt-BR — Portuguese (Brazil) | Check Brazilian official/academic lexicographic resources and the applicable orthographic agreement; do not copy Portugal-specific vocabulary blindly | Brazilian regional usage |
| bn-BD — Bengali (Bangladesh) | [Bangla Academy](https://banglaacademy.gov.bd/) | Bengali dictionaries and editorial references |
| zh-CN / zh-TW — Chinese | Consult the relevant mainland Chinese or Taiwan language-standardization/dictionary source separately; do not treat Simplified and Traditional Chinese as merely different fonts | Regional vocabulary, characters, and terminology |
| Other locales | Identify a recognized language authority or national/academic terminology source for the specific locale before final review | Authority varies by language and country |

The authority/source mapping is deliberately regional. For example, RAE/ASALE guidance supports shared Spanish norms but does not remove the need to review Mexican wording; likewise, the Portuguese authority listed for pt-PT must not be treated as the sole authority for pt-BR.

## Reference sources

- [TDK — Yabancı Sözlere Karşılıklar Kılavuzu](https://tdk.gov.tr/icerik/diger-icerikler/yabanc-soezlere-karlklar-klavuzu/)
- [TDK — Güncel Türkçe Sözlük](https://sozluk.tdk.gov.tr/)
- [TDK — Yazım Kılavuzu](https://yazim.tdk.gov.tr/)
- [RAE / ASALE — Diccionario panhispánico de dudas](https://www.rae.es/dpd/)
- [Académie française — Terminologie](https://www.academie-francaise.fr/la-langue-francaise/terminologie)
- [German Orthography Council](https://www.rechtschreibrat.com/)
- [Japan Agency for Cultural Affairs — Japanese language policy](https://www.bunka.go.jp/english/policy/japanese_language/)
- [Institut d'Estudis Catalans — DIEC](https://dlc.iec.cat/)
- [Academia das Ciências de Lisboa — VOLP](https://vocabulario.acad-ciencias.pt/)
- [Bangla Academy](https://banglaacademy.gov.bd/)
- [Unicode CLDR/LDML specification](https://www.unicode.org/reports/tr35/)
- [Flutter internationalization guide](https://docs.flutter.dev/ui/internationalization/)


## Localization format decision: ARB + Flutter gen-l10n

ARB is now the canonical source for user-visible UI messages. The former `assets/localization/language.json` runtime catalog has been removed; application and installer localization must not load, search for, or silently recreate it. Flutter's `gen-l10n` generates typed `AppLocalizations` accessors from `lib/l10n/app_*.arb`, and `l10n.yaml` defines the source template and generated class.

Use ICU message syntax when grammar depends on a value, especially plural counts and selection. Use declared typed placeholders for paths, errors, versions, platform names, percentages, and other interpolated values. Avoid manually replacing `{placeholder}` strings in application code when a generated accessor is available. The `app_localizations_map.dart` adapter is a compatibility boundary for older key-based widgets, not a second translation catalog: it reads only Flutter-generated ARB accessors. The dashboard now materializes only the selected locale's compatibility map instead of keeping all 40 maps in memory. Tests verify every key-based call is mapped and that parameterized messages use generated typed accessors. New or changed parameterized messages should use generated typed accessors.

The ARB migration does **not** mean every JSON or INI file should become ARB. Settings, fan curves, profiles, telemetry, model metadata, update manifests, and security manifests are structured data, not translated messages. Keep their existing schemas and compatibility/migration code unless a separate data-format migration is designed and validated. In particular, do not remove legacy configuration migration merely because it mentions INI.

## Migration and validation rules

- Keep all 40 regional locale catalogs and preserve BCP 47 identifiers.
- Validate ICU syntax by running `flutter gen-l10n` in CI, then run `flutter analyze` and `flutter test`.
- Test key coverage, placeholder metadata and parity, ICU plural coverage, locale naming, adapter parity, RTL behavior, and the absence of references to the removed localization JSON asset.
- Treat English template fallback as a temporary translation gap, not as a completed translation. New security/update messages must be reviewed and translated for each locale before claiming full coverage.
- Do not maintain JSON and ARB as parallel localization sources of truth.
- Review locale changes visually for truncation, accessibility, and RTL layout before release.
