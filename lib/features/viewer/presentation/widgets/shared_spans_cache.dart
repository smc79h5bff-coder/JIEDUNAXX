import 'dart:collection';
import 'package:flutter/material.dart';

/// 查找高亮 spans 的共享 LRU 缓存。
/// 4 个视图（merged / side_by_side / diff_only / diff_only_plain）共用这一份，
/// 避免同一份文本在 4 处各算各存、各 fill 各 clear。
/// 容量放大到 2048（原来是每个视图 512 × 4），LRU 单条淘汰代替 bulk clear。
const int sharedSpansCacheCap = 2048;

final LinkedHashMap<String, List<InlineSpan>> sharedSpansCache =
    LinkedHashMap<String, List<InlineSpan>>();

List<InlineSpan> cachedSpans(
  String text,
  String findQuery,
  bool isCurrentMatch,
  Color matchYellow,
  Color matchPink,
) {
  final key = '$text\u0000$findQuery\u0000${isCurrentMatch ? 1 : 0}';
  final hit = sharedSpansCache[key];
  if (hit != null) return hit;

  final spans =
      buildSpans(text, findQuery, isCurrentMatch, matchYellow, matchPink);
  if (sharedSpansCache.length >= sharedSpansCacheCap) {
    sharedSpansCache.remove(sharedSpansCache.keys.first);
  }
  sharedSpansCache[key] = spans;
  return spans;
}

List<InlineSpan> buildSpans(
  String text,
  String findQuery,
  bool isCurrentMatch,
  Color matchYellow,
  Color matchPink,
) {
  final q = findQuery;
  if (q.isEmpty || text.isEmpty) {
    return <InlineSpan>[TextSpan(text: text.isEmpty ? ' ' : text)];
  }
  final bg = isCurrentMatch ? matchPink : matchYellow;
  final spans = <InlineSpan>[];
  var start = 0;
  int idx;
  while ((idx = text.indexOf(q, start)) != -1) {
    if (idx > start) spans.add(TextSpan(text: text.substring(start, idx)));
    spans.add(TextSpan(
      text: q,
      style: TextStyle(backgroundColor: bg, fontWeight: FontWeight.bold),
    ));
    start = idx + q.length;
  }
  if (start < text.length) spans.add(TextSpan(text: text.substring(start)));
  return spans.isEmpty ? <InlineSpan>[TextSpan(text: ' ')] : spans;
}
