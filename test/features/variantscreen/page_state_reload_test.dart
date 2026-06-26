import 'package:flutter_test/flutter_test.dart';
import 'package:sooq_merchant/engine/page/page_state_store.dart';
import 'package:sooq_merchant/engine/requests/request_mapper.dart';

void main() {
  test('primeFromRequest config is parsed on mapped request', () {
    const request = EngineMappedRequest(
      key: 'category-products',
      requestUrl: null,
      rawRequestUrl:
          '/api/v1/public/categories/:categorySlug/products?page=0&size=20',
      semanticType: null,
      page: 0,
      size: 20,
      deferInitialDispatch: true,
      primeFromRequest: EnginePrimeFromRequest(
        sourceRequestKey: 'category-tree',
        itemField: 'slug',
        pageStateKey: 'selectedCategorySlug',
      ),
      sourceData: {},
    );

    expect(request.primeFromRequest?.sourceRequestKey, 'category-tree');
    expect(request.deferInitialDispatch, isTrue);
  });

  test('pageState reload uses resolved category products URL', () {
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

    final store = PageStateStore()..update({'selectedCategorySlug': 'shoes'});

    final runtime = EngineRequestMapper.buildRuntimeRequest(
      base,
      pageState: store.values,
    );

    expect(
      runtime.requestUrl,
      '/api/v1/public/categories/shoes/products?page=0&size=20',
    );
  });
}
