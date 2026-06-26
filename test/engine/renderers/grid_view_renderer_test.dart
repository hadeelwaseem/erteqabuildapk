import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:sooq_merchant/config/component_config.dart';
import 'package:sooq_merchant/core/enums/generic_component_type.dart';
import 'package:sooq_merchant/core/widgets/engine_network_image.dart';
import 'package:sooq_merchant/engine/tree/renderers/grid_view_renderer.dart';
import 'package:sooq_merchant/engine/tree/renderers/image_renderer.dart';
import 'package:sooq_merchant/engine/tree/renderers/text_renderer.dart';

import 'renderer_test_utils.dart';

const _requestKey = 'product-list';

ComponentConfig _gridConfig({
  Map<String, dynamic> extraProps = const {},
  ItemBuilderConfig? itemBuilder,
}) {
  return ComponentConfig(
    type: GenericComponentType.gridView,
    crossAxisCount: 2,
    properties: {
      'data': {'requestKey': _requestKey},
      ...extraProps,
    },
    itemBuilder:
        itemBuilder ??
        ItemBuilderConfig(
          source: 'dataContext.requests.$_requestKey.data',
          item: ComponentConfig(
            type: GenericComponentType.text,
            properties: {'valuePath': 'item.name'},
          ),
        ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildChild(
    ComponentConfig child,
    Map<String, dynamic> dataContext,
  ) {
    final merged = mergeRendererContext(dataContext, child);
    return TextRenderer().render(
      child,
      buildChild: (_) => const SizedBox.shrink(),
      dataContext: merged,
    );
  }

  testWidgets('loading phase shows Skeletonizer with grid layout', (
    tester,
  ) async {
    final renderer = GridViewRenderer();
    final dataContext = requestLoadingDataContext(_requestKey);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: renderer.render(
            _gridConfig(
              extraProps: {
                'data': {'requestKey': _requestKey, 'size': 6},
              },
            ),
            buildChild: (c) => buildChild(c, dataContext),
            dataContext: dataContext,
          ),
        ),
      ),
    );

    expect(
      find.byWidgetPredicate((w) => w is Skeletonizer),
      findsOneWidget,
    );
    expect(find.byType(GridView), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('error phase still shows message not skeleton', (tester) async {
    final renderer = GridViewRenderer();
    const arabicError = 'تعذر تحميل المنتجات';
    final dataContext = {
      ...rendererDataContext(),
      'requests': {
        _requestKey: {'success': false, 'message': 'fail'},
      },
    };

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: renderer.render(
            _gridConfig(extraProps: {'errorMessage': arabicError}),
            buildChild: (c) => buildChild(c, dataContext),
            dataContext: dataContext,
          ),
        ),
      ),
    );

    expect(find.text(arabicError), findsOneWidget);
    expect(
      find.byWidgetPredicate((w) => w is Skeletonizer),
      findsNothing,
    );
  });

  testWidgets('empty phase shows Arabic emptyMessage from props', (
    tester,
  ) async {
    const arabicEmpty = 'لا توجد منتجات';
    final renderer = GridViewRenderer();
    final dataContext = requestReadyDataContext(
      requestKey: _requestKey,
      items: [],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: renderer.render(
            _gridConfig(extraProps: {'emptyMessage': arabicEmpty}),
            buildChild: (c) => buildChild(c, dataContext),
            dataContext: dataContext,
          ),
        ),
      ),
    );

    expect(find.text(arabicEmpty), findsOneWidget);
    expect(find.text('No items available'), findsNothing);
  });

  testWidgets('ready phase builds GridView with item template text', (
    tester,
  ) async {
    final renderer = GridViewRenderer();
    final dataContext = requestReadyDataContext(
      requestKey: _requestKey,
      items: [
        {'name': 'Alpha'},
        {'name': 'Beta'},
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: renderer.render(
            _gridConfig(),
            buildChild: (c) => buildChild(c, dataContext),
            dataContext: dataContext,
          ),
        ),
      ),
    );

    expect(find.byType(GridView), findsOneWidget);
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);
  });

  testWidgets('ready phase binds item.image in grid tile', (tester) async {
    const productUrl = 'https://cdn.example.com/product-a.jpg';
    const fallbackUrl = 'https://cdn.example.com/fallback.jpg';
    final gridRenderer = GridViewRenderer();
    final imageRenderer = ImageRenderer();
    final dataContext = requestReadyDataContext(
      requestKey: _requestKey,
      items: [
        {'name': 'Alpha', 'image': productUrl},
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: gridRenderer.render(
            _gridConfig(
              itemBuilder: ItemBuilderConfig(
                source: 'dataContext.requests.$_requestKey.data',
                item: ComponentConfig(
                  type: GenericComponentType.image,
                  properties: {
                    'source': 'network',
                    'urlPath': 'item.image',
                    'url': fallbackUrl,
                    'height': 80,
                  },
                ),
              ),
            ),
            buildChild: (c) {
              final merged = mergeRendererContext(dataContext, c);
              return imageRenderer.render(
                c,
                buildChild: (_) => const SizedBox.shrink(),
                dataContext: merged,
              );
            },
            dataContext: dataContext,
          ),
        ),
      ),
    );

    final networkImage = tester.widget<EngineNetworkImage>(
      find.byType(EngineNetworkImage),
    );
    expect(networkImage.url, productUrl);
  });

  testWidgets(
    'deferred qField request with phase none does not show emptyMessage',
    (tester) async {
      const requestKey = 'search-results';
      final renderer = GridViewRenderer();
      final config = ComponentConfig(
        type: GenericComponentType.gridView,
        crossAxisCount: 2,
        properties: {
          'enableInnerScroll': false,
          'data': {
            'requestKey': requestKey,
            'requestUrl': '/api/v1/public/products/search',
            'qField': 'searchQuery',
          },
          'emptyMessage': 'لا توجد منتجات',
        },
        itemBuilder: ItemBuilderConfig(
          source: 'dataContext.requests.$requestKey.data',
          item: ComponentConfig(
            type: GenericComponentType.text,
            properties: {'valuePath': 'item.name'},
          ),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: renderer.render(
              config,
              buildChild: (c) => buildChild(c, rendererDataContext()),
              dataContext: rendererDataContext(),
            ),
          ),
        ),
      );

      expect(find.text('لا توجد منتجات'), findsNothing);
      expect(find.byType(GridView), findsNothing);
    },
  );
}
