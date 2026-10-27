import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'models.dart';
import 'entry_form.dart';

const moods = ['Радість', 'Спокій', 'Сум', 'Стрес'];
const moodIcons = ['😊', '🙂', '😔', '😟'];
const moodColors = [Colors.amber, Colors.green, Colors.blue, Colors.red];
String day(DateTime t) =>
    '${t.toLocal().year}-${t.toLocal().month.toString().padLeft(2, '0')}-${t.toLocal().day.toString().padLeft(2, '0')}';
void main() => runApp(const MaterialApp(
    debugShowCheckedModeBanner: false, home: JournalScreen()));

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});
  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  final _db = DatabaseHelper.instance;
  List<Entry> _entries = [], _all = [];
  List<Tag> _tags = [];
  Map<String, Object> _stats = {};
  String _search = '';
  String? _mood;
  int? _tag;
  int _tab = 0, _request = 0;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void error(Object e) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Помилка: $e')));
    }
  }

  Future<void> _reload() async {
    final request = ++_request;
    try {
      final entries =
          await _db.entries(search: _search, mood: _mood, tagId: _tag);
      final all = await _db.entries();
      final tags = await _db.tags();
      final stats = await _db.statistics();
      if (mounted && request == _request) {
        setState(() {
          _entries = entries;
          _all = all;
          _tags = tags;
          _stats = stats;
        });
      }
    } catch (e) {
      error(e);
    }
  }

  Future<void> _act(Future<void> Function() action) async {
    try {
      await action();
      await _reload();
    } catch (e) {
      error(e);
    }
  }

  Future<void> _edit([Entry? entry]) async {
    await Navigator.of(context).push<void>(MaterialPageRoute(
        builder: (_) => EntryForm(entry: entry, tags: _tags)));
    await _reload();
  }

  Future<void> _tagDialog([Tag? tag]) async {
    final result = await Navigator.of(context)
        .push<Tag>(MaterialPageRoute(builder: (_) => TagForm(tag: tag)));
    if (result != null) await _act(() => _db.saveTag(result));
  }

  int get _streak {
    final dates = _all.map((e) => day(e.createdAt)).toSet();
    var cursor = DateTime.now();
    if (!dates.contains(day(cursor))) {
      cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
    }
    var count = 0;
    while (dates.contains(day(cursor))) {
      count++;
      cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
    }
    return count;
  }

  Widget _timeline() => Column(children: [
        Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
                decoration:
                    const InputDecoration(labelText: 'Пошук у назві та тексті'),
                onChanged: (v) {
                  _search = v;
                  _reload();
                })),
        SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              ChoiceChip(
                  label: const Text('Усі настрої'),
                  selected: _mood == null,
                  onSelected: (_) {
                    _mood = null;
                    _reload();
                  }),
              for (final m in moods)
                Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: ChoiceChip(
                        label: Text(m),
                        selected: _mood == m,
                        onSelected: (v) {
                          _mood = v ? m : null;
                          _reload();
                        })),
            ])),
        DropdownButton<int>(
            hint: const Text('Усі теги'),
            value: _tag,
            items: [
              const DropdownMenuItem<int>(value: null, child: Text('Усі теги')),
              for (final t in _tags)
                DropdownMenuItem(value: t.id, child: Text(t.name))
            ],
            onChanged: (v) {
              _tag = v;
              _reload();
            }),
        Expanded(
            child: _entries.isEmpty
                ? const Center(child: Text('Записів не знайдено'))
                : ListView.builder(
                    itemCount: _entries.length,
                    itemBuilder: (context, i) {
                      final e = _entries[i];
                      final header = i == 0 ||
                          day(_entries[i - 1].createdAt) != day(e.createdAt);
                      return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (header)
                              Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Text(day(e.createdAt),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium)),
                            ListTile(
                                onTap: () => _edit(e),
                                leading: Text(moodIcons[moods.indexOf(e.mood)]),
                                title: Text(e.title),
                                subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(e.content,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis),
                                      Text('Слів: ${e.wordCount}'),
                                      Wrap(spacing: 4, children: [
                                        for (final t in e.tags)
                                          Chip(
                                              label: Text(t.name),
                                              backgroundColor: Color(int.parse(
                                                  'FF${t.color}',
                                                  radix: 16)))
                                      ])
                                    ]),
                                trailing: IconButton(
                                    onPressed: () =>
                                        _act(() => _db.favorite(e)),
                                    icon: Icon(e.isFavorite
                                        ? Icons.favorite
                                        : Icons.favorite_border))),
                          ]);
                    })),
      ]);
  Widget _calendar() {
    final first = DateTime(_month.year, _month.month, 1),
        days = DateTime(_month.year, _month.month + 1, 0).day;
    final offset = first.weekday - 1;
    return ListView(padding: const EdgeInsets.all(12), children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        IconButton(
            onPressed: () => setState(
                () => _month = DateTime(_month.year, _month.month - 1)),
            icon: const Icon(Icons.chevron_left)),
        Text('${_month.year}-${_month.month.toString().padLeft(2, '0')}'),
        IconButton(
            onPressed: () => setState(
                () => _month = DateTime(_month.year, _month.month + 1)),
            icon: const Icon(Icons.chevron_right))
      ]),
      const Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        Text('Пн'),
        Text('Вт'),
        Text('Ср'),
        Text('Чт'),
        Text('Пт'),
        Text('Сб'),
        Text('Нд')
      ]),
      GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7),
          itemCount: offset + days,
          itemBuilder: (context, i) {
            if (i < offset) return const SizedBox.shrink();
            final date = DateTime(_month.year, _month.month, i - offset + 1);
            final es =
                _all.where((e) => day(e.createdAt) == day(date)).toList();
            return InkWell(
                onTap: es.isEmpty
                    ? null
                    : () => showDialog<void>(
                        context: context,
                        builder: (context) => AlertDialog(
                            title: Text(day(date)),
                            content: SingleChildScrollView(
                                child: Text(es
                                    .map((e) => '${e.title}: ${e.mood}')
                                    .join('\n'))))),
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('${date.day}'),
                      Wrap(spacing: 2, children: [
                        for (final mood in es.map((e) => e.mood).toSet())
                          Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: moodColors[moods.indexOf(mood)]))
                      ])
                    ]));
          }),
      for (var i = 0; i < moods.length; i++)
        ListTile(
            leading: Icon(Icons.circle, color: moodColors[i]),
            title: Text(moods[i])),
    ]);
  }

  List<Map<String, Object?>> _rows(String key) =>
      (_stats[key] as List?)
          ?.map((v) => Map<String, Object?>.from(v as Map))
          .toList() ??
      [];
  Widget _statistics() =>
      ListView(padding: const EdgeInsets.all(16), children: [
        Text('Усього записів: ${_all.length}',
            style: Theme.of(context).textTheme.titleLarge),
        Text('Серія днів із записами: $_streak'),
        const SizedBox(height: 16),
        const Text('Розподіл настрою'),
        for (final r in _rows('moods'))
          ListTile(
              title: Text('${r['mood']}'), trailing: Text('${r['count']}')),
        const Text('Записи за місяцями за UTC'),
        for (final r in _rows('months'))
          ListTile(
              title: Text('${r['month']}'), trailing: Text('${r['count']}')),
        const Text('Найуживаніші теги'),
        for (final r in _rows('tags'))
          ListTile(
              title: Text('${r['name']}'), trailing: Text('${r['count']}')),
      ]);
  Widget _tagList() => ListView(children: [
        for (final t in _tags)
          ListTile(
              onTap: () => _tagDialog(t),
              leading: Icon(Icons.label,
                  color: Color(int.parse('FF${t.color}', radix: 16))),
              title: Text(t.name),
              subtitle: Text(
                  'Використань: ${_rows('tags').where((r) => r['id'] == t.id).map((r) => r['count']).firstOrNull ?? 0}'),
              trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () {
                    if (_tag == t.id) _tag = null;
                    _act(() => _db.deleteTag(t.id!));
                  })),
        TextButton.icon(
            onPressed: () => _tagDialog(),
            icon: const Icon(Icons.add),
            label: const Text('Додати тег')),
      ]);
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Особистий щоденник')),
      floatingActionButton: _tab == 0
          ? FloatingActionButton(
              onPressed: () => _edit(), child: const Icon(Icons.add))
          : null,
      bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (v) => setState(() => _tab = v),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.notes), label: 'Записи'),
            NavigationDestination(
                icon: Icon(Icons.calendar_month), label: 'Календар'),
            NavigationDestination(
                icon: Icon(Icons.bar_chart), label: 'Статистика'),
            NavigationDestination(icon: Icon(Icons.label), label: 'Теги')
          ]),
      body: switch (_tab) {
        0 => _timeline(),
        1 => _calendar(),
        2 => _statistics(),
        _ => _tagList()
      });
}

class TagForm extends StatefulWidget {
  const TagForm({super.key, this.tag});
  final Tag? tag;
  @override
  State<TagForm> createState() => _TagFormState();
}

class _TagFormState extends State<TagForm> {
  final _name = TextEditingController();
  String _color = 'BBDEFB';
  @override
  void initState() {
    super.initState();
    _name.text = widget.tag?.name ?? '';
    _color = widget.tag?.color ?? _color;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Тег')),
      body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Назва')),
            Wrap(spacing: 8, children: [
              for (final color in ['BBDEFB', 'C8E6C9', 'FFECB3', 'F8BBD0'])
                ChoiceChip(
                    label: Text(color),
                    backgroundColor: Color(int.parse('FF$color', radix: 16)),
                    selected: _color == color,
                    onSelected: (_) => setState(() => _color = color))
            ]),
            FilledButton(
                onPressed: () {
                  if (_name.text.trim().isNotEmpty) {
                    Navigator.pop(
                        context,
                        Tag(
                            id: widget.tag?.id,
                            name: _name.text.trim(),
                            color: _color,
                            createdAt:
                                widget.tag?.createdAt ?? DateTime.now()));
                  }
                },
                child: const Text('Зберегти')),
          ])));
}
