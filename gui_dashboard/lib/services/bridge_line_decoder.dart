import 'dart:convert';

/// Decodes a byte stream as UTF-8 before splitting protocol lines.
///
/// Unlike decoding each socket chunk independently, [utf8.decoder] preserves
/// partial multibyte sequences across chunk boundaries.
Stream<String> decodeUtf8Lines(Stream<List<int>> chunks) =>
    chunks.transform(utf8.decoder).transform(const LineSplitter());
