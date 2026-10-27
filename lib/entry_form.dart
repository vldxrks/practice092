import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'models.dart';
import 'main.dart' show moods;

class EntryForm extends StatefulWidget {
  const EntryForm({super.key, this.entry, required this.tags});
  final Entry? entry;
  final List<Tag> tags;
  @override
  State<EntryForm> createState() => _EntryFormState();
}

class _EntryFormState extends State<EntryForm> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController(), _content = TextEditingController();
  String _mood = moods.first;
  final _selected = <int>{};
  bool _favorite = false, _busy = false;
  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    if (e != null) {
      _title.text = e.title;
      _content.text = e.content;
      _mood = e.mood;
      _favorite = e.isFavorite;
      _selected.addAll(e.tags.map((t) => t.id!));
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final now = DateTime.now();
      await DatabaseHelper.instance.saveEntry(Entry(
          id: widget.entry?.id,
          title: _title.text.trim(),
          content: _content.text.trim(),
          mood: _mood,
          createdAt: widget.entry?.createdAt ?? now,
          updatedAt: now,
          isFavorite: _favorite,
          tags: widget.tags.where((t) => _selected.contains(t.id)).toList()));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Не збережено: $e')));
      }
    }
  }

  Future<void> _delete() async {
    try {
      await DatabaseHelper.instance.deleteEntry(widget.entry!.id!);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = _content.text.trim();
    final count = text.isEmpty ? 0 : text.split(RegExp(r'\s+')).length;
    return Scaffold(
        appBar: AppBar(
            title: Text(
                widget.entry == null ? 'Новий запис' : 'Редагування запису')),
        body: Form(
            key: _form,
            child: ListView(padding: const EdgeInsets.all(16), children: [
              TextFormField(
                  controller: _title,
                  decoration: const InputDecoration(labelText: 'Назва'),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Введіть назву' : null),
              TextFormField(
                  controller: _content,
                  minLines: 6,
                  maxLines: 12,
                  decoration: const InputDecoration(labelText: 'Текст'),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Введіть текст' : null,
                  onChanged: (_) => setState(() {})),
              Text('Слів: $count'),
              DropdownButton<String>(
                  value: _mood,
                  items: [
                    for (final m in moods)
                      DropdownMenuItem(value: m, child: Text(m))
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _mood = v);
                  }),
              SwitchListTile(
                  title: const Text('Обране'),
                  value: _favorite,
                  onChanged: (v) => setState(() => _favorite = v)),
              Wrap(spacing: 8, children: [
                for (final t in widget.tags)
                  FilterChip(
                      label: Text(t.name),
                      selected: _selected.contains(t.id),
                      onSelected: (v) => setState(() {
                            if (v) {
                              _selected.add(t.id!);
                            } else {
                              _selected.remove(t.id);
                            }
                          }))
              ]),
              FilledButton(
                  onPressed: _busy ? null : _save,
                  child: Text(_busy ? 'Збереження…' : 'Зберегти')),
              if (widget.entry != null)
                TextButton(
                    onPressed: _busy ? null : _delete,
                    child: const Text('Видалити запис')),
            ])));
  }
}
