import 'package:flutter/material.dart';

import '../../../config/component_config.dart';
import '../../actions/action_dispatcher.dart';
import '../../component_renderer/component_renderer.dart';
import '../../form/form_state_store.dart';
import '../../theme/engine_theme.dart';
import '../../theme/shadow_parser.dart';
import '../parsers/property_parsers.dart';

/// Default required-field message when JSON omits [requiredMessage].
const _kDefaultRequiredMessage = 'هذا الحقل مطلوب';

class TextFormFieldRenderer implements ComponentRenderer {
  static const _minTapTarget = 48.0;

  @override
  Widget render(
    ComponentConfig config, {
    required ComponentWidgetBuilder buildChild,
    Map<String, dynamic>? dataContext,
  }) {
    final properties = config.properties;
    final fieldId = properties['id'] as String? ?? '';
    final controllerId = properties['controllerId'] as String?;
    final initialValue =
        properties['initialValue'] as String? ?? properties['value'] as String?;

    final label = properties['label'] as String?;
    final hint = properties['hint'] as String?;
    final helper = properties['helper'] as String?;
    final error = properties['error'] as String?;
    final prefixText = properties['prefixText'] as String?;
    final suffixText = properties['suffixText'] as String?;
    final prefixIconName = properties['prefixIcon'] as String?;
    final suffixIconName = properties['suffixIcon'] as String?;
    final clearable = properties['clearable'] == true;
    final clearIconName = properties['clearIcon'] as String? ?? 'close';

    final autofocus = properties['autofocus'] == true;
    final enabled = properties['enabled'] != false;
    final readOnly = properties['readOnly'] == true;
    final obscureText = properties['obscureText'] == true;
    final autocorrect = properties['autocorrect'] != false;
    final enableSuggestions = properties['enableSuggestions'] != false;
    final expands = properties['expands'] == true;

    final textInputAction = PropertyParsers.parseTextInputAction(
      properties['textInputAction'] as String?,
    );
    final textCapitalization = PropertyParsers.parseTextCapitalization(
      properties['textCapitalization'] as String?,
    );
    final explicitTextAlign = properties['textAlign'] as String?;
    final keyboardType = PropertyParsers.parseKeyboardType(
      properties['keyboardType'] as String?,
    );
    final isPhoneKeyboard = keyboardType == TextInputType.phone;
    final textDirection =
        PropertyParsers.parseTextDirection(
          properties['textDirection'] as String?,
        ) ??
        (isPhoneKeyboard ? TextDirection.ltr : null);
    final textAlign =
        PropertyParsers.parseTextAlign(explicitTextAlign) ??
        (textDirection == TextDirection.ltr ? TextAlign.left : null);

    final inputFormatters = PropertyParsers.parseInputFormatters(
      properties['inputFormatters'],
    );

    final maxLines = _parseInt(properties['maxLines']);
    final minLines = _parseInt(properties['minLines']);
    final maxLength = _parseInt(properties['maxLength']);

    final requiredField =
        properties['required'] == true ||
        properties['validateRequired'] == true;
    final validateEmail = properties['validateEmail'] == true;
    final validatePhone = properties['validatePhone'] == true;
    final validatePassword = properties['validatePassword'] == true;
    final validateMinLength = _parseInt(properties['validateMinLength']);
    final validateMaxLength = _parseInt(properties['validateMaxLength']);
    final validatePattern = properties['validatePattern'] as String?;
    final validationMessage = properties['validationMessage'] as String?;
    final requiredMessage =
        properties['requiredMessage'] as String? ?? _kDefaultRequiredMessage;

    final onChangedAction = properties['onChanged'] as Map<String, dynamic>?;
    final onSubmittedAction =
        properties['onSubmitted'] as Map<String, dynamic>?;

    final margin = PropertyParsers.parseEdgeInsets(properties['margin']);
    final color = PropertyParsers.parseColor(properties['color'] as String?);
    final borderRadius = PropertyParsers.parseBorderRadius(
      properties['borderRadius'],
    );
    final width = PropertyParsers.parseDouble(properties['width']);
    final height = PropertyParsers.parseDouble(properties['height']);
    final border = _parseBorder(properties['border'], dataContext);
    final shadow = ShadowParser.resolveBoxShadowPreset(
      properties,
      dataContext,
      componentType: 'textFormField',
    );

    final theme = EngineTheme.fromDataContext(dataContext);
    final hasValidation = _hasValidation(
      requiredField,
      validateEmail,
      validatePhone,
      validatePassword,
      validateMinLength,
      validateMaxLength,
      validatePattern,
    );
    final validator = _buildValidator(
      requiredField: requiredField,
      requiredMessage: requiredMessage,
      validateEmail: validateEmail,
      validatePhone: validatePhone,
      validatePassword: validatePassword,
      validateMinLength: validateMinLength,
      validateMaxLength: validateMaxLength,
      validatePattern: validatePattern,
      validationMessage: validationMessage,
    );

    final contentPadding = PropertyParsers.parseEdgeInsets(
      properties['padding'],
    );

    final controllerKey = controllerId ?? fieldId;
    final formState = _formStateFrom(dataContext);
    assert(() {
      if (formState == null) {
        debugPrint(
          '[TextFormFieldRenderer] FormStateStore missing in dataContext '
          'for field "$fieldId". Wire VariantScreen or parent form.',
        );
      }
      return formState != null;
    }());

    final effectiveKey = controllerKey.isEmpty
        ? 'field_${config.hashCode}'
        : controllerKey;
    final TextEditingController controller;
    if (formState != null) {
      controller = formState.controllerFor(
        effectiveKey,
        initialValue: initialValue,
      );
    } else {
      controller = TextEditingController(text: initialValue ?? '');
    }

    Widget buildField(BuildContext context) {
      final dispatcher = _resolveDispatcher(dataContext, context);

      final decoration = _buildDecoration(
        theme: theme,
        label: label,
        hint: hint,
        helper: helper,
        error: validator == null ? error : null,
        prefixText: prefixText,
        suffixText: suffixText,
        prefixIconName: prefixIconName,
        suffixIcon: _buildSuffixIcon(
          suffixIconName: suffixIconName,
          clearable: clearable,
          clearIconName: clearIconName,
          controller: controller,
          formState: formState,
          controllerKey: controllerKey,
          theme: theme,
        ),
        borderRadius: borderRadius,
        fillColor: color,
        border: border,
        contentPadding: contentPadding,
      );

      final field = TextFormField(
        key: ValueKey('engine_tff_$effectiveKey'),
        controller: controller,
        focusNode: formState?.focusNodeFor(effectiveKey),
        autofocus: autofocus,
        enabled: enabled,
        readOnly: readOnly,
        obscureText: obscureText,
        autocorrect: autocorrect,
        enableSuggestions: enableSuggestions,
        expands: expands,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        textCapitalization: textCapitalization,
        textDirection: textDirection,
        textAlign: textAlign ?? TextAlign.start,
        inputFormatters: inputFormatters,
        maxLines: expands ? null : (maxLines ?? 1),
        minLines: expands ? null : minLines,
        maxLength: maxLength,
        autovalidateMode: hasValidation
            ? AutovalidateMode.onUserInteraction
            : AutovalidateMode.disabled,
        decoration: decoration,
        validator: validator,
        onChanged: (value) {
          if (formState != null && controllerKey.isNotEmpty) {
            formState.updateValue(controllerKey, value);
          }
          if (onChangedAction != null && dispatcher != null) {
            dispatcher.dispatch(
              onChangedAction,
              value: value,
              fieldId: fieldId,
            );
          }
        },
        onFieldSubmitted: (value) {
          if (formState != null && controllerKey.isNotEmpty) {
            formState.updateValue(controllerKey, value);
          }
          if (onSubmittedAction != null && dispatcher != null) {
            dispatcher.dispatch(
              onSubmittedAction,
              value: value,
              fieldId: fieldId,
            );
          }
        },
      );

      final needsMaterial =
          context.findAncestorWidgetOfExactType<Material>() == null;
      final fieldWidget = needsMaterial
          ? Material(type: MaterialType.transparency, child: field)
          : field;

      Widget result = fieldWidget;
      if (shadow != null) {
        final radius =
            borderRadius ?? BorderRadius.circular(theme?.radiusMd ?? 12);
        result = DecoratedBox(
          decoration: BoxDecoration(borderRadius: radius, boxShadow: [shadow]),
          child: result,
        );
      }
      if (margin != null || width != null || height != null) {
        result = Container(
          width: width,
          height: height,
          margin: margin,
          child: result,
        );
      }

      return Semantics(
        textField: true,
        enabled: enabled,
        label: label,
        hint: hint,
        child: result,
      );
    }

    if (clearable) {
      return ListenableBuilder(
        listenable: controller,
        builder: (context, _) =>
            Builder(builder: (context) => buildField(context)),
      );
    }

    return Builder(builder: buildField);
  }

  InputDecoration _buildDecoration({
    required EngineTheme? theme,
    required String? label,
    required String? hint,
    required String? helper,
    required String? error,
    required String? prefixText,
    required String? suffixText,
    required String? prefixIconName,
    required Widget? suffixIcon,
    required BorderRadius? borderRadius,
    required Color? fillColor,
    required Border? border,
    required EdgeInsets? contentPadding,
  }) {
    final prefixIcon = _tapTargetIcon(prefixIconName);

    final radius = borderRadius ?? BorderRadius.circular(theme?.radiusMd ?? 12);
    final fill = fillColor ?? theme?.surfaceColor ?? const Color(0xFFF8FAFC);
    final defaultPadding =
        contentPadding ??
        const EdgeInsets.symmetric(horizontal: 12, vertical: 14);

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
    final focusedErrorOutline = OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: errorColor, width: 2),
    );

    final labelStyle = TextStyle(
      color: theme?.textColor ?? const Color(0xFF0F172A),
    );
    final hintStyle = TextStyle(
      color: theme?.mutedColor ?? const Color(0xFF475569),
    );

    return InputDecoration(
      labelText: label,
      hintText: hint,
      helperText: helper,
      errorText: error,
      prefixText: prefixText,
      suffixText: suffixText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: fill,
      labelStyle: labelStyle,
      hintStyle: hintStyle,
      contentPadding: defaultPadding,
      border: enabledOutline,
      enabledBorder: enabledOutline,
      focusedBorder: focusedOutline,
      errorBorder: errorOutline,
      focusedErrorBorder: focusedErrorOutline,
      disabledBorder: enabledOutline,
    );
  }

  Widget? _tapTargetIcon(String? iconName) {
    if (iconName == null) return null;
    return SizedBox(
      width: _minTapTarget,
      height: _minTapTarget,
      child: Center(child: Icon(PropertyParsers.parseIconData(iconName))),
    );
  }

  Widget? _buildSuffixIcon({
    required String? suffixIconName,
    required bool clearable,
    required String clearIconName,
    required TextEditingController controller,
    required FormStateStore? formState,
    required String controllerKey,
    required EngineTheme? theme,
  }) {
    if (clearable && controller.text.isNotEmpty) {
      final iconColor = theme?.mutedColor ?? const Color(0xFF475569);
      return SizedBox(
        width: _minTapTarget,
        height: _minTapTarget,
        child: IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(
            minWidth: _minTapTarget,
            minHeight: _minTapTarget,
          ),
          icon: Icon(
            PropertyParsers.parseIconData(clearIconName),
            size: 22,
            color: iconColor,
          ),
          tooltip: 'مسح',
          onPressed: () {
            controller.clear();
            if (formState != null && controllerKey.isNotEmpty) {
              formState.updateValue(controllerKey, '');
            }
          },
        ),
      );
    }
    return _tapTargetIcon(suffixIconName);
  }

  FormStateStore? _formStateFrom(Map<String, dynamic>? dataContext) {
    final existing = dataContext?[FormStateStore.contextKey];
    return existing is FormStateStore ? existing : null;
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

  int? _parseInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  bool _hasValidation(
    bool requiredField,
    bool validateEmail,
    bool validatePhone,
    bool validatePassword,
    int? validateMinLength,
    int? validateMaxLength,
    String? validatePattern,
  ) {
    return requiredField ||
        validateEmail ||
        validatePhone ||
        validatePassword ||
        validateMinLength != null ||
        validateMaxLength != null ||
        (validatePattern != null && validatePattern.isNotEmpty);
  }

  FormFieldValidator<String>? _buildValidator({
    required bool requiredField,
    required String requiredMessage,
    required bool validateEmail,
    required bool validatePhone,
    required bool validatePassword,
    required int? validateMinLength,
    required int? validateMaxLength,
    required String? validatePattern,
    required String? validationMessage,
  }) {
    if (!_hasValidation(
      requiredField,
      validateEmail,
      validatePhone,
      validatePassword,
      validateMinLength,
      validateMaxLength,
      validatePattern,
    )) {
      return null;
    }

    return (value) {
      final text = value?.trim() ?? '';
      if (requiredField && text.isEmpty) {
        return validationMessage ?? requiredMessage;
      }
      if (text.isEmpty) return null;
      if (validateEmail && !_isEmail(text)) {
        return validationMessage ?? 'أدخل بريداً إلكترونياً صالحاً';
      }
      if (validatePhone && !_isPhone(text)) {
        return validationMessage ?? 'أدخل رقم جوال صالحاً';
      }
      if (validatePassword && !_isPassword(text)) {
        return validationMessage ?? 'كلمة المرور 8 أحرف على الأقل وتتضمن رقماً';
      }
      if (validateMinLength != null && text.length < validateMinLength) {
        return validationMessage ??
            'يجب أن يكون $validateMinLength أحرف على الأقل';
      }
      if (validateMaxLength != null && text.length > validateMaxLength) {
        return validationMessage ?? 'يجب ألا يتجاوز $validateMaxLength حرفاً';
      }
      if (validatePattern != null && validatePattern.isNotEmpty) {
        final regex = RegExp(validatePattern);
        if (!regex.hasMatch(text)) {
          return validationMessage ?? 'صيغة غير صالحة';
        }
      }
      return null;
    };
  }

  bool _isEmail(String value) {
    final regex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    return regex.hasMatch(value);
  }

  bool _isPhone(String value) {
    final regex = RegExp(r'^\+?[0-9]{7,15}$');
    return regex.hasMatch(value);
  }

  bool _isPassword(String value) {
    final regex = RegExp(r'^(?=.*[A-Za-z])(?=.*\d).{8,}$');
    return regex.hasMatch(value);
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
