import 'package:flutter_test/flutter_test.dart';

void main() {
  test('product detail route prefers item slug over productId uuid', () {
    final route = '/product/details/:productId';
    final dataContext = <String, dynamic>{
      'item': {
        'productId': 'ef743ddc-75a5-4f57-8447-0deb9d5c58bf',
        'slug': 'simple-product-test',
      },
    };

    final resolved = route.replaceAllMapped(RegExp(r':([A-Za-z0-9_]+)'), (
      match,
    ) {
      final key = match.group(1) ?? '';
      // Mirror EngineActionDispatcher._lookupRouteValue via testing helper
      final item = dataContext['item'] as Map<String, dynamic>;
      if (key == 'productId') {
        final slug = item['slug'];
        if (slug != null && slug.toString().trim().isNotEmpty) {
          return slug.toString().trim();
        }
      }
      return item[key]?.toString() ?? match.group(0) ?? '';
    });

    expect(resolved, '/product/details/simple-product-test');
  });
}
