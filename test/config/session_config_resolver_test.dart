import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sooq_merchant/config/bootstrap_config.dart';
import 'package:sooq_merchant/config/config_cache.dart';
import 'package:sooq_merchant/config/config_mode.dart';
import 'package:sooq_merchant/config/remote_config_fetcher.dart';
import 'package:sooq_merchant/engine/config_pipeline_result.dart';
import 'package:sooq_merchant/config/session_config_resolver.dart';

void main() {
  const bootstrap = BootstrapConfig(
    schemaVersion: '1.0',
    configMode: ConfigMode.remoteStorage,
    variantId: 'mobile_production_v2',
    appName: 'Remote Store',
    bundleId: 'com.remote.store',
    apiBaseUrl: 'https://api.example.com',
    tenantId: 'tenant-1',
    tenantSlug: 'store-a',
    configUrl: 'https://cdn.example.com/mobile-config.json',
  );

  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('session_resolver_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  ConfigCache cache() => ConfigCache(directoryProvider: () async => tempDir);

  Map<String, dynamic> validRenderJson() => {
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

  String validRawJson() => jsonEncode(validRenderJson());

  RemoteConfigFetcher fetcherReturning(
    String? body, {
    bool failOnRequest = false,
  }) {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (failOnRequest) {
            fail('Remote fetch should not have been called');
          }
          if (body == null) {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.connectionError,
              ),
            );
            return;
          }
          handler.resolve(
            Response(requestOptions: options, statusCode: 200, data: body),
          );
        },
      ),
    );
    return RemoteConfigFetcher(client: dio);
  }

  SessionConfigResolver resolver({
    ConfigCache? cacheOverride,
    RemoteConfigFetcher? fetcher,
    Future<Map<String, dynamic>> Function(BootstrapConfig bootstrap)?
    assetLoader,
  }) {
    return SessionConfigResolver(
      cache: cacheOverride ?? cache(),
      fetcher: fetcher ?? fetcherReturning(null),
      assetLoader: assetLoader ?? (_) async => validRenderJson(),
    );
  }

  test('valid cache returns source cache without network', () async {
    final c = cache();
    await c.write(bootstrap, validRawJson());

    final result = await resolver(
      cacheOverride: c,
      fetcher: fetcherReturning(validRawJson(), failOnRequest: true),
    ).resolve(bootstrap);

    expect(result, isNotNull);
    expect(result!.sessionSource, SessionConfigSource.cache);
    expect(result.renderJson['pages'], isA<List>());
  });

  test('invalid cache then valid remote rewrites cache', () async {
    final c = cache();
    await c.write(bootstrap, '{not valid json');

    final remoteJson = validRawJson();
    final result = await resolver(
      cacheOverride: c,
      fetcher: fetcherReturning(remoteJson),
    ).resolve(bootstrap);

    expect(result, isNotNull);
    expect(result!.sessionSource, SessionConfigSource.remote);
    expect(await c.read(bootstrap), remoteJson);
  });

  test('invalid cache then remote timeout then valid asset', () async {
    final c = cache();
    await c.write(bootstrap, '{"no":"pages"}');

    final result = await resolver(
      cacheOverride: c,
      fetcher: fetcherReturning(null),
      assetLoader: (_) async => validRenderJson(),
    ).resolve(bootstrap);

    expect(result, isNotNull);
    expect(result!.sessionSource, SessionConfigSource.asset);
    expect(await c.read(bootstrap), isNull);
  });

  test('no cache then valid remote writes cache', () async {
    final c = cache();
    final remoteJson = validRawJson();

    final result = await resolver(
      cacheOverride: c,
      fetcher: fetcherReturning(remoteJson),
    ).resolve(bootstrap);

    expect(result, isNotNull);
    expect(result!.sessionSource, SessionConfigSource.remote);
    expect(await c.read(bootstrap), remoteJson);
  });

  test('no cache then remote timeout then valid asset', () async {
    final c = cache();

    final result = await resolver(
      cacheOverride: c,
      fetcher: fetcherReturning(null),
      assetLoader: (_) async => validRenderJson(),
    ).resolve(bootstrap);

    expect(result, isNotNull);
    expect(result!.sessionSource, SessionConfigSource.asset);
    expect(await c.read(bootstrap), isNull);
  });

  test('all sources invalid returns null', () async {
    final c = cache();
    await c.write(bootstrap, 'not-json');

    final result = await resolver(
      cacheOverride: c,
      fetcher: fetcherReturning('{"schemaVersion":"1.0"}'),
      assetLoader: (_) async => {'schemaVersion': '1.0'},
    ).resolve(bootstrap);

    expect(result, isNull);
    expect(await c.read(bootstrap), isNull);
  });

  test('malformed JSON in cache is deleted and falls through', () async {
    final c = cache();
    await c.write(bootstrap, '{broken');

    final remoteJson = validRawJson();
    final result = await resolver(
      cacheOverride: c,
      fetcher: fetcherReturning(remoteJson),
    ).resolve(bootstrap);

    expect(result!.sessionSource, SessionConfigSource.remote);
    expect(await c.read(bootstrap), remoteJson);
  });

  test('resolveLocal returns asset source for valid bundled config', () async {
    final result = await resolver(
      assetLoader: (_) async => validRenderJson(),
    ).resolveLocal(bootstrap);

    expect(result, isNotNull);
    expect(result!.sessionSource, SessionConfigSource.asset);
  });

  test('resolveLocal returns null when asset invalid', () async {
    final result = await resolver(
      assetLoader: (_) async => {'schemaVersion': '1.0'},
    ).resolveLocal(bootstrap);

    expect(result, isNull);
  });
}
