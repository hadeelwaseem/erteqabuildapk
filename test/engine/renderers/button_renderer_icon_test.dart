import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sooq_merchant/config/component_config.dart';
import 'package:sooq_merchant/core/enums/generic_component_type.dart';
import 'package:sooq_merchant/engine/tree/renderers/button_renderer.dart';

import 'renderer_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('icon renders Row with label and Icon trailing by default', (
    tester,
  ) async {
    final renderer = ButtonRenderer();
    final config = ComponentConfig(
      type: GenericComponentType.button,
      properties: {
        'label': 'واتساب',
        'variant': 'elevated',
        'icon': 'phone',
        'onTap': () {},
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: renderer.render(
            config,
            buildChild: (_) => const SizedBox.shrink(),
            dataContext: rendererDataContext(),
          ),
        ),
      ),
    );

    expect(find.byType(Row), findsOneWidget);
    expect(find.text('واتساب'), findsOneWidget);
    expect(find.byIcon(Icons.phone), findsOneWidget);
  });

  testWidgets('iconPosition leading places icon before label', (tester) async {
    final renderer = ButtonRenderer();
    final config = ComponentConfig(
      type: GenericComponentType.button,
      properties: {
        'label': 'Cart',
        'variant': 'elevated',
        'icon': 'shopping_cart',
        'iconPosition': 'leading',
        'onTap': () {},
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: renderer.render(
            config,
            buildChild: (_) => const SizedBox.shrink(),
            dataContext: rendererDataContext(),
          ),
        ),
      ),
    );

    final row = tester.widget<Row>(find.byType(Row));
    expect(row.children.first, isA<Icon>());
  });

  testWidgets('without icon still renders plain Text child', (tester) async {
    final renderer = ButtonRenderer();
    final config = ComponentConfig(
      type: GenericComponentType.button,
      properties: {'label': 'Go', 'variant': 'elevated', 'onTap': () {}},
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: renderer.render(
            config,
            buildChild: (_) => const SizedBox.shrink(),
            dataContext: rendererDataContext(),
          ),
        ),
      ),
    );

    expect(find.byType(Row), findsNothing);
    expect(find.text('Go'), findsOneWidget);
  });
}
