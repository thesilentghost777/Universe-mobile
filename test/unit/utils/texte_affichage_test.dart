import 'package:flutter_test/flutter_test.dart';
import 'package:universe_frontend/core/utils/texte_affichage.dart';

void main() {
  test('un suffixe d une lettre reste collé au mot précédent', () {
    expect(
      eviterMotOrphelin('Université de Yaoundé I'),
      'Université de Yaoundé\u00A0I',
    );
  });

  test('un titre sans suffixe court ne change pas', () {
    expect(
      eviterMotOrphelin('Les réseaux de neurones'),
      'Les réseaux de neurones',
    );
  });
}
