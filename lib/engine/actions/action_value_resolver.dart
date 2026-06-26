import '../form/form_state_store.dart';
import '../tree/parsers/data_context_path.dart';

/// Resolves JSON action values: plain strings or `{ source, field }` maps.
class ActionValueResolver {
  ActionValueResolver({FormStateStore? formState}) : _formState = formState;

  final FormStateStore? _formState;

  String? resolveString(dynamic spec, {Map<String, dynamic>? dataContext}) {
    if (spec == null) return null;
    if (spec is String) {
      final trimmed = spec.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    if (spec is! Map) return spec.toString().trim();

    final source = (spec['source'] as String?)?.toLowerCase();
    final field = spec['field'] as String?;
    switch (source) {
      case 'form':
        if (field != null && _formState != null) {
          final value = _formState.valueFor(field);
          return value?.toString().trim();
        }
        return null;
      case 'app':
        if (field != null && dataContext != null) {
          final app = dataContext['app'];
          if (app is Map<String, dynamic>) {
            final value = app[field];
            return value?.toString().trim();
          }
        }
        return null;
      case 'value':
        return spec['value']?.toString().trim();
      case 'context':
      case 'datacontext':
        if (field != null && field.isNotEmpty) {
          final value = resolveDataContextPath(dataContext, field);
          return value?.toString().trim();
        }
        return null;
      default:
        return spec['value']?.toString().trim();
    }
  }
}
