import 'package:flutter/foundation.dart';

import '../config/bootstrap_config.dart';
import '../config/config_mode.dart';
import '../config/config_source.dart';
import '../config/local_asset_config_source.dart';
import '../config/mobile_app_config.dart';
import '../config/session_config_resolver.dart';
import 'config_pipeline_result.dart';

/// Orchestrates bootstrap → render JSON → [MobileAppConfig] at startup.
class ConfigPipeline {
  ConfigPipeline._();

  /// Loads bootstrap, resolves config source, and parses [MobileAppConfig].
  static Future<ConfigPipelineResult> initialize() {
    return initializeWith();
  }

  @visibleForTesting
  static Future<ConfigPipelineResult> initializeWith({
    AppConfigSource? sourceOverride,
    BootstrapConfig? bootstrapOverride,
    SessionConfigResolver? resolverOverride,
  }) async {
    BootstrapConfig bootstrap;
    try {
      bootstrap =
          bootstrapOverride ??
          await LocalAssetConfigSource.loadBootstrap(
            allowLocalFallback: kDebugMode,
          );
    } catch (e, st) {
      debugPrint('[ConfigPipeline] ❌ Failed to load bootstrap: $e\n$st');
      return ConfigPipelineResult(
        bootstrap: const BootstrapConfig(
          schemaVersion: '1.0',
          configMode: ConfigMode.local,
          variantId: '',
          appName: 'App',
          bundleId: '',
          apiBaseUrl: '',
        ),
        loadError: 'Failed to load bootstrap: $e',
      );
    }

    if (sourceOverride != null) {
      return _initializeWithSourceOverride(bootstrap, sourceOverride);
    }

    final resolver = resolverOverride ?? SessionConfigResolver();
    try {
      final SessionConfigResult? resolved;
      if (bootstrap.configMode == ConfigMode.local) {
        resolved = await resolver.resolveLocal(bootstrap);
      } else {
        resolved = await resolver.resolve(bootstrap);
      }

      if (resolved == null) {
        return ConfigPipelineResult(
          bootstrap: bootstrap,
          loadError: 'Failed to load valid app configuration.',
        );
      }

      final mobileConfig = MobileAppConfig.fromBootstrapAndRender(
        bootstrap: bootstrap,
        renderJson: resolved.renderJson,
      );
      debugPrint(
        '[ConfigPipeline] ✅ Loaded config: ${mobileConfig.appName} '
        '(${mobileConfig.navigation.tabs.length} tabs, '
        '${mobileConfig.pageRoutes.length} pages, '
        'mode=${bootstrap.configMode.toJson()}, '
        'source=${resolved.sessionSource.name}, '
        'variant=${bootstrap.variantId})',
      );
      return ConfigPipelineResult(
        bootstrap: bootstrap,
        mobileAppConfig: mobileConfig,
        rawConfigJson: resolved.renderJson,
        sessionSource: resolved.sessionSource,
        usedRemoteConfig: bootstrap.configMode != ConfigMode.local,
      );
    } catch (e, st) {
      debugPrint('[ConfigPipeline] ❌ Failed to load full config: $e\n$st');
      return ConfigPipelineResult(
        bootstrap: bootstrap,
        loadError: e.toString(),
      );
    }
  }

  static Future<ConfigPipelineResult> _initializeWithSourceOverride(
    BootstrapConfig bootstrap,
    AppConfigSource source,
  ) async {
    try {
      final renderJson = await source.loadFullConfig(bootstrap);
      final mobileConfig = MobileAppConfig.fromBootstrapAndRender(
        bootstrap: bootstrap,
        renderJson: renderJson,
      );
      debugPrint(
        '[ConfigPipeline] ✅ Loaded config (sourceOverride): '
        '${mobileConfig.appName}',
      );
      return ConfigPipelineResult(
        bootstrap: bootstrap,
        mobileAppConfig: mobileConfig,
        rawConfigJson: renderJson,
        usedRemoteConfig: bootstrap.configMode != ConfigMode.local,
      );
    } catch (e, st) {
      debugPrint('[ConfigPipeline] ❌ Failed to load full config: $e\n$st');
      return ConfigPipelineResult(
        bootstrap: bootstrap,
        loadError: e.toString(),
      );
    }
  }
}
