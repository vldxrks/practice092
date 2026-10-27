import 'package:flutter_test/flutter_test.dart';
import 'package:practice092/models.dart';

void main() {
  test('Підрахунок слів у записі', () {
    final now = DateTime(2026, 10, 27);
    final entry = Entry(
      title: 'Навчання',
      content: 'Сьогодні   вивчав Dart',
      mood: 'Спокій',
      createdAt: now,
      updatedAt: now,
    );

    expect(entry.wordCount, 3);
    expect(entry.toMap()['word_count'], 3);
    expect(entry.toMap()['is_favorite'], 0);
  });
}
