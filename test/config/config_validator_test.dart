import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sooq_merchant/config/bootstrap_config.dart';
import 'package:sooq_merchant/config/config_mode.dart';
import 'package:sooq_merchant/config/config_validator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const bootstrap = BootstrapConfig(
    schemaVersion: '1.0',
    configMode: ConfigMode.local,
    variantId: 'mobile_production_v2',
    appName: 'Test App',
    bundleId: 'com.test.app',
    apiBaseUrl: 'https://api.example.com',
    tenantId: 'tenant-uuid',
    tenantSlug: 'store-a',
  );

  Map<String, dynamic> minimalRenderJson() => {
    'schemaVersion': '1.0',
    'navigation': {
      'type': 'tabs',
      'initialRoute': '/home',
      'tabs': [
        {'id': 'home', 'label': 'Home', 'icon': 'home', 'route': '/home'},
      ],
    },
    'pages': [
      {
        'id': 'home-page',
        'route': '/home',
        'title': 'Home',
        'body': [
          {
            'id': 'title',
            'type': 'text',
            'props': {'value': 'Hello'},
          },
        ],
      },
    ],
  };

  test('valid render JSON passes validation', () {
    final result = ConfigValidator.validateMap(bootstrap, minimalRenderJson());

    expect(result.valid, isTrue);
    expect(result.renderJson, isNotNull);
    expect(result.errorMessage, isNull);
  });

  test('malformed JSON string fails validation', () {
    final result = ConfigValidator.validateString(bootstrap, '{not json');

    expect(result.valid, isFalse);
    expect(result.renderJson, isNull);
    expect(result.errorMessage, isNotNull);
  });

  test('missing pages and root fails validation', () {
    final result = ConfigValidator.validateMap(bootstrap, {
      'schemaVersion': '1.0',
      'navigation': {'type': 'tabs', 'tabs': []},
    });

    expect(result.valid, isFalse);
    expect(result.errorMessage, contains('pages[]'));
  });

  test('legacy root shape passes validation', () {
    final result = ConfigValidator.validateMap(bootstrap, {
      'id': 'legacy-page',
      'pageName': 'Legacy',
      'root': {'id': 'root', 'type': 'scaffold', 'props': {}, 'children': []},
    });

    expect(result.valid, isTrue);
    expect(result.renderJson, isNotNull);
  });

  test('empty pages with valid nav passes validation', () {
    final result = ConfigValidator.validateMap(bootstrap, {
      'schemaVersion': '1.0',
      'navigation': {'type': 'tabs', 'initialRoute': '/', 'tabs': []},
      'pages': [],
    });

    expect(result.valid, isTrue);
  });

  test('prod asset JSON string passes validation', () async {
    final jsonStr = await rootBundle.loadString(
      'assets/config/mobile_production_v2.json',
    );

    final result = ConfigValidator.validateString(
      const BootstrapConfig(
        schemaVersion: '1.0',
        configMode: ConfigMode.local,
        variantId: 'mobile_production_v2',
        appName: 'Anas Golden Store',
        bundleId: 'com.anasgoldenmer.shop',
        apiBaseUrl: 'https://sooq.up.railway.app',
        tenantId: '3fc183e8-ac80-4b2a-8bf1-4cd6ac6ffcb1',
        tenantSlug: 'anasgoldenmer',
      ),
      jsonStr,
    );

    expect(result.valid, isTrue, reason: result.errorMessage);
    expect(result.renderJson!['pages'], isA<List>());
  });
}
