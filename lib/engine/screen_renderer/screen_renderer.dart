import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/enums/generic_component_type.dart';
import '../../config/component_config.dart';
import '../../config/screen_config.dart';
import '../tree/renderers/button_renderer.dart';
import '../tree/renderers/contact_button_renderer.dart';
import '../tree/renderers/card_renderer.dart';
import '../tree/renderers/column_renderer.dart';
import '../component_renderer/component_renderer.dart';
import '../tree/renderers/app_bar_renderer.dart';
import '../tree/renderers/container_renderer.dart';
import '../tree/renderers/divider_renderer.dart';
import '../tree/renderers/sized_box_renderer.dart';
import '../tree/renderers/icon_renderer.dart';
import '../tree/renderers/row_renderer.dart';
import '../tree/renderers/scaffold_renderer.dart';
import '../tree/renderers/single_child_scroll_view_renderer.dart';
import '../tree/renderers/text_renderer.dart';
import '../tree/renderers/text_form_field_renderer.dart';
import '../tree/renderers/form_renderer.dart';
import '../tree/renderers/image_renderer.dart';
import '../tree/renderers/list_view_renderer.dart';
import '../tree/renderers/grid_view_renderer.dart';
import '../tree/renderers/rich_text_renderer.dart';
import '../tree/renderers/video_player_renderer.dart';
import '../tree/renderers/stack_renderer.dart';
import '../tree/renderers/image_slider_renderer.dart';
import '../tree/renderers/timer_renderer.dart';
import '../tree/renderers/progress_indicator_renderer.dart';
import '../tree/renderers/app_drawer_renderer.dart';
import '../tree/renderers/tabs_renderer.dart';
import '../tree/renderers/otp_input_renderer.dart';
import '../tree/renderers/dropdown_renderer.dart';
import '../tree/renderers/expansion_tile_renderer.dart';
import '../tree/renderers/unsupported_component_renderer.dart';
import '../actions/action_dispatcher.dart';
import '../engine_page_chrome.dart';
import '../form/form_state_store.dart';
import '../page/page_state_store.dart';
import '../validation/layout_constraint_validator.dart';
import '../visibility/visible_when.dart';

/// Recursively renders a tree-based [ScreenConfig] into a widget tree.
///
/// The renderer uses a registry pattern with dependency injection support,
/// allowing custom renderers to be injected without modifying this class.
class ScreenRenderer {
  final Map<GenericComponentType, ComponentRenderer> _renderers;
  static const _pathKey = '_enginePath';

  /// Creates a [ScreenRenderer] with a custom renderer registry.
  ///
  /// Use this constructor for dependency injection and testing.
  /// Pass a map of component types to their renderer implementations.
  ScreenRenderer(this._renderers);

  /// Creates a [ScreenRenderer] with all primitive renderers pre-configured.
  ///
  /// This is the default factory for typical usage. Use the main constructor
  /// if you need to inject custom renderers or override specific implementations.
  ///
  /// **Renderers included**:
  /// - Scaffold, Column, Row, Container (layout)
  /// - Text, Button (leaf widgets)
  /// - Card (material card)
  /// - Spacer, Image (new in Phase 1)
  factory ScreenRenderer.withPrimitives() {
    return ScreenRenderer(_createDefaultRenderers());
  }

  /// Creates the default renderer registry.
  ///
  /// Extracted as a static method to support:
  /// - Testing (can be mocked or overridden)
  /// - Custom renderer chains (start with defaults, override specific ones)
  /// - Serialization/inspection of available renderers
  static Map<GenericComponentType, ComponentRenderer>
  _createDefaultRenderers() {
    return {
      GenericComponentType.scaffold: ScaffoldRenderer(),
      GenericComponentType.singleChildScrollView:
          SingleChildScrollViewRenderer(),
      GenericComponentType.column: ColumnRenderer(),
      GenericComponentType.row: RowRenderer(),
      GenericComponentType.container: ContainerRenderer(),
      GenericComponentType.listView: ListViewRenderer(),
      GenericComponentType.gridView: GridViewRenderer(),
      GenericComponentType.text: TextRenderer(),
      GenericComponentType.textFormField: TextFormFieldRenderer(),
      GenericComponentType.form: FormRenderer(),
      GenericComponentType.button: ButtonRenderer(),
      GenericComponentType.contactButton: ContactButtonRenderer(),
      GenericComponentType.card: CardRenderer(),
      GenericComponentType.image: ImageRenderer(),
      GenericComponentType.appBar: AppBarRenderer(),
      GenericComponentType.divider: DividerRenderer(),
      GenericComponentType.sizedBox: SizedBoxRenderer(),
      GenericComponentType.icon: IconRenderer(),
      GenericComponentType.richtext: RichTextRenderer(),
      GenericComponentType.videoPlayer: VideoPlayerRenderer(),
      GenericComponentType.stack: StackRenderer(),
      GenericComponentType.imageSlider: ImageSliderRenderer(),
      GenericComponentType.timer: TimerRenderer(),
      GenericComponentType.progressIndicator: ProgressIndicatorRenderer(),
      GenericComponentType.appDrawer: AppDrawerRenderer(),
      GenericComponentType.tabs: TabsRenderer(),
      GenericComponentType.otpInput: OtpInputRenderer(),
      GenericComponentType.dropdown: DropdownRenderer(),
      GenericComponentType.expansionTile: ExpansionTileRenderer(),
      GenericComponentType.unsupported: UnsupportedComponentRenderer(),
    };
  }

  /// Renders the screen configuration into a widget.
  Widget render(
    ScreenConfig config, {
    BuildContext? context,
    Map<String, dynamic>? dataContext,
  }) {
    final rootContext = dataContext ?? <String, dynamic>{};
    _ensureFormState(rootContext);
    _ensurePageChrome(rootContext);
    if (context != null) {
      _ensureActionDispatcher(rootContext, context);
    }
    assert(() {
      final rootProps = config.root.properties;
      LayoutConstraintValidator.reportIfNeeded(
        config.root,
        pageScroll: rootProps['pageScroll'] as String?,
        pageLayout: rootProps['pageLayout'] as String?,
        pageRoute: rootProps['pageRoute'] as String?,
      );
      return true;
    }());
    final body = _buildComponent(
      config.root,
      dataContext: rootContext,
      context: context,
      variantId: config.pageId,
      path: 'root',
    );
    final page = _wrapPageDrawer(rootContext, body, context: context);
    return page;
  }

  void _ensurePageChrome(Map<String, dynamic> dataContext) {
    if (dataContext[EnginePageChromeRegistry.contextKey]
        is EnginePageChromeRegistry) {
      return;
    }
    dataContext[EnginePageChromeRegistry.contextKey] =
        EnginePageChromeRegistry();
  }

  Widget _wrapPageDrawer(
    Map<String, dynamic> dataContext,
    Widget body, {
    BuildContext? context,
  }) {
    final registry = dataContext[EnginePageChromeRegistry.contextKey];
    if (registry is! EnginePageChromeRegistry) return body;

    final drawer = registry.drawer;
    if (drawer == null) return body;

    // `drawer` = start edge (visual right in RTL). `endDrawer` = end edge (visual left).
    final useEnd = registry.drawerEdge.toLowerCase() == 'end';

    return Scaffold(
      key: registry.scaffoldKey,
      drawer: useEnd ? null : drawer,
      endDrawer: useEnd ? drawer : null,
      body: body,
    );
  }

  /// Recursively builds a component widget from [ComponentConfig].
  ///
  /// Looks up the renderer for the component type and delegates rendering.
  /// Passes [buildChild] callback to support nested layouts like Row/Column.
  Widget _buildComponent(
    ComponentConfig config, {
    Map<String, dynamic>? dataContext,
    BuildContext? context,
    required String variantId,
    required String path,
  }) {
    // AppLogger.debug(
    //   '[ScreenRenderer] render node type=${config.type.name} path=$path',
    // );
    final renderer = _renderers[config.type];
    if (renderer == null) {
      final id = config.properties['id'] as String? ?? '?';
      throw StateError(
        'No renderer found for type: ${config.type.name} '
        '(id="$id") at $path',
      );
    }
    final mergedContext = _mergeContext(
      dataContext,
      config.dataContextOverride,
    );
    final dispatcher = _resolveActionDispatcher(mergedContext, context);
    final onTap = _resolveTapAction(config, dispatcher, mergedContext);
    final renderConfig = onTap == null
        ? config
        : ComponentConfig(
            type: config.type,
            properties: {...config.properties, 'onTap': onTap},
            child: config.child,
            children: config.children,
            itemBuilder: config.itemBuilder,
            axis: config.axis,
            scrollDirection: config.scrollDirection,
            crossAxisCount: config.crossAxisCount,
            mainAxisSpacing: config.mainAxisSpacing,
            crossAxisSpacing: config.crossAxisSpacing,
            dataContextOverride: config.dataContextOverride,
          );
    var widget = renderer.render(
      renderConfig,
      buildChild: (c) => _buildComponent(
        c,
        dataContext: _withPath(mergedContext, path),
        context: context,
        variantId: variantId,
        path: _childPath(path, config, c),
      ),
      dataContext: _withPath(mergedContext, path),
    );
    final visibleWhen = config.properties['visibleWhen'];
    if (visibleWhen != null) {
      widget = wrapWithVisibleWhen(
        child: widget,
        dataContext: mergedContext,
        visibleWhenRaw: visibleWhen,
      );
    }
    if (onTap == null ||
        config.type == GenericComponentType.button ||
        config.type == GenericComponentType.contactButton ||
        config.type == GenericComponentType.tabs ||
        config.type == GenericComponentType.dropdown) {
      return widget;
    }
    return Semantics(
      button: true,
      label: _resolveAccessibilityLabel(config),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: widget,
      ),
    );
  }

  String? _resolveAccessibilityLabel(ComponentConfig config) {
    final tap = config.properties['tap'];
    if (tap is Map) {
      final fromTap = tap['semanticLabel'];
      if (fromTap is String && fromTap.trim().isNotEmpty) {
        return fromTap.trim();
      }
    }
    final fromProps = config.properties['accessibilityLabel'];
    if (fromProps is String && fromProps.trim().isNotEmpty) {
      return fromProps.trim();
    }
    return null;
  }

  VoidCallback? _resolveTapAction(
    ComponentConfig config,
    EngineActionDispatcher? dispatcher,
    Map<String, dynamic>? dataContext,
  ) {
    if (dispatcher == null) return null;
    final tap = config.properties['tap'];
    if (tap is! Map) return null;
    return dispatcher.resolveTap(
      tap.cast<String, dynamic>(),
      dataContext: dataContext,
    );
  }

  EngineActionDispatcher? _resolveActionDispatcher(
    Map<String, dynamic>? dataContext,
    BuildContext? context,
  ) {
    if (dataContext != null) {
      final existing = dataContext[EngineActionDispatcher.contextKey];
      if (existing is EngineActionDispatcher) return existing;
    }
    if (context == null) return null;
    final created = EngineActionDispatcher(
      context: context,
      formState: dataContext?[FormStateStore.contextKey] as FormStateStore?,
      pageStateStore:
          dataContext?[PageStateStore.contextKey] as PageStateStore?,
    );
    dataContext?[EngineActionDispatcher.contextKey] = created;
    return created;
  }

  void _ensureFormState(Map<String, dynamic> dataContext) {
    if (dataContext[FormStateStore.contextKey] is FormStateStore) return;
    dataContext[FormStateStore.contextKey] = FormStateStore();
  }

  void _ensureActionDispatcher(
    Map<String, dynamic> dataContext,
    BuildContext context,
  ) {
    if (dataContext[EngineActionDispatcher.contextKey]
        is EngineActionDispatcher) {
      return;
    }
    dataContext[EngineActionDispatcher.contextKey] = EngineActionDispatcher(
      context: context,
      formState: dataContext[FormStateStore.contextKey] as FormStateStore?,
      pageStateStore: dataContext[PageStateStore.contextKey] as PageStateStore?,
    );
  }

  Map<String, dynamic> _withPath(
    Map<String, dynamic>? dataContext,
    String path,
  ) {
    if (!kDebugMode) {
      return dataContext ?? <String, dynamic>{};
    }
    final next = dataContext == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(dataContext);
    next[_pathKey] = path;
    return next;
  }

  Map<String, dynamic> _mergeContext(
    Map<String, dynamic>? base,
    Map<String, dynamic>? override,
  ) {
    if (override == null || override.isEmpty) {
      return base ?? <String, dynamic>{};
    }
    final next = base == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(base);
    next.addAll(override);
    return next;
  }

  String _childPath(
    String parentPath,
    ComponentConfig parent,
    ComponentConfig child,
  ) {
    if (parent.child == child) {
      return '$parentPath.child';
    }
    final children = parent.children;
    if (children == null) return '$parentPath.child';
    final index = children.indexOf(child);
    return index == -1
        ? '$parentPath.children[?]'
        : '$parentPath.children[$index]';
  }
}
