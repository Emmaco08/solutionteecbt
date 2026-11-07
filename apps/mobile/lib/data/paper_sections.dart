import 'dart:convert';

/// One part of a JAMB paper (e.g. "Antonyms") with the instruction shown above it.
/// [start] is the index of its first question in the whole attempt's question list.
class PaperSection {
  const PaperSection({required this.subjectId, required this.key, required this.label, required this.instruction, required this.start, required this.count});

  final int subjectId;
  final String key, label, instruction;
  final int start, count;

  int get end => start + count; // exclusive

  /// Leftover questions ("more") have no instruction and no header.
  bool get hasInstruction => key != 'more' && instruction.trim().isNotEmpty;

  Map<String, dynamic> toJson() => {'key': key, 'label': label, 'instruction': instruction, 'start': start, 'count': count};
}

/// The sections of an attempt, read from its config JSON (`"sections": {"<subjectId>": [...]}`).
class PaperSections {
  PaperSections(this.all);
  const PaperSections.empty() : all = const [];

  final List<PaperSection> all;

  bool get isEmpty => all.isEmpty;

  factory PaperSections.fromConfig(Map<String, dynamic> config) {
    final raw = config['sections'];
    if (raw is! Map) return const PaperSections.empty();
    final out = <PaperSection>[];
    for (final e in raw.entries) {
      final sid = int.tryParse('${e.key}');
      if (sid == null || e.value is! List) continue;
      for (final s in e.value as List) {
        if (s is! Map) continue;
        out.add(
          PaperSection(
            subjectId: sid,
            key: '${s['key'] ?? ''}',
            label: '${s['label'] ?? ''}',
            instruction: '${s['instruction'] ?? ''}',
            start: (s['start'] as num?)?.toInt() ?? 0,
            count: (s['count'] as num?)?.toInt() ?? 0,
          ),
        );
      }
    }
    out.sort((a, b) => a.start.compareTo(b.start));
    return PaperSections(out);
  }

  factory PaperSections.fromConfigJson(String json) {
    try {
      return PaperSections.fromConfig(jsonDecode(json) as Map<String, dynamic>);
    } catch (_) {
      return const PaperSections.empty();
    }
  }

  /// The section that holds question [index], or null.
  PaperSection? at(int index) {
    for (final s in all) {
      if (index >= s.start && index < s.end) return s;
    }
    return null;
  }

  /// Sections of one subject that have a header (excludes "more").
  List<PaperSection> forSubject(int subjectId) => [
    for (final s in all)
      if (s.subjectId == subjectId && s.hasInstruction) s,
  ];

  /// "Section 5 of 8" for [s].
  String position(PaperSection s) {
    final list = forSubject(s.subjectId);
    return 'Section ${list.indexOf(s) + 1} of ${list.length}';
  }
}
