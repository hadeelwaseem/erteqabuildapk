import 'package:flutter/material.dart';

import '../../../config/component_config.dart';
import '../../component_renderer/component_renderer.dart';
import '../../form/form_state_store.dart';
import '../../theme/engine_theme.dart';

class FormRenderer implements ComponentRenderer {
  @override
  Widget render(
    ComponentConfig config, {
    required ComponentWidgetBuilder buildChild,
    Map<String, dynamic>? dataContext,
  }) {
    final formId =
        config.properties['formId'] as String? ??
        config.properties['id'] as String? ??
        '';
    final autovalidateMode = _parseAutovalidateMode(
      config.properties['autovalidateMode'] as String?,
    );

    final formState = _formStateFrom(dataContext);
    assert(() {
      if (formState == null) {
        debugPrint(
          '[FormRenderer] FormStateStore missing in dataContext '
          'for form "$formId". Wire VariantScreen.',
        );
      }
      return formState != null;
    }());

    final child = _resolveChild(config, buildChild, dataContext);
    if (child == null) {
      assert(() {
        debugPrint('[FormRenderer] form "$formId" has no child/children');
        return false;
      }());
      return const SizedBox.shrink();
    }

    if (formState == null) {
      return child;
    }

    final formKey = formState.formKeyFor(formId);
    return Form(key: formKey, autovalidateMode: autovalidateMode, child: child);
  }

  AutovalidateMode _parseAutovalidateMode(String? raw) {
    if (raw == 'onUserInteraction') {
      return AutovalidateMode.onUserInteraction;
    }
    return AutovalidateMode.disabled;
  }

  FormStateStore? _formStateFrom(Map<String, dynamic>? dataContext) {
    final existing = dataContext?[FormStateStore.contextKey];
    return existing is FormStateStore ? existing : null;
  }

  Widget? _resolveChild(
    ComponentConfig config,
    ComponentWidgetBuilder buildChild,
    Map<String, dynamic>? dataContext,
  ) {
    if (config.child != null) {
      return buildChild(config.child!);
    }
    final children = config.children;
    if (children == null || children.isEmpty) return null;

    final theme = EngineTheme.fromDataContext(dataContext);
    final gap = theme?.spacing('sm') ?? 10.0;
    final widgets = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        widgets.add(SizedBox(height: gap));
      }
      widgets.add(buildChild(children[i]));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: widgets,
    );
  }
}
