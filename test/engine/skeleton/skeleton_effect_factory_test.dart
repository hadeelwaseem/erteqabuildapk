import 'package:flutter_test/flutter_test.dart';
import 'package:sooq_merchant/config/models/mobile_theme_config.dart';
import 'package:sooq_merchant/engine/skeleton/skeleton_effect_factory.dart';
import 'package:sooq_merchant/engine/theme/engine_theme.dart';

void main() {
  test('bone palette has stronger contrast than prod surface/background', () {
    final theme = EngineTheme.fromConfig(MobileThemeConfig.defaults());
    final prodDelta =
        (theme.surfaceColor.computeLuminance() -
                theme.backgroundColor.computeLuminance())
            .abs();
    final boneDelta =
        SkeletonEffectFactory.kBoneHighlight.computeLuminance() -
        SkeletonEffectFactory.kBoneBase.computeLuminance();

    expect(boneDelta, greaterThan(0));
    expect(boneDelta, greaterThan(prodDelta * 3));
  });

  test('containersColor differs from page background', () {
    final theme = EngineTheme.fromConfig(MobileThemeConfig.defaults());
    final container = SkeletonEffectFactory.containersColor(theme);
    final delta =
        (container.computeLuminance() -
                theme.backgroundColor.computeLuminance())
            .abs();
    expect(delta, greaterThan(0.02));
  });
}
