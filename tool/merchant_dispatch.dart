/// Maps and validates GitHub `repository_dispatch` `client_payload` (snake_case)
/// into a merchant build manifest (camelCase) for [apply_merchant_build.dart].
library;

import 'dart:convert';

const merchantDispatchRequiredKeys = <String>[
  'app_name',
  'bundle_id',
  'api_base_url',
  'tenant_id',
  'tenant_slug',
  'config_mode',
  'variant_id',
];

const merchantDispatchCamelCaseMistakes = <String, String>{
  'appName': 'app_name',
  'bundleId': 'bundle_id',
  'apiBaseUrl': 'api_base_url',
  'tenantId': 'tenant_id',
  'tenantSlug': 'tenant_slug',
  'configMode': 'config_mode',
  'variantId': 'variant_id',
  'configUrl': 'config_url',
  'iconUrl': 'icon_url',
  'buildNumber': 'build_number',
};

/// Validates [payload] from `github.event.client_payload`.
List<String> validateMerchantDispatchPayload(Map<String, dynamic> payload) {
  final errors = <String>[];

  for (final mistake in merchantDispatchCamelCaseMistakes.entries) {
    if (payload.containsKey(mistake.key)) {
      errors.add(
        'Use snake_case "${mistake.value}" instead of camelCase "${mistake.key}"',
      );
    }
  }

  for (final key in merchantDispatchRequiredKeys) {
    final value = payload[key];
    if (value == null || value.toString().trim().isEmpty) {
      errors.add('Missing required client_payload field: $key');
    }
  }

  final configMode = payload['config_mode']?.toString().trim() ?? '';
  if (configMode == 'remoteStorage') {
    final configUrl = payload['config_url'];
    if (configUrl == null || configUrl.toString().trim().isEmpty) {
      errors.add('config_url is required when config_mode is remoteStorage');
    }
  }

  final bundleId = payload['bundle_id']?.toString().trim() ?? '';
  if (bundleId.isNotEmpty &&
      !RegExp(r'^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$').hasMatch(bundleId)) {
    errors.add(
      'bundle_id must be lowercase reverse-domain notation (e.g. com.merchant.shop)',
    );
  }

  return errors;
}

/// Builds merchant-build manifest JSON from dispatch payload.
Map<String, dynamic> merchantManifestFromDispatch(
  Map<String, dynamic> payload, {
  String defaultVersion = '1.0.0',
  int defaultBuildNumber = 1,
}) {
  final version = _optionalString(payload['version']) ?? defaultVersion;
  final buildNumber = _parseBuildNumber(payload['build_number']) ?? defaultBuildNumber;

  return <String, dynamic>{
    'appName': _requiredString(payload, 'app_name'),
    'bundleId': _requiredString(payload, 'bundle_id'),
    'apiBaseUrl': _requiredString(payload, 'api_base_url'),
    'tenantId': _requiredString(payload, 'tenant_id'),
    'tenantSlug': _requiredString(payload, 'tenant_slug'),
    'configMode': _requiredString(payload, 'config_mode'),
    'variantId': _requiredString(payload, 'variant_id'),
    'configUrl': _optionalString(payload['config_url']),
    'iconUrl': _optionalString(payload['icon_url']),
    'version': version,
    'buildNumber': buildNumber,
  };
}

/// Unwraps a full repository_dispatch body, raw `client_payload`, or
/// `client_payload.app_data` (JSON string from some builders).
Map<String, dynamic> unwrapDispatchPayload(Map<String, dynamic> input) {
  Map<String, dynamic> current = input;

  final nested = input['client_payload'];
  if (nested is Map<String, dynamic>) {
    current = nested;
  } else if (nested is Map) {
    current = Map<String, dynamic>.from(nested);
  }

  return _unwrapAppDataIfPresent(current);
}

Map<String, dynamic> _unwrapAppDataIfPresent(Map<String, dynamic> payload) {
  final appData = payload['app_data'];
  if (appData == null) return payload;

  if (appData is String && appData.trim().isNotEmpty) {
    final decoded = jsonDecode(appData);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
  }
  if (appData is Map<String, dynamic>) return appData;
  if (appData is Map) return Map<String, dynamic>.from(appData);

  return payload;
}

String _requiredString(Map<String, dynamic> json, String key) {
  return json[key]!.toString().trim();
}

String? _optionalString(Object? value) {
  if (value == null) return null;
  final trimmed = value.toString().trim();
  return trimmed.isEmpty ? null : trimmed;
}

int? _parseBuildNumber(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString().trim());
}
