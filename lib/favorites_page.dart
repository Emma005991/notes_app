import 'package:flutter/material.dart';
import 'main.dart';

class FavoritesPage extends StatelessWidget {
  final List<Note> favorites;
  final Function(Note) onOpen;

  const FavoritesPage({
    super.key,
    required this.favorites,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Favorites')),
      body: favorites.isEmpty
          ? const Center(
              child: Text(
                'No favorite notes yet',
                style: TextStyle(fontSize: 16),
              ),
            )
          : ListView.builder(
              itemCount: favorites.length,
              itemBuilder: (_, index) {
                final note = favorites[index];
                return ListTile(
                  title: Text(note.title.isEmpty ? '(No title)' : note.title),
                  subtitle: Text(
                    note.content,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.star, color: Colors.amber),
                  onTap: () => onOpen(note),
                );
              },
            ),
    );
  }
}
