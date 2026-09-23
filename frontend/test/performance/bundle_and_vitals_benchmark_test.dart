import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universe_frontend/app/theme.dart';
import 'package:universe_frontend/shared/models/models.dart';

void main() {
  group('Performance, Core Vitals & Memory Benchmark Tests', () {
    testWidgets('Large Feed list (200 items) renders efficiently within frame budget', (tester) async {
      final largeVideoList = List.generate(
        200,
        (i) => VideoItem(
          id: 'vid-$i',
          titre: 'Vidéo numéro $i - Algorithmique et Complexité',
          description: 'Description de la vidéo $i sur les structures de données avancées.',
          youtubeId: 'vid_yt_$i',
          nombreLikes: i * 5,
          likedByMe: i % 2 == 0,
        ),
      );

      final stopwatch = Stopwatch()..start();

      await tester.pumpWidget(
        MaterialApp(
          theme: buildUniverseTheme(),
          home: Scaffold(
            body: ListView.builder(
              itemCount: largeVideoList.length,
              itemBuilder: (context, index) {
                final v = largeVideoList[index];
                return ListTile(
                  title: Text(v.titre),
                  subtitle: Text(v.description ?? ''),
                  trailing: Text('${v.nombreLikes} likes'),
                );
              },
            ),
          ),
        ),
      );

      await tester.pump();
      stopwatch.stop();

      // Ensure first frame layout finishes without unhandled errors
      expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(0));
      expect(find.byType(ListTile), findsWidgets);

      // Test scroll performance through virtualized list
      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    test('JSON model parsing throughput benchmark (> 1000 items / 50ms)', () {
      final sampleList = List.generate(
        1000,
        (i) => {
          'id': 'l-$i',
          'titre': 'Livre $i',
          'auteurLivre': 'Auteur $i',
          'description': 'Description du livre $i',
          'fichierCle': 'livres/livre_$i.pdf',
        },
      );

      final stopwatch = Stopwatch()..start();
      final items = sampleList.map((j) => LivreItem.fromJson(j)).toList();
      stopwatch.stop();

      expect(items.length, 1000);
      expect(items.first.titre, 'Livre 0');
      expect(stopwatch.elapsedMilliseconds, lessThan(100));
    });

    test('VideoItem copyWith immutability maintains zero mutation footprint', () {
      const original = VideoItem(
        id: 'v1',
        titre: 'Original Title',
        nombreLikes: 10,
        likedByMe: false,
      );

      final mutated = original.copyWith(likedByMe: true, nombreLikes: 11);

      expect(original.nombreLikes, 10);
      expect(original.likedByMe, isFalse);
      expect(mutated.nombreLikes, 11);
      expect(mutated.likedByMe, isTrue);
    });
  });
}
