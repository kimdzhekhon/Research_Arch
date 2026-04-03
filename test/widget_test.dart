import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:researcharch/main.dart';

void main() {
  testWidgets('App renders dashboard', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: ResearchArchApp()));
    await tester.pumpAndSettle();

    expect(find.text('ResearchArch'), findsOneWidget);
    expect(find.text('연구 주제 입력'), findsOneWidget);
    expect(find.text('연구 시작'), findsOneWidget);
  });
}
