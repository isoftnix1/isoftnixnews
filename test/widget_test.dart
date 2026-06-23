import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:isoftnix_news/main.dart';

void main() {
  testWidgets('app builds successfully', (WidgetTester tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(ISoftNixNewsApp(navigatorKey: navigatorKey));
    await tester.pumpAndSettle();

    expect(find.byType(ISoftNixNewsApp), findsOneWidget);
  });
}
