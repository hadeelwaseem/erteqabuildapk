import 'package:flutter_test/flutter_test.dart';
import 'package:sooq_merchant/config/component_config.dart';
import 'package:sooq_merchant/config/screen_config.dart';
import 'package:sooq_merchant/core/enums/generic_component_type.dart';
import 'package:sooq_merchant/engine/requests/request_mapper.dart';

void main() {
  group('EngineRequestMapper pathBindings', () {
    test('buildRuntimeRequest resolves categorySlug from pageState', () {
      const base = EngineMappedRequest(
        key: 'category-products',
        requestUrl: null,
        rawRequestUrl:
            '/api/v1/public/categories/:categorySlug/products?page=0&size=20',
        semanticType: null,
        page: 0,
        size: 20,
        pathBindings: {
          ':categorySlug': {
            'source': 'pageState',
            'field': 'selectedCategorySlug',
          },
        },
        deferInitialDispatch: true,
        sourceData: {'page': 0, 'size': 20},
      );

      final runtime = EngineRequestMapper.buildRuntimeRequest(
        base,
        pageState: {'selectedCategorySlug': 'electronics'},
      );

      expect(
        runtime.requestUrl,
        '/api/v1/public/categories/electronics/products?page=0&size=20',
      );
    });

    test(
      'buildRuntimeRequest returns unresolved when pageState slug missing',
      () {
        const base = EngineMappedRequest(
          key: 'category-products',
          requestUrl: null,
          rawRequestUrl:
              '/api/v1/public/categories/:categorySlug/products?page=0&size=20',
          semanticType: null,
          page: 0,
          size: 20,
          pathBindings: {
            ':categorySlug': {
              'source': 'pageState',
              'field': 'selectedCategorySlug',
            },
          },
          deferInitialDispatch: true,
          sourceData: {},
        );

        final runtime = EngineRequestMapper.buildRuntimeRequest(
          base,
          pageState: const {},
        );

        expect(runtime.requestUrl, isNull);
      },
    );

    test('collectRequests keeps deferred path-bound request', () {
      final config = ScreenConfig(
        pageId: 'page-categories',
        pageName: 'Categories',
        root: ComponentConfig(
          type: GenericComponentType.scaffold,
          children: [
            ComponentConfig(
              type: GenericComponentType.gridView,
              properties: {
                'data': {
                  'requestKey': 'category-products',
                  'requestUrl':
                      '/api/v1/public/categories/:categorySlug/products?page=0&size=20',
                  'pathBindings': {
                    ':categorySlug': {
                      'source': 'pageState',
                      'field': 'selectedCategorySlug',
                    },
                  },
                },
              },
            ),
          ],
        ),
      );

      final mapped = EngineRequestMapper.collectRequests(config);

      expect(mapped, hasLength(1));
      expect(mapped.first.key, 'category-products');
      expect(mapped.first.deferInitialDispatch, isTrue);
      expect(mapped.first.requestUrl, isNull);
    });

    test('parses primeFromRequest from data block', () {
      final prime = EnginePrimeFromRequest.fromData({
        'sourceRequestKey': 'category-tree',
        'itemField': 'slug',
        'pageStateKey': 'selectedCategorySlug',
      });

      expect(prime, isNotNull);
      expect(prime!.sourceRequestKey, 'category-tree');
      expect(prime.itemField, 'slug');
      expect(prime.pageStateKey, 'selectedCategorySlug');
    });

    test('buildRuntimeRequest uses fallbackRequestUrl when slug empty', () {
      const base = EngineMappedRequest(
        key: 'product-list',
        requestUrl: '/api/v1/public/products?page=0&size=20',
        rawRequestUrl:
            '/api/v1/public/categories/:categorySlug/products?page=0&size=20',
        semanticType: null,
        page: 0,
        size: 20,
        pathBindings: {
          ':categorySlug': {
            'source': 'pageState',
            'field': 'selectedCategorySlug',
          },
        },
        fallbackRequestUrl: '/api/v1/public/products?page=0&size=20',
        sourceData: {},
      );

      final runtime = EngineRequestMapper.buildRuntimeRequest(
        base,
        pageState: const {},
      );

      expect(runtime.requestUrl, '/api/v1/public/products?page=0&size=20');
    });

    test(
      'buildRuntimeRequest keeps category URL when slug resolved via pathBindings',
      () {
        const base = EngineMappedRequest(
          key: 'product-list',
          requestUrl: '/api/v1/public/products?page=0&size=20',
          rawRequestUrl:
              '/api/v1/public/categories/:categorySlug/products?page=0&size=20',
          semanticType: null,
          page: 0,
          size: 20,
          pathBindings: {
            ':categorySlug': {
              'source': 'pageState',
              'field': 'selectedCategorySlug',
            },
          },
          fallbackRequestUrl: '/api/v1/public/products?page=0&size=20',
          sourceData: {},
        );

        final runtime = EngineRequestMapper.buildRuntimeRequest(
          base,
          pageState: {'selectedCategorySlug': 'electronics'},
        );

        expect(
          runtime.requestUrl,
          '/api/v1/public/categories/electronics/products?page=0&size=20',
        );
      },
    );

    test('collectRequests uses fallback for initial product-list URL', () {
      final config = ScreenConfig(
        pageId: 'page-products',
        pageName: 'Products',
        root: ComponentConfig(
          type: GenericComponentType.scaffold,
          children: [
            ComponentConfig(
              type: GenericComponentType.gridView,
              properties: {
                'data': {
                  'requestKey': 'product-list',
                  'requestUrl':
                      '/api/v1/public/categories/:categorySlug/products?page=0&size=20',
                  'fallbackRequestUrl':
                      '/api/v1/public/products?page=0&size=20',
                  'pathBindings': {
                    ':categorySlug': {
                      'source': 'pageState',
                      'field': 'selectedCategorySlug',
                    },
                  },
                },
              },
            ),
          ],
        ),
      );

      final mapped = EngineRequestMapper.collectRequests(config);

      expect(mapped, hasLength(1));
      expect(mapped.first.deferInitialDispatch, isFalse);
      expect(mapped.first.requestUrl, '/api/v1/public/products?page=0&size=20');
      expect(EngineRequestMapper.needsSearchCubit(mapped), isFalse);
      expect(EngineRequestMapper.needsProductCubit(mapped), isTrue);
    });
  });
}
