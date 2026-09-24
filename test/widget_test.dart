import 'package:flutter_test/flutter_test.dart';
import 'package:bursa_zemin/main.dart';
import 'package:bursa_zemin/core/constants.dart';

void main() {
  testWidgets('App smoke test — shows app name', (tester) async {
    await tester.pumpWidget(const BursaZeminApp());
    expect(find.text(kAppName), findsOneWidget);
  });

  test('Disclaimer constant is not empty', () {
    expect(kDisclaimer.isNotEmpty, isTrue);
    expect(kDisclaimer, contains('zemin etüdü'));
  });
}
