import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:connect_four_flutter/app.dart';
import 'package:connect_four_flutter/core/theme/nb_colors.dart';

void main() {
  testWidgets('ConnectFourApp renders with Neobrutalism theme and no debug banner', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ConnectFourApp());

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.title, 'Lig 4');
    expect(materialApp.debugShowCheckedModeBanner, isFalse);
    expect(materialApp.theme?.scaffoldBackgroundColor, NbColors.background);
    expect(find.text('Lig 4'), findsOneWidget);
  });
}
