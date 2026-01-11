import 'package:flutter/material.dart';
import 'main.dart';

class TrashPage extends StatelessWidget {
  final List<Note> trash;
  final Function(Note) onRestore;
  final Function(Note) onDeleteForever;

  const TrashPage({
    super.key,
    required this.trash,
    required this.onRestore,
    required this.onDeleteForever,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recycle Bin'),
      ),
      body: trash.isEmpty
          ? const Center(
              child: Text(
                'Recycle bin is empty',
                style: TextStyle(fontSize: 16),
              ),
            )
          : ListView.builder(
              itemCount: trash.length,
              itemBuilder: (context, index) {
                final note = trash[index];
                return ListTile(
                  title: Text(note.title.isEmpty ? '(No title)' : note.title),
                  subtitle: Text(
                    note.content,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.restore),
                        onPressed: () => onRestore(note),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_forever, color: Colors.red),
                        onPressed: () => onDeleteForever(note),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
