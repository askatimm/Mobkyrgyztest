import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyrgyztestapp/widgets/video_design.dart';

void main() {
  testWidgets('Premium badge is visible without backend initialization', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: PremiumBadge()),
    ));
    expect(find.text('Premium'), findsOneWidget);
    expect(find.byIcon(Icons.workspace_premium_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
