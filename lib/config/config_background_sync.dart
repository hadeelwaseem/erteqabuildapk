import 'dart:async';

import 'package:flutter/foundation.dart';

import '../engine/config_pipeline_result.dart';
import 'bootstrap_config.dart';
import 'config_cache.dart';
import 'config_mode.dart';
import 'config_validator.dart';
import 'remote_config_fetcher.dart';

/// Post-startup remote config refresh — updates disk cache only for next launch.
class ConfigBackgroundSync {
  ConfigBackgroundSync._();

  static const backgroundTimeout = Duration(seconds: 20);

  /// Schedules a non-blocking background fetch for remote config modes.
  ///
  /// Never mutates [ConfigPipelineResult.rawConfigJson], router, or DI.
  static void scheduleIfNeeded(
    ConfigPipelineResult pipelineResult, {
    RemoteConfigFetcher? fetcher,
    ConfigCache? cache,
  }) {
    if (pipelineResult.bootstrap.configMode == ConfigMode.local) {
      return;
    }

    unawaited(sync(pipelineResult.bootstrap, fetcher: fetcher, cache: cache));
  }

  @visibleForTesting
  static Future<bool> sync(
    BootstrapConfig bootstrap, {
    RemoteConfigFetcher? fetcher,
    ConfigCache? cache,
  }) async {
    if (bootstrap.configMode == ConfigMode.local) {
      return false;
    }

    try {
      final remoteFetcher = fetcher ?? RemoteConfigFetcher();
      final configCache = cache ?? ConfigCache();

      final raw = await remoteFetcher.fetch(
        bootstrap,
        timeout: backgroundTimeout,
      );
      if (raw == null) {
        debugPrint('[ConfigBackgroundSync] remote fetch failed');
        return false;
      }

      final validation = ConfigValidator.validateString(bootstrap, raw);
      if (!validation.valid) {
        debugPrint(
          '[ConfigBackgroundSync] invalid remote config ignored: '
          '${validation.errorMessage}',
        );
        return false;
      }

      await configCache.write(bootstrap, raw);
      final slug = bootstrap.tenantSlug ?? bootstrap.variantId;
      debugPrint(
        '[ConfigBackgroundSync] cache updated for $slug (next launch)',
      );
      return true;
    } catch (e, st) {
      debugPrint('[ConfigBackgroundSync] sync failed: $e\n$st');
      return false;
    }
  }
}
