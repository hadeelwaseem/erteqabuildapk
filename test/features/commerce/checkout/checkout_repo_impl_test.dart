import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sooq_merchant/core/errors/failures.dart';
import 'package:sooq_merchant/core/network/network_config.dart';
import 'package:sooq_merchant/features/commerce/checkout/data/repos/checkout_repo_impl.dart';
import 'package:sooq_merchant/features/commerce/data/models/checkout_item.dart';
import 'package:sooq_merchant/features/commerce/data/models/checkout_request.dart';
import 'package:sooq_merchant/features/commerce/data/models/guest_order_lookup.dart';
import 'package:sooq_merchant/features/commerce/data/models/shipping_address.dart';
import 'package:sooq_merchant/features/commerce/data/models/shipping_cost_request.dart';

import '../../product/support/product_test_utils.dart';

Dio _testDio(FakeHttpClientAdapter adapter) {
  return Dio(BaseOptions(baseUrl: NetworkConfig.defaultBaseUrl))
    ..httpClientAdapter = adapter;
}

void main() {
  group('CheckoutRepoImpl', () {
    test('getPaymentMethods parses list envelope', () async {
      final adapter = FakeHttpClientAdapter((options) async {
        expect(options.path, '/api/v1/public/payments/methods');
        return jsonResponse({
          'success': true,
          'data': [
            {
              'providerCode': 'COD',
              'displayName': 'COD',
              'requiresRedirect': false,
              'supportsSavedCards': false,
            },
          ],
        });
      });
      final repo = CheckoutRepoImpl(_testDio(adapter));

      final result = await repo.getPaymentMethods(tenantId: 'tenant-1');

      result.fold(
        (failure) => fail(failure.errMessage),
        (methods) {
          expect(methods, hasLength(1));
          expect(methods.first.providerCode, 'COD');
        },
      );
    });

    test('calculateShipping parses object envelope', () async {
      final adapter = FakeHttpClientAdapter((options) async {
        expect(options.path, '/api/v1/public/shipping/calculate');
        return jsonResponse({
          'success': true,
          'data': {
            'shippingCostSyp': 25000,
            'providerCode': 'LOCAL',
            'providerName': 'Local',
            'estimatedDeliveryHours': 24,
          },
        });
      });
      final repo = CheckoutRepoImpl(_testDio(adapter));

      final result = await repo.calculateShipping(
        request: const ShippingCostRequest(
          originLat: 33.5,
          originLng: 36.3,
          destinationLat: 33.52,
          destinationLng: 36.28,
        ),
      );

      result.fold(
        (failure) => fail(failure.errMessage),
        (quote) => expect(quote.shippingCostSyp, 25000),
      );
    });

    test('validateDiscount maps failure envelope to Left', () async {
      final adapter = FakeHttpClientAdapter((options) async {
        expect(options.path, '/api/v1/public/checkout/validate-discount');
        return jsonResponse({
          'success': false,
          'message': 'كود الخصم غير صالح',
        });
      });
      final repo = CheckoutRepoImpl(_testDio(adapter));

      final result = await repo.validateDiscount(
        code: 'BAD',
        subtotal: 1000,
        shippingCost: 100,
      );

      result.fold(
        (failure) => expect(failure.errMessage, contains('غير صالح')),
        (_) => fail('expected failure'),
      );
    });

    test('placeOrder parses order envelope', () async {
      final adapter = FakeHttpClientAdapter((options) async {
        expect(options.path, '/api/v1/public/checkout');
        return jsonResponse({
          'success': true,
          'data': {
            'orderId': 'ord-1',
            'tenantId': 'tenant-1',
            'orderNumber': 'SOOQ-1001',
            'orderStatus': 'PENDING',
            'paymentStatus': 'PENDING',
            'paymentMethod': 'COD',
            'currencyCode': 'SYP',
            'subtotal': 100000,
            'discountAmount': 0,
            'taxAmount': 0,
            'shippingCost': 25000,
            'total': 125000,
            'shippingAddress': {
              'latitude': 33.5,
              'longitude': 36.3,
              'recipientName': 'Test',
              'phone': '+963900000000',
            },
            'placedAt': '2026-01-01T00:00:00Z',
          },
        });
      });
      final repo = CheckoutRepoImpl(_testDio(adapter));

      final result = await repo.placeOrder(
        request: CheckoutRequest(
          items: const [CheckoutItem(variantId: 'v1', quantity: 1)],
          shippingAddress: const ShippingAddress(
            latitude: 33.5,
            longitude: 36.3,
            recipientName: 'Test',
            phone: '+963900000000',
          ),
          paymentMethod: 'COD',
          checkoutToken: 'token-1',
        ),
      );

      result.fold(
        (failure) => fail(failure.errMessage),
        (order) => expect(order.orderNumber, 'SOOQ-1001'),
      );
    });

    test('lookupGuestOrder returns Left on HTTP error', () async {
      final adapter = FakeHttpClientAdapter((options) async {
        return jsonResponse(
          {'success': false, 'message': 'الطلب غير موجود'},
          statusCode: 404,
        );
      });
      final repo = CheckoutRepoImpl(_testDio(adapter));

      final result = await repo.lookupGuestOrder(
        lookup: const GuestOrderLookup(
          orderNumber: 'SOOQ-404',
          email: 'guest@example.com',
        ),
      );

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure, isA<ServerFailure>()),
        (_) => fail('expected failure'),
      );
    });
  });
}
