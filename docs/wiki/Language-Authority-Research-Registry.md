# Language Authority and Terminology Research Registry

**Purpose:** establish a traceable, locale-specific research workflow for the 40 regional ARB catalogs. This registry is a starting inventory, not a claim that every listed institution has approved HWcontrol2.0 wording. Verify availability, scope, current URLs, access conditions, and reuse rights before depending on a source or automating access.

## Research rules

1. **Start from the actual locale**, not just its base language. Regional catalogs must use regional vocabulary and conventions where these differ (notably `en-US`/`en-GB`/`en-CA`, `es-ES`/`es-MX`, `pt-PT`/`pt-BR`, and `zh-CN`/`zh-TW`).
2. **Use a source hierarchy:** (a) laws, standards, government language bodies and official terminology databases; (b) national academies and academic language institutes; (c) recognized specialist dictionaries, standards organizations and technical glossaries; (d) real product UI and established technical usage. Record when a source is not governmental or not prescriptive.
3. **Do not infer authority from a domain name.** If a language has no single official regulator, record that fact and use multiple reputable references. English, for example, has no single worldwide official language academy.
4. **Research meaning in context.** Search terms for hardware monitoring, cooling, temperature, firmware, permissions, diagnostics, updates and cybersecurity. Record definition, grammatical form, regional scope, source URL, access date, licensing/reuse notes, decision and rejected alternatives.
5. **Do not blindly scrape.** Respect each site’s terms, robots/access policy, rate limits, API terms, copyright and database rights. Prefer documented APIs, bulk downloads and open-licensed datasets. Never bypass login, CAPTCHA, access controls or rate limits.
6. **Sources guide translation; they do not replace linguistic review.** An official general dictionary may not contain specialist hardware vocabulary. A term can be common but still misleading in a safety-critical message.
7. **No silent source-of-truth split.** ARB remains the canonical runtime translation catalog. This registry is research metadata only; it must not become a second translation catalog.
8. **No unverified claims.** A translation is not “officially approved” unless the relevant body has explicitly reviewed or approved it. Mark unresolved terms as `needs-review`.
9. **Automated quality gates:** exact key coverage, ICU/placeholder parity, non-empty values, locale-tag validity, bidirectional-text checks, critical-message review, UI overflow and accessibility checks. Passing structural tests is not proof of native-quality language.
10. **Use current official spelling and terminology guidance.** Record the version/date of any rule or standard that influences a decision.

## Cross-locale technical references

- [Unicode CLDR / LDML](https://www.unicode.org/reports/tr35/) — locale identifiers, inheritance, plural categories, date/time and number formatting, collation, units and message-format conventions. Use it for locale behavior, not as the sole authority for prose or technical terminology.
- [Unicode CLDR data](https://github.com/unicode-org/cldr) — locale data and change history; check the applicable release and license.
- [W3C Internationalization](https://www.w3.org/International/) — internationalization and text-direction guidance.
- [RFC 5646 / BCP 47](https://www.rfc-editor.org/rfc/rfc5646) — language tags.
- [Unicode Bidirectional Algorithm, UAX #9](https://www.unicode.org/reports/tr9/) — bidirectional text behavior.
- [UNTERM](https://unterm.un.org/) — UN-system terminology in Arabic, Chinese, English, French, Russian and Spanish; useful for general institutional terminology, not a substitute for consumer hardware terminology.
- [TermAB](https://termab.ab.gov.tr/) — Türkiye Ministry of Foreign Affairs EU Affairs terminology database, including Turkish, English and French.
- [IATE](https://iate.europa.eu/) — EU inter-institutional terminology database; useful for supported EU language pairs and institutional terminology, not a universal language regulator.
- [Microsoft Language Portal](https://www.microsoft.com/en-us/language) — software UI terminology and style references where available; treat as product terminology guidance, not a national language authority.
- [Google developer documentation style guide](https://developers.google.com/style) — technical writing guidance; not a language regulator.

## Locale-by-locale source inventory

“Primary” means the first place to investigate, not an endorsement of every entry or a claim of exclusive authority. For each locale, consult all applicable spelling, dictionary, terminology, grammar, technical and public-sector plain-language resources; log which source supports each term.

| Locale (ARB) | Regional language scope | Primary sources to investigate | Scope / caution |
|---|---|---|---|
| `ar_SA` | Arabic, Saudi Arabia | [King Salman Global Academy for Arabic Language](https://ksaa.gov.sa/); [UNTERM](https://unterm.un.org/) | Check Modern Standard Arabic and Saudi usage; verify the academy’s specific terminology products. |
| `bg_BG` | Bulgarian, Bulgaria | [Institute for Bulgarian Language, Bulgarian Academy of Sciences](https://ibl.bas.bg/) | Normative dictionary, spelling and linguistic resources; verify specialist technical coverage. |
| `bn_BD` | Bengali, Bangladesh | [Bangla Academy](https://banglaacademy.gov.bd/) | Bengali lexicography and usage; verify current spelling/terminology publications. |
| `ca_ES` | Catalan, Spain | [Institut d’Estudis Catalans](https://www.iec.cat/); [DIEC](https://dlc.iec.cat/) | Normative Catalan lexicon and terminology; use Catalan-specific sources rather than Spanish equivalents. |
| `cs_CZ` | Czech, Czechia | [Institute of the Czech Language, Czech Academy of Sciences](https://ujc.cas.cz/) | Czech spelling, dictionary and language advice; supplement with technical sources. |
| `da_DK` | Danish, Denmark | [Danish Language Council](https://dsn.dk/); [Ordnet](https://ordnet.dk/) | Danish spelling and dictionaries; verify technical terms in context. |
| `de_DE` | German, Germany | [Council for German Orthography](https://www.rechtschreibrat.com/); [DWDS](https://www.dwds.de/) | Spelling rules and lexical evidence; distinguish normative spelling from usage corpora. |
| `el_GR` | Greek, Greece | [Centre for the Greek Language](https://www.greek-language.gr/) | Greek dictionaries and language resources; check contemporary technical usage. |
| `en_CA` | English, Canada | [TERMIUM Plus, Government of Canada](https://www.btb.termiumplus.gc.ca/); [Government of Canada Language Portal](https://www.noslangues-ourlanguages.gc.ca/) | Canadian spelling and bilingual terminology; English has no single global regulator. |
| `en_GB` | English, United Kingdom | [GOV.UK style guide](https://www.gov.uk/guidance/style-guide); [Oxford English Dictionary](https://www.oed.com/) | Government writing conventions plus lexicographic evidence; OED is not a government regulator. |
| `en_US` | English, United States | [PlainLanguage.gov](https://www.plainlanguage.gov/); [NIST](https://www.nist.gov/) for technical terminology | Plain-language and specialist standards; no single official US English academy. |
| `es_ES` | Spanish, Spain | [RAE](https://www.rae.es/); [FundéuRAE](https://www.fundeu.es/) | Spanish spelling and usage; check whether recommendations are pan-Hispanic or Spain-specific. |
| `es_MX` | Spanish, Mexico | [RAE / ASALE](https://www.rae.es/); [Academia Mexicana de la Lengua](https://www.academia.org.mx/) | Review Mexican vocabulary and usage; do not copy Spain-only terms automatically. |
| `fi_FI` | Finnish, Finland | [Institute for the Languages of Finland (Kotus)](https://kotus.fi/) | Finnish language recommendations, dictionaries and terminology. |
| `fil_PH` | Filipino, Philippines | [Komisyon sa Wikang Filipino](https://kwf.gov.ph/) | Filipino language policy and vocabulary; verify whether a technical term is natural and current. |
| `fr_FR` | French, France | [FranceTerme](https://www.culture.fr/franceterme); [Académie française](https://www.academie-francaise.fr/) | Government terminology and dictionary resources; distinguish official terminology recommendations from general usage. |
| `he_IL` | Hebrew, Israel | [Academy of the Hebrew Language](https://hebrew-academy.org.il/) | Hebrew spelling, grammar and terminology; check current technical coinages. |
| `hi_IN` | Hindi, India | [Commission for Scientific and Technical Terminology](https://cstt.education.gov.in/); [SHABD terminology portal](https://www.shabd.education.gov.in/) | Government scientific/technical terminology; verify actual UI readability and regional register. |
| `hr_HR` | Croatian, Croatia | [Institute of Croatian Language](https://ihjj.hr/) | Croatian dictionaries, orthography and terminology; distinguish Croatian forms from closely related standards. |
| `hu_HU` | Hungarian, Hungary | [Hungarian Research Centre for Linguistics](https://nytud.hu/); [Hungarian electronic dictionaries](https://szotar.net/) | Hungarian linguistic and lexicographic resources; verify whether each source is normative or descriptive. |
| `id_ID` | Indonesian, Indonesia | [Badan Pengembangan dan Pembinaan Bahasa](https://badanbahasa.kemendikdasmen.go.id/); [KBBI](https://kbbi.kemdikbud.go.id/) | Indonesian dictionary and language guidance; verify the current agency domain and dictionary access. |
| `it_IT` | Italian, Italy | [Accademia della Crusca](https://accademiadellacrusca.it/); [Treccani](https://www.treccani.it/) | Italian usage, dictionary and language advice; specialist computing terminology may need additional sources. |
| `ja_JP` | Japanese, Japan | [Agency for Cultural Affairs](https://www.bunka.go.jp/); [National Institute for Japanese Language and Linguistics](https://www.ninjal.ac.jp/) | Government language policy, writing conventions and linguistic research; validate UI conventions and terminology. |
| `ko_KR` | Korean, South Korea | [National Institute of Korean Language](https://www.korean.go.kr/); [Standard Korean Dictionary](https://stdict.korean.go.kr/) | Official Korean dictionary, spelling, terminology and public-language resources. |
| `ms_MY` | Malay, Malaysia | [Dewan Bahasa dan Pustaka](https://dbp.gov.my/); [PRPM](https://prpm.dbp.gov.my/) | Malay dictionary and terminology; verify Malaysian standard and contemporary technical wording. |
| `nb_NO` | Norwegian Bokmål, Norway | [Language Council of Norway](https://sprakradet.no/); [Bokmålsordboka](https://ordbokene.no/) | Bokmål spelling and lexicon; do not mix Nynorsk and Bokmål without a deliberate locale decision. |
| `nl_NL` | Dutch, Netherlands | [Dutch Language Union](https://taalunie.org/); [Woordenlijst Nederlandse Taal](https://woordenlijst.org/) | Dutch spelling and terminology; check Netherlands/Belgium regional differences where relevant. |
| `pl_PL` | Polish, Poland | [Polish Language Council](https://rjp.pan.pl/); [PWN Dictionary](https://sjp.pwn.pl/) | Polish orthography, usage and dictionary evidence; confirm current recommendations. |
| `pt_BR` | Portuguese, Brazil | [Academia Brasileira de Letras](https://www.academia.org.br/); [VOLP](https://www.academia.org.br/nossa-lingua/busca-no-vocabulario) | Brazilian spelling and vocabulary; do not treat Portugal usage as interchangeable. |
| `pt_PT` | Portuguese, Portugal | [Academia das Ciências de Lisboa](https://www.acad-ciencias.pt/); [Priberam](https://dicionario.priberam.org/) | Portugal-specific vocabulary and spelling; distinguish institutional from commercial dictionary sources. |
| `ro_RO` | Romanian, Romania | [Romanian Academy](https://acad.ro/); [DEX online](https://dexonline.ro/) | Romanian spelling and lexicon; DEX online is an aggregator, so check the underlying dictionary source. |
| `ru_RU` | Russian, Russia | [Vinogradov Institute of the Russian Language](https://ruslang.ru/); [Gramota.ru](https://gramota.ru/) | Russian language advice and lexicographic resources; distinguish official/academic guidance from reference portals. |
| `sv_SE` | Swedish, Sweden | [Institute for Language and Folklore (ISOF)](https://www.isof.se/); [Svenska Akademiens ordböcker](https://svenska.se/) | Swedish language recommendations and dictionaries; verify contemporary technical usage. |
| `th_TH` | Thai, Thailand | [Office of the Royal Society](https://www.orst.go.th/) | Thai dictionary and terminology resources; confirm current official portal paths and technical vocabulary. |
| `tr_TR` | Turkish, Türkiye | [Turkish Language Association (TDK)](https://tdk.gov.tr/); [Güncel Türkçe Sözlük](https://sozluk.tdk.gov.tr/); [TDK spelling guide](https://yazim.tdk.gov.tr/); [TermAB](https://termab.ab.gov.tr/) | Spelling, established Turkish equivalents and bilingual institutional terminology. Record decisions and alternatives; avoid forced translations that obscure technical meaning. |
| `uk_UA` | Ukrainian, Ukraine | [National Commission on State Language Standards](https://mova.gov.ua/); [Ukrainian Language and Information Fund](https://ulif.mon.gov.ua/) | State-language standards and dictionary resources; verify current government URLs and terminology. |
| `ur_PK` | Urdu, Pakistan | [National Language Promotion Department](https://nlpd.gov.pk/) | Urdu dictionary and terminology resources; confirm script, spelling and current technical usage. |
| `vi_VN` | Vietnamese, Vietnam | [Vietnamese Institute of Linguistics](https://vienngonnguhoc.gov.vn/) | Vietnamese lexicography and linguistic research; supplement with current Vietnamese technical usage. |
| `zh_CN` | Simplified Chinese, mainland China | [Ministry of Education of China](https://www.moe.gov.cn/); [National Language Commission resources](https://www.moe.gov.cn/) | Mainland standards and simplified-character usage; locate specific current terminology standards for each technical term. |
| `zh_TW` | Traditional Chinese, Taiwan | [Ministry of Education Dictionary](https://dict.revised.moe.edu.tw/); [National Academy for Educational Research](https://www.naer.edu.tw/) | Taiwan-specific terminology and Traditional Chinese; do not merely convert Simplified characters mechanically. |

## Term research record template

Create one record per disputed or high-impact term, not one vague source list per language.

| Field | Required content |
|---|---|
| Source key | Stable ARB key, e.g. `fanSpeed` |
| Concept | Meaning in HWcontrol2.0, including what it does not mean |
| Locale | Exact BCP 47 locale |
| Candidate terms | Candidate wording, grammatical form and regional variants |
| Evidence | Direct source URL, source title, quoted minimal definition or relevant excerpt, lookup date |
| Source status | Government / statutory standard / academy / academic / commercial / community |
| Reuse rights | License, terms or manual-review-only status |
| Decision | Selected wording and short rationale |
| Safety impact | Whether ambiguity could affect security, hardware control or recovery |
| Review status | `unreviewed`, `researched`, `native-reviewed`, `approved` |
| Reviewer / date | Reviewer identity or role and date, when available |

## Work plan

1. Extract the actual 235+ canonical source keys and group them by concept rather than translating isolated strings.
2. Prioritize high-risk concepts first: fan-control state, temperature limits, permissions, bridge authentication, security blocks, update verification, diagnostic consent and recovery instructions.
3. For each of the 40 locale catalogs, verify the locale-specific source links above and record broken links, missing official resources, access restrictions and the best replacement source.
4. Build a controlled terminology list with definitions, allowed variants, forbidden/ambiguous variants, grammatical notes, source citations and locale tags.
5. Apply terminology consistently to ARB translations and metadata; do not rewrite unrelated configuration JSON or INI files.
6. Add automated checks for terminology drift and source-registry schema. Automated checks should flag for review rather than blindly replacing natural-language strings.
7. Run Flutter localization generation, analyzer, tests and visual overflow/accessibility checks. Have native or demonstrably proficient reviewers review every locale before claiming linguistic quality.
8. Revisit this registry periodically. Record source last-checked dates and investigate broken URLs rather than silently treating old references as current.

## Current completion status

- Registry created as a research starting point: yes.
- All 40 locale rows represented: yes.
- Every source independently verified for current availability, exact jurisdiction and reuse rights: **not yet**.
- All ARB translations reviewed against sources: **not yet**.
- Native-speaker review completed: **not yet**.
- This document must not be presented as proof that all translations are officially endorsed or production-quality.
