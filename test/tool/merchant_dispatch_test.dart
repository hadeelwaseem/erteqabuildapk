import 'package:flutter_test/flutter_test.dart';

import '../../tool/merchant_dispatch.dart';

void main() {
  group('validateMerchantDispatchPayload', () {
    test('accepts valid local dispatch payload', () {
      final errors = validateMerchantDispatchPayload(_validPayload);
      expect(errors, isEmpty);
    });

    test('rejects missing snake_case fields', () {
      final errors = validateMerchantDispatchPayload(<String, dynamic>{
        'app_name': 'Store',
      });
      expect(errors, isNotEmpty);
      expect(errors.any((e) => e.contains('bundle_id')), isTrue);
    });

    test('rejects camelCase keys (common Postman mistake)', () {
      final errors = validateMerchantDispatchPayload(<String, dynamic>{
        ..._validPayload,
        'appName': 'Wrong casing',
      });
      expect(
        errors.any((e) => e.contains('app_name') && e.contains('appName')),
        isTrue,
      );
    });

    test('requires config_url for remoteStorage', () {
      final errors = validateMerchantDispatchPayload(<String, dynamic>{
        ..._validPayload,
        'config_mode': 'remoteStorage',
      });
      expect(errors.any((e) => e.contains('config_url')), isTrue);
    });

    test('rejects invalid bundle_id format', () {
      final errors = validateMerchantDispatchPayload(<String, dynamic>{
        ..._validPayload,
        'bundle_id': 'Not A Valid Package',
      });
      expect(errors.any((e) => e.contains('bundle_id')), isTrue);
    });
  });

  group('merchantManifestFromDispatch', () {
    test('maps snake_case payload to camelCase manifest', () {
      final manifest = merchantManifestFromDispatch(_validPayload);

      expect(manifest['appName'], 'Anas Golden Store');
      expect(manifest['bundleId'], 'com.anasgoldenmer.shop');
      expect(manifest['apiBaseUrl'], 'https://sooq.up.railway.app');
      expect(manifest['tenantId'], '3fc183e8-ac80-4b2a-8bf1-4cd6ac6ffcb1');
      expect(manifest['tenantSlug'], 'anasgoldenmer');
      expect(manifest['configMode'], 'local');
      expect(manifest['variantId'], 'mobile_production_v2');
      expect(manifest['version'], '1.0.0');
      expect(manifest['buildNumber'], 1);
    });

    test('defaults version and build_number when omitted', () {
      final payload = Map<String, dynamic>.from(_validPayload)
        ..remove('version')
        ..remove('build_number');

      final manifest = merchantManifestFromDispatch(payload);

      expect(manifest['version'], '1.0.0');
      expect(manifest['buildNumber'], 1);
    });
  });

  group('unwrapDispatchPayload', () {
    test('unwraps client_payload from full dispatch body', () {
      final payload = unwrapDispatchPayload(<String, dynamic>{
        'event_type': 'build-merchant-app',
        'client_payload': _validPayload,
      });

      expect(payload['tenant_slug'], 'anasgoldenmer');
    });

    test('returns raw payload when client_payload is absent', () {
      final payload = unwrapDispatchPayload(_validPayload);
      expect(payload['tenant_slug'], 'anasgoldenmer');
    });

    test('unwraps app_data JSON string inside client_payload', () {
      final payload = unwrapDispatchPayload(<String, dynamic>{
        'app_data':
            '{"app_name":"Anas Store","bundle_id":"com.sooq.merchant.mobile",'
            '"api_base_url":"https://example.com","tenant_id":"id",'
            '"tenant_slug":"slug","config_mode":"local","variant_id":"mobile_production_v2"}',
      });

      expect(payload['app_name'], 'Anas Store');
      expect(payload['bundle_id'], 'com.sooq.merchant.mobile');
    });
  });
}

const _validPayload = <String, dynamic>{
  'app_name': 'Anas Golden Store',
  'bundle_id': 'com.anasgoldenmer.shop',
  'api_base_url': 'https://sooq.up.railway.app',
  'tenant_id': '3fc183e8-ac80-4b2a-8bf1-4cd6ac6ffcb1',
  'tenant_slug': 'anasgoldenmer',
  'config_mode': 'local',
  'variant_id': 'mobile_production_v2',
  'version': '1.0.0',
  'build_number': 1,
};
