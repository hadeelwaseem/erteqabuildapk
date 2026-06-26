import 'package:flutter_test/flutter_test.dart';
import 'package:sooq_merchant/engine/requests/request_mapper.dart';

void main() {
  const base = EngineMappedRequest(
    key: 'my-orders',
    requestUrl: '/api/v1/customer/orders?page=0&size=20',
    rawRequestUrl: '/api/v1/customer/orders?page=0&size=20',
    semanticType: null,
    page: 0,
    size: 20,
    queryBindings: {
      'status': {'source': 'pageState', 'field': 'orderStatus'},
    },
    sourceData: {'page': 0, 'size': 20},
  );

  group('EngineRequestMapper.buildRuntimeRequest', () {
    test('applies status from pageState', () {
      final runtime = EngineRequestMapper.buildRuntimeRequest(
        base,
        pageState: {'orderStatus': 'CONFIRMED'},
      );

      expect(runtime.requestUrl, contains('status=CONFIRMED'));
      expect(runtime.requestUrl, contains('page=0'));
      expect(runtime.requestUrl, contains('size=20'));
    });

    test('omits status when pageState value is empty', () {
      final runtime = EngineRequestMapper.buildRuntimeRequest(
        base,
        pageState: {'orderStatus': ''},
      );

      expect(runtime.requestUrl, isNot(contains('status=')));
    });

    test('omits status when orderStatus not in pageState', () {
      final runtime = EngineRequestMapper.buildRuntimeRequest(
        base,
        pageState: const {},
      );

      expect(runtime.requestUrl, isNot(contains('status=')));
    });

    test('applies sort from pageState for product browse', () {
      const productBase = EngineMappedRequest(
        key: 'product-list',
        requestUrl: '/api/v1/public/products?page=0&size=20',
        rawRequestUrl: '/api/v1/public/products?page=0&size=20',
        semanticType: null,
        page: 0,
        size: 20,
        queryBindings: {
          'sort': {'source': 'pageState', 'field': 'productSort'},
        },
        sourceData: {'page': 0, 'size': 20},
      );

      final runtime = EngineRequestMapper.buildRuntimeRequest(
        productBase,
        pageState: {'productSort': 'createdAt,desc'},
      );

      expect(runtime.requestUrl, contains('sort=createdAt%2Cdesc'));
    });

    test('uses browse fallback when categoryId filter is inactive', () {
      const productFilterBase = EngineMappedRequest(
        key: 'product-list',
        requestUrl: '/api/v1/public/products/search?page=0&size=20',
        rawRequestUrl: '/api/v1/public/products/search?page=0&size=20',
        semanticType: null,
        page: 0,
        size: 20,
        queryBindings: {
          'categoryId': {
            'source': 'pageState',
            'field': 'selectedCategoryId',
          },
        },
        fallbackRequestUrl: '/api/v1/public/products?page=0&size=20',
        sourceData: {},
      );

      final browse = EngineRequestMapper.buildRuntimeRequest(
        productFilterBase,
        pageState: const {},
      );
      expect(browse.requestUrl, '/api/v1/public/products?page=0&size=20');

      final filtered = EngineRequestMapper.buildRuntimeRequest(
        productFilterBase,
        pageState: {'selectedCategoryId': 'cat-1'},
      );
      expect(filtered.requestUrl, contains('/products/search'));
      expect(filtered.requestUrl, contains('categoryId=cat-1'));
    });
  });
}
