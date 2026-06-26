import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:sooq_merchant/core/network/network_config.dart';
import 'package:sooq_merchant/core/network/remote_image_url.dart';
import 'package:sooq_merchant/core/utils/constants.dart';

void main() {
  final getIt = GetIt.instance;

  tearDown(() {
    if (getIt.isRegistered<NetworkConfig>()) {
      getIt.unregister<NetworkConfig>();
    }
  });

  test('absolute https passes through unchanged', () {
    expect(
      resolveRemoteImageUrl('https://cdn.example.com/a.jpg'),
      'https://cdn.example.com/a.jpg',
    );
  });

  test('empty string returns empty', () {
    expect(resolveRemoteImageUrl(''), '');
    expect(resolveRemoteImageUrl('   '), '');
  });

  test('relative path prefixes assetBaseUrl from NetworkConfig', () {
    getIt.registerSingleton<NetworkConfig>(
      const NetworkConfig(baseUrl: 'https://sooq.up.railway.app/api/v1'),
    );
    expect(
      resolveRemoteImageUrl('/uploads/foo.png'),
      'https://sooq.up.railway.app/uploads/foo.png',
    );
  });

  test(
    'relative path uses kBaseUrlAsset when NetworkConfig is not registered',
    () {
      expect(
        resolveRemoteImageUrl('/uploads/foo.png'),
        '$kBaseUrlAsset/uploads/foo.png',
      );
    },
  );

  test('httpHeadersForImageUrl is null for third-party hosts', () {
    expect(
      httpHeadersForImageUrl('https://placehold.co/200x200/png?text=P01'),
      isNull,
    );
    expect(
      httpHeadersForImageUrl('https://images.unsplash.com/photo-1'),
      isNull,
    );
  });

  test('httpHeadersForImageUrl applies to merchant asset host', () {
    getIt.registerSingleton<NetworkConfig>(
      const NetworkConfig(baseUrl: 'https://sooq.up.railway.app/api/v1'),
    );
    expect(
      httpHeadersForImageUrl('https://sooq.up.railway.app/uploads/foo.png'),
      kRemoteImageHttpHeaders,
    );
  });

  test(
    'fullSizeFallbackForGeneratedThumbnail strips _150/_300/_600 png suffix',
    () {
      const base = 'https://cdn.example.com/media/2026/06/photo-id';
      expect(
        fullSizeFallbackForGeneratedThumbnail('${base}_150.png'),
        '$base.jpg',
      );
      expect(
        fullSizeFallbackForGeneratedThumbnail('${base}_300.png'),
        '$base.jpg',
      );
      expect(
        fullSizeFallbackForGeneratedThumbnail('${base}_600.png'),
        '$base.jpg',
      );
    },
  );

  test(
    'fullSizeFallbackForGeneratedThumbnail returns null for non-thumbnail urls',
    () {
      expect(
        fullSizeFallbackForGeneratedThumbnail(
          'https://cdn.example.com/media/photo.jpg',
        ),
        isNull,
      );
      expect(fullSizeFallbackForGeneratedThumbnail(''), isNull);
    },
  );
}
