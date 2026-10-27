import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'models.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final instance = DatabaseHelper._();
  Future<Database>? _opening;
  Future<Database> get database => _opening ??= _open();
  Future<Database> _open() async {
    try {
      return await openDatabase(join(await getDatabasesPath(), 'journal.db'),
          version: 1,
          onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
          onCreate: (db, version) async {
            await db.execute(
                'CREATE TABLE journal_entries(id INTEGER PRIMARY KEY AUTOINCREMENT,title TEXT NOT NULL,content TEXT NOT NULL,mood TEXT NOT NULL,created_at TEXT NOT NULL,updated_at TEXT NOT NULL,is_favorite INTEGER NOT NULL DEFAULT 0,word_count INTEGER NOT NULL)');
            await db.execute(
                'CREATE TABLE tags(id INTEGER PRIMARY KEY AUTOINCREMENT,name TEXT NOT NULL UNIQUE,color TEXT NOT NULL,created_at TEXT NOT NULL)');
            await db.execute(
                'CREATE TABLE entry_tags(entry_id INTEGER NOT NULL REFERENCES journal_entries(id) ON DELETE CASCADE,tag_id INTEGER NOT NULL REFERENCES tags(id) ON DELETE CASCADE,PRIMARY KEY(entry_id,tag_id))');
            await db.execute(
                'CREATE INDEX idx_entries_created ON journal_entries(created_at)');
            await db.execute(
                'CREATE INDEX idx_entries_mood ON journal_entries(mood)');
            await db.execute('CREATE INDEX idx_tags_name ON tags(name)');
            await db.execute(
                'CREATE INDEX idx_entry_tags_tag ON entry_tags(tag_id)');
          });
    } catch (_) {
      _opening = null;
      rethrow;
    }
  }

  Future<void> saveEntry(Entry entry) async {
    final db = await database;
    await db.transaction((txn) async {
      final id = entry.id ?? await txn.insert('journal_entries', entry.toMap());
      if (entry.id != null) {
        await txn.update('journal_entries', entry.toMap(),
            where: 'id=?', whereArgs: [id]);
      }
      await txn.delete('entry_tags', where: 'entry_id=?', whereArgs: [id]);
      for (final tag in entry.tags) {
        await txn.insert('entry_tags', {'entry_id': id, 'tag_id': tag.id});
      }
    });
  }

  Future<void> deleteEntry(int id) async {
    await (await database)
        .delete('journal_entries', where: 'id=?', whereArgs: [id]);
  }

  Future<void> favorite(Entry e) async {
    await (await database).update(
        'journal_entries',
        {
          'is_favorite': e.isFavorite ? 0 : 1,
          'updated_at': DateTime.now().toUtc().toIso8601String()
        },
        where: 'id=?',
        whereArgs: [e.id]);
  }

  Future<List<Entry>> entries(
      {String search = '', String? mood, int? tagId}) async {
    final db = await database;
    final rows = await db.rawQuery('''SELECT DISTINCT e.* FROM journal_entries e
      LEFT JOIN entry_tags et ON et.entry_id=e.id
      WHERE (e.title LIKE ? OR e.content LIKE ?)
      AND (? IS NULL OR e.mood=?) AND (? IS NULL OR et.tag_id=?)
      ORDER BY e.created_at DESC, e.id DESC''',
        ['%$search%', '%$search%', mood, mood, tagId, tagId]);
    final links = await db.rawQuery(
        'SELECT et.entry_id,t.* FROM entry_tags et INNER JOIN tags t ON t.id=et.tag_id');
    final grouped = <int, List<Tag>>{};
    for (final row in links) {
      grouped
          .putIfAbsent(row['entry_id'] as int, () => [])
          .add(Tag.fromMap(row));
    }
    return rows
        .map((m) => Entry.fromMap(m, tags: grouped[m['id']] ?? []))
        .toList();
  }

  Future<List<Tag>> tags() async =>
      (await (await database).query('tags', orderBy: 'name'))
          .map(Tag.fromMap)
          .toList();
  Future<void> saveTag(Tag t) async {
    final db = await database;
    if (t.id == null) {
      await db.insert('tags', t.toMap());
    } else {
      await db.update('tags', t.toMap(), where: 'id=?', whereArgs: [t.id]);
    }
  }

  Future<void> deleteTag(int id) async {
    await (await database).delete('tags', where: 'id=?', whereArgs: [id]);
  }

  Future<Map<String, Object>> statistics() async {
    final db = await database;
    return {
      'moods': await db.rawQuery(
          'SELECT mood,COUNT(*) AS count FROM journal_entries GROUP BY mood'),
      'months': await db.rawQuery(
          "SELECT substr(created_at,1,7) AS month,COUNT(*) AS count FROM journal_entries GROUP BY month ORDER BY month"),
      'tags': await db.rawQuery(
          'SELECT t.id,t.name,COUNT(et.entry_id) AS count FROM tags t LEFT JOIN entry_tags et ON et.tag_id=t.id GROUP BY t.id ORDER BY count DESC,t.name'),
    };
  }
}
