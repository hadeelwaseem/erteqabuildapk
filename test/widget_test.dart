import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sooq_merchant/core/cubits/shared_preferences_cubit/shared_preferences_cubit.dart';
import 'package:sooq_merchant/core/cubits/token_cubit/token_cubit.dart';
import 'package:sooq_merchant/core/network/network_config.dart';
import 'package:sooq_merchant/core/utils/service_locator.dart';
import 'package:sooq_merchant/app/sooq_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await getIt.reset();
    setupServiceLocator(
      networkConfig: const NetworkConfig(
        baseUrl: NetworkConfig.defaultBaseUrl,
      ),
    );
    await EasyLocalization.ensureInitialized();
  });

  testWidgets('SOOQApp smoke test', (WidgetTester tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(body: Text('SOOQ')),
        ),
      ],
    );

    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en'), Locale('ar')],
        path: 'assets/translations',
        fallbackLocale: const Locale('en'),
        child: SOOQApp(
          router: router,
          tokenCubit: getIt<TokenCubit>(),
          sharedPreferencesCubit: getIt<SharedPreferencesCubit>(),
        ),
      ),
    );

    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
