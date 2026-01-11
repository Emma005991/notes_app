import 'package:flutter/material.dart';
import 'main.dart'; // for the Note model

class NotesSearchDelegate extends SearchDelegate {
  final List<Note> notes;
  final Function(Note) onOpen;

  NotesSearchDelegate({
    required this.notes,
    required this.onOpen,
  });

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () => query = '',
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildList();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildList();
  }

  Widget _buildList() {
    final results = notes.where((note) {
      return note.title.toLowerCase().contains(query.toLowerCase()) ||
          note.content.toLowerCase().contains(query.toLowerCase());
    }).toList();

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final note = results[index];
        return ListTile(
          title: Text(note.title.isEmpty ? '(No title)' : note.title),
          subtitle: Text(
            note.content,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () => onOpen(note),
        );
      },
    );
  }
}
