import 'package:flutter/material.dart';

import '../../../config/component_config.dart';
import '../../actions/action_dispatcher.dart';
import '../../component_renderer/component_renderer.dart';
import '../../form/form_state_store.dart';
import '../../theme/engine_theme.dart';
import '../parsers/data_context_path.dart';
import '../parsers/property_parsers.dart';

const _kDefaultRequiredMessage = 'هذا الحقل مطلوب';
const _kDefaultEmptyHint = 'لا توجد خيارات';

class _DropdownItem {
  const _DropdownItem({
    required this.label,
    required this.value,
    required this.index,
    this.disabled = false,
  });

  final String label;
  final String value;
  final int index;
  final bool disabled;
}

/// Single-choice dropdown for filters and forms.
///
/// Static items: [data.items]. Dynamic: [itemsPath] with optional
/// [itemLabelPath] / [itemValuePath]. Selection stored in [FormStateStore]
/// under [id]. [tap] / [onChanged] receive `dataContext['tap']` with
/// `{ value, index, label }`.
class DropdownRenderer implements ComponentRenderer {
  @override
  Widget render(
    ComponentConfig config, {
    required ComponentWidgetBuilder buildChild,
    Map<String, dynamic>? dataContext,
  }) {
    final properties = config.properties;
    final fieldId = properties['id'] as String? ?? '';
    final controllerId = properties['controllerId'] as String?;
    final effectiveKey = (controllerId ?? fieldId).isEmpty
        ? 'dropdown_${config.hashCode}'
        : (controllerId ?? fieldId);

    final items = _resolveItems(properties, dataContext);
    final theme = EngineTheme.fromDataContext(dataContext);
    final formState = _formStateFrom(dataContext);

    final label = properties['label'] as String?;
    final hint = properties['hint'] as String?;
    final helper = properties['helper'] as String?;
    final error = properties['error'] as String?;
    final emptyHint = properties['emptyHint'] as String? ?? _kDefaultEmptyHint;

    final enabled = properties['enabled'] != false && items.isNotEmpty;
    final readOnly = properties['readOnly'] == true;
    final isDense = properties['isDense'] != false;
    final isExpanded = properties['isExpanded'] == true;

    final requiredField =
        properties['required'] == true ||
        properties['validateRequired'] == true;
    final requiredMessage =
        properties['requiredMessage'] as String? ?? _kDefaultRequiredMessage;
    final validationMessage = properties['validationMessage'] as String?;

    final margin = PropertyParsers.parseEdgeInsets(properties['margin']);
    final width = PropertyParsers.parseDouble(properties['width']);
    final contentPadding = PropertyParsers.parseEdgeInsets(
      properties['padding'],
    );
    final color = PropertyParsers.parseColor(properties['color'] as String?);
    final borderRadius = PropertyParsers.parseBorderRadius(
      properties['borderRadius'],
    );
    final border = _parseBorder(properties['border'], dataContext);

    final tapAction = properties['tap'];
    final tapMap = tapAction is Map<String, dynamic> ? tapAction : null;
    final onChangedAction = properties['onChanged'] as Map<String, dynamic>?;

    final semanticsLabel = properties['semanticsLabel'] as String? ?? label;

    final initialValue = _resolveSelectedValue(
      properties: properties,
      dataContext: dataContext,
      formState: formState,
      effectiveKey: effectiveKey,
      items: items,
    );

    if (formState != null && initialValue != null) {
      formState.updateValue(effectiveKey, initialValue);
    }

    return _EngineDropdownField(
      effectiveKey: effectiveKey,
      fieldId: fieldId,
      items: items,
      initialValue: initialValue,
      label: label,
      hint: items.isEmpty ? emptyHint : hint,
      helper: helper,
      staticError: error,
      enabled: enabled,
      readOnly: readOnly,
      isDense: isDense,
      isExpanded: isExpanded,
      requiredField: requiredField,
      requiredMessage: requiredMessage,
      validationMessage: validationMessage,
      theme: theme,
      fillColor: color,
      borderRadius: borderRadius,
      border: border,
      contentPadding: contentPadding,
      margin: margin,
      width: width,
      tapMap: tapMap,
      onChangedAction: onChangedAction,
      formState: formState,
      dataContext: dataContext,
      semanticsLabel: semanticsLabel,
    );
  }

  List<_DropdownItem> _resolveItems(
    Map<String, dynamic> properties,
    Map<String, dynamic>? dataContext,
  ) {
    final itemsPath = properties['itemsPath'] as String?;
    if (itemsPath != null && itemsPath.isNotEmpty) {
      final raw = resolveDataContextPath(dataContext, itemsPath);
      return _mapDynamicItems(raw, properties);
    }

    final data = properties['data'];
    if (data is Map) {
      final rawItems = data['items'];
      if (rawItems is List) {
        return _parseStaticItems(rawItems);
      }
    }
    return const [];
  }

  List<_DropdownItem> _parseStaticItems(List<dynamic> rawItems) {
    final result = <_DropdownItem>[];
    for (var i = 0; i < rawItems.length; i++) {
      final entry = rawItems[i];
      if (entry is! Map) continue;
      final label = entry['label']?.toString() ?? '';
      final value = entry['value']?.toString() ?? label;
      if (value.isEmpty) continue;
      final indexRaw = entry['index'];
      final index = indexRaw is int
          ? indexRaw
          : indexRaw is num
          ? indexRaw.toInt()
          : i;
      final disabled = entry['disabled'] == true;
      result.add(
        _DropdownItem(
          label: label.isEmpty ? value : label,
          value: value,
          index: index,
          disabled: disabled,
        ),
      );
    }
    return result;
  }

  List<_DropdownItem> _mapDynamicItems(
    dynamic raw,
    Map<String, dynamic> properties,
  ) {
    if (raw is! List) return const [];
    final labelPath = properties['itemLabelPath'] as String?;
    final valuePath = properties['itemValuePath'] as String?;

    final result = <_DropdownItem>[];
    for (var i = 0; i < raw.length; i++) {
      final entry = raw[i];
      if (entry is! Map) continue;
      final label = _readItemField(entry, labelPath, const [
        'label',
        'name',
        'title',
      ]);
      final value = _readItemField(entry, valuePath, const [
        'value',
        'slug',
        'id',
      ]);
      if (value.isEmpty) continue;
      result.add(
        _DropdownItem(
          label: label.isEmpty ? value : label,
          value: value,
          index: i,
          disabled: entry['disabled'] == true,
        ),
      );
    }
    return result;
  }

  String _readItemField(
    Map<dynamic, dynamic> entry,
    String? explicitPath,
    List<String> fallbacks,
  ) {
    if (explicitPath != null && explicitPath.isNotEmpty) {
      final v = entry[explicitPath]?.toString().trim() ?? '';
      if (v.isNotEmpty) return v;
    }
    for (final key in fallbacks) {
      final v = entry[key]?.toString().trim() ?? '';
      if (v.isNotEmpty) return v;
    }
    return '';
  }

  String? _resolveSelectedValue({
    required Map<String, dynamic> properties,
    required Map<String, dynamic>? dataContext,
    required FormStateStore? formState,
    required String effectiveKey,
    required List<_DropdownItem> items,
  }) {
    if (formState != null) {
      final stored = formState.valueFor(effectiveKey);
      if (stored != null && stored.isNotEmpty) {
        return _valueIfInItems(stored, items);
      }
    }

    final staticValue = properties['value']?.toString();
    if (staticValue != null && staticValue.isNotEmpty) {
      return _valueIfInItems(staticValue, items);
    }

    final valuePath = properties['valuePath'] as String?;
    if (valuePath != null && valuePath.isNotEmpty) {
      final fromContext = resolveDataContextPath(dataContext, valuePath);
      final text = fromContext?.toString() ?? '';
      if (text.isNotEmpty) {
        return _valueIfInItems(text, items);
      }
    }

    final index = _resolveSelectedIndex(properties, dataContext);
    if (index >= 0 && index < items.length) {
      return items[index].value;
    }
    return null;
  }

  String? _valueIfInItems(String value, List<_DropdownItem> items) {
    for (final item in items) {
      if (item.value == value) return value;
    }
    return items.isEmpty ? null : value;
  }

  int _resolveSelectedIndex(
    Map<String, dynamic> properties,
    Map<String, dynamic>? dataContext,
  ) {
    final path = properties['selectedIndexPath'] as String?;
    if (path != null && path.isNotEmpty) {
      final fromContext = resolveDataContextPath(dataContext, path);
      if (fromContext is int) return fromContext;
      if (fromContext is num) return fromContext.toInt();
      if (fromContext is String) {
        final parsed = int.tryParse(fromContext);
        if (parsed != null) return parsed;
      }
    }
    final staticIndex = properties['selectedIndex'];
    if (staticIndex is int) return staticIndex;
    if (staticIndex is num) return staticIndex.toInt();
    if (staticIndex is String) return int.tryParse(staticIndex) ?? -1;
    return -1;
  }

  FormStateStore? _formStateFrom(Map<String, dynamic>? dataContext) {
    final existing = dataContext?[FormStateStore.contextKey];
    return existing is FormStateStore ? existing : null;
  }

  Border? _parseBorder(dynamic v, Map<String, dynamic>? dataContext) {
    if (v is! Map) return null;
    final width = (v['width'] as num?)?.toDouble() ?? 1.0;
    final theme = EngineTheme.fromDataContext(dataContext);
    final color =
        PropertyParsers.parseColor(v['color'] as String?) ??
        theme?.inputBorderColor ??
        const Color(0xFFE2E8F0);
    return Border.all(width: width, color: color);
  }
}

class _EngineDropdownField extends StatefulWidget {
  const _EngineDropdownField({
    required this.effectiveKey,
    required this.fieldId,
    required this.items,
    required this.initialValue,
    required this.label,
    required this.hint,
    required this.helper,
    required this.staticError,
    required this.enabled,
    required this.readOnly,
    required this.isDense,
    required this.isExpanded,
    required this.requiredField,
    required this.requiredMessage,
    required this.validationMessage,
    required this.theme,
    required this.fillColor,
    required this.borderRadius,
    required this.border,
    required this.contentPadding,
    required this.margin,
    required this.width,
    required this.tapMap,
    required this.onChangedAction,
    required this.formState,
    required this.dataContext,
    required this.semanticsLabel,
  });

  final String effectiveKey;
  final String fieldId;
  final List<_DropdownItem> items;
  final String? initialValue;
  final String? label;
  final String? hint;
  final String? helper;
  final String? staticError;
  final bool enabled;
  final bool readOnly;
  final bool isDense;
  final bool isExpanded;
  final bool requiredField;
  final String requiredMessage;
  final String? validationMessage;
  final EngineTheme? theme;
  final Color? fillColor;
  final BorderRadius? borderRadius;
  final Border? border;
  final EdgeInsets? contentPadding;
  final EdgeInsets? margin;
  final double? width;
  final Map<String, dynamic>? tapMap;
  final Map<String, dynamic>? onChangedAction;
  final FormStateStore? formState;
  final Map<String, dynamic>? dataContext;
  final String? semanticsLabel;

  @override
  State<_EngineDropdownField> createState() => _EngineDropdownFieldState();
}

class _EngineDropdownFieldState extends State<_EngineDropdownField> {
  String? _selectedValue;

  @override
  void initState() {
    super.initState();
    _selectedValue = widget.initialValue;
  }

  @override
  void didUpdateWidget(covariant _EngineDropdownField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != oldWidget.initialValue &&
        widget.initialValue != _selectedValue) {
      _selectedValue = widget.initialValue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    final menuItems = <DropdownMenuItem<String>>[
      for (final item in items)
        DropdownMenuItem<String>(
          value: item.value,
          enabled: !item.disabled,
          child: Text(item.label, overflow: TextOverflow.ellipsis, maxLines: 1),
        ),
    ];

    final decoration = _buildDecoration(
      theme: widget.theme,
      label: widget.label,
      hint: widget.hint,
      helper: widget.helper,
      error: widget.requiredField ? null : widget.staticError,
      borderRadius: widget.borderRadius,
      fillColor: widget.fillColor,
      border: widget.border,
      contentPadding: widget.contentPadding,
    );

    final validator = widget.requiredField
        ? (String? value) {
            if (value == null || value.isEmpty) {
              return widget.validationMessage ?? widget.requiredMessage;
            }
            return null;
          }
        : null;

    final compact = _isCompactFilter();
    final inForm = context.findAncestorWidgetOfExactType<Form>() != null;
    final useFormField =
        !compact && (validator != null || inForm || _hasDecoratedLabel());

    Widget field;
    if (widget.readOnly) {
      final label = _labelForValue(_selectedValue, items);
      field = InputDecorator(
        decoration: decoration,
        isEmpty: label.isEmpty,
        child: Text(
          label.isEmpty ? (widget.hint ?? '') : label,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
          style: TextStyle(
            color: widget.theme?.textColor ?? const Color(0xFF0F172A),
          ),
        ),
      );
    } else if (useFormField) {
      field = DropdownButtonFormField<String>(
        initialValue:
            _selectedValue != null && _valueInItems(_selectedValue!, items)
            ? _selectedValue
            : null,
        items: menuItems,
        isExpanded: widget.isExpanded,
        isDense: widget.isDense,
        decoration: decoration,
        hint: widget.hint != null ? Text(widget.hint!) : null,
        autovalidateMode: validator != null
            ? AutovalidateMode.onUserInteraction
            : AutovalidateMode.disabled,
        validator: validator,
        onChanged: widget.enabled
            ? (value) => _handleChange(context, value, items)
            : null,
      );
    } else if (compact) {
      field = IntrinsicWidth(
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value:
                _selectedValue != null && _valueInItems(_selectedValue!, items)
                ? _selectedValue
                : null,
            items: menuItems,
            isDense: widget.isDense,
            hint: widget.hint != null ? Text(widget.hint!) : null,
            onChanged: widget.enabled
                ? (value) => _handleChange(context, value, items)
                : null,
          ),
        ),
      );
    } else {
      field = InputDecorator(
        decoration: decoration,
        isEmpty: _selectedValue == null,
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value:
                _selectedValue != null && _valueInItems(_selectedValue!, items)
                ? _selectedValue
                : null,
            items: menuItems,
            isExpanded: widget.isExpanded,
            isDense: widget.isDense,
            hint: widget.hint != null ? Text(widget.hint!) : null,
            onChanged: widget.enabled
                ? (value) => _handleChange(context, value, items)
                : null,
          ),
        ),
      );
    }

    final needsMaterial =
        context.findAncestorWidgetOfExactType<Material>() == null;
    Widget result = needsMaterial
        ? Material(type: MaterialType.transparency, child: field)
        : field;
    if (widget.margin != null || widget.width != null) {
      result = Container(
        width: widget.width,
        margin: widget.margin,
        child: result,
      );
    }

    return Semantics(
      label: widget.semanticsLabel,
      enabled: widget.enabled,
      child: result,
    );
  }

  bool _isCompactFilter() {
    final hasLabel = widget.label != null && widget.label!.isNotEmpty;
    final hasHelper = widget.helper != null && widget.helper!.isNotEmpty;
    final hasError =
        widget.staticError != null && widget.staticError!.isNotEmpty;
    return !hasLabel && !hasHelper && !hasError && !widget.requiredField;
  }

  bool _hasDecoratedLabel() {
    return widget.label != null && widget.label!.isNotEmpty;
  }

  bool _valueInItems(String value, List<_DropdownItem> items) {
    return items.any((item) => item.value == value);
  }

  String _labelForValue(String? value, List<_DropdownItem> items) {
    if (value == null) return '';
    for (final item in items) {
      if (item.value == value) return item.label;
    }
    return value;
  }

  void _handleChange(
    BuildContext context,
    String? value,
    List<_DropdownItem> items,
  ) {
    if (value == null) return;
    setState(() => _selectedValue = value);

    if (widget.formState != null) {
      widget.formState!.updateValue(widget.effectiveKey, value);
    }

    _DropdownItem? matched;
    for (final item in items) {
      if (item.value == value) {
        matched = item;
        break;
      }
    }

    final dispatcher = _resolveDispatcher(widget.dataContext, context);
    if (dispatcher == null) return;

    if (widget.onChangedAction != null) {
      dispatcher.dispatch(
        widget.onChangedAction!,
        value: value,
        fieldId: widget.fieldId,
      );
    }

    if (widget.tapMap != null) {
      final merged = Map<String, dynamic>.from(
        widget.dataContext ?? <String, dynamic>{},
      );
      merged['tap'] = {
        'value': value,
        'index': matched?.index ?? 0,
        'label': matched?.label ?? value,
      };
      dispatcher.dispatch(widget.tapMap!, dataContext: merged);
    }
  }

  EngineActionDispatcher? _resolveDispatcher(
    Map<String, dynamic>? dataContext,
    BuildContext context,
  ) {
    if (dataContext != null) {
      final existing = dataContext[EngineActionDispatcher.contextKey];
      if (existing is EngineActionDispatcher) return existing;
    }
    final dispatcher = EngineActionDispatcher(context: context);
    dataContext?[EngineActionDispatcher.contextKey] = dispatcher;
    return dispatcher;
  }

  InputDecoration _buildDecoration({
    required EngineTheme? theme,
    required String? label,
    required String? hint,
    required String? helper,
    required String? error,
    required BorderRadius? borderRadius,
    required Color? fillColor,
    required Border? border,
    required EdgeInsets? contentPadding,
  }) {
    final radius = borderRadius ?? BorderRadius.circular(theme?.radiusMd ?? 12);
    final fill = fillColor ?? theme?.surfaceColor ?? const Color(0xFFF8FAFC);
    final defaultPadding =
        contentPadding ??
        const EdgeInsets.symmetric(horizontal: 12, vertical: 8);

    final borderSide = border != null
        ? BorderSide(color: border.top.color, width: border.top.width)
        : BorderSide(color: theme?.inputBorderColor ?? const Color(0xFFE2E8F0));

    final enabledOutline = OutlineInputBorder(
      borderRadius: radius,
      borderSide: borderSide,
    );
    final focusedOutline = OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(
        color: theme?.primaryColor ?? const Color(0xFF1D4ED8),
        width: 2,
      ),
    );
    final errorColor = theme?.errorColor ?? const Color(0xFFDC2626);
    final errorOutline = OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: errorColor),
    );

    return InputDecoration(
      labelText: label,
      hintText: hint,
      helperText: helper,
      errorText: error,
      filled: true,
      fillColor: fill,
      contentPadding: defaultPadding,
      border: enabledOutline,
      enabledBorder: enabledOutline,
      focusedBorder: focusedOutline,
      errorBorder: errorOutline,
      focusedErrorBorder: errorOutline,
      disabledBorder: enabledOutline,
    );
  }
}
