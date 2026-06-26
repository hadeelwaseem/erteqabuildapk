import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sooq_merchant/core/cubits/token_cubit/token_cubit.dart';
import 'package:sooq_merchant/core/errors/failures.dart';
import 'package:sooq_merchant/core/network/auth_token_storage.dart';
import 'package:sooq_merchant/dev/commerce_mock/mock_checkout_repo.dart';
import 'package:sooq_merchant/dev/commerce_mock/mock_commerce_data.dart';
import 'package:sooq_merchant/engine/actions/action_dispatcher.dart';
import 'package:sooq_merchant/engine/form/form_state_store.dart';
import 'package:sooq_merchant/features/commerce/cart/data/repos/cart_repo.dart';
import 'package:sooq_merchant/features/commerce/cart/presentation/manager/cart_cubit/cart_cubit.dart';
import 'package:sooq_merchant/features/commerce/checkout/data/datasources/checkout_session_store.dart';
import 'package:sooq_merchant/features/commerce/checkout/data/models/checkout_draft.dart';
import 'package:sooq_merchant/features/commerce/checkout/presentation/manager/checkout_cubit/checkout_cubit.dart';
import 'package:sooq_merchant/features/commerce/data/models/cart.dart';
import 'package:sooq_merchant/features/commerce/data/models/shipping_address.dart';

class _MemoryCartRepo implements CartRepo {
  Cart _cart = const Cart();

  @override
  Future<Either<Failure, Cart>> clear() async {
    _cart = const Cart();
    return Right(_cart);
  }

  @override
  Future<Either<Failure, Cart>> load() async => Right(_cart);

  @override
  Future<Either<Failure, Cart>> save(Cart cart) async {
    _cart = cart;
    return Right(cart);
  }
}

class _MemoryTokenStorage implements AuthTokenStorage {
  @override
  Future<void> clearTokens() async {}

  @override
  Future<String?> readAccessToken() async => null;

  @override
  Future<DateTime?> readExpiresAt() async => null;

  @override
  Future<String?> readRefreshToken() async => null;

  @override
  Future<String?> readTenantId() async => null;

  @override
  Future<AuthTokenBundle> readTokenBundle() async =>
      const AuthTokenBundle();

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    DateTime? expiresAt,
    String? tenantId,
  }) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final locator = GetIt.instance;
  late _MemoryCartRepo cartRepo;
  late CheckoutSessionStore sessionStore;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    MockCommerceData.resetForTests();
    cartRepo = _MemoryCartRepo();

    if (locator.isRegistered<CartCubit>()) {
      await locator.unregister<CartCubit>();
    }
    if (locator.isRegistered<CheckoutCubit>()) {
      await locator.unregister<CheckoutCubit>();
    }
    if (locator.isRegistered<TokenCubit>()) {
      await locator.unregister<TokenCubit>();
    }

    locator.registerLazySingleton<CartCubit>(() => CartCubit(cartRepo));
    locator.registerLazySingleton<TokenCubit>(
      () => TokenCubit(_MemoryTokenStorage()),
    );
    sessionStore = CheckoutSessionStore();
    locator.registerLazySingleton<CheckoutCubit>(
      () => CheckoutCubit(
        MockCheckoutRepo(),
        sessionStore,
        locator<CartCubit>(),
        locator<TokenCubit>(),
      ),
    );
  });

  tearDown(() async {
    if (locator.isRegistered<CheckoutCubit>()) {
      await locator.unregister<CheckoutCubit>();
    }
    if (locator.isRegistered<CartCubit>()) {
      await locator.unregister<CartCubit>();
    }
    if (locator.isRegistered<TokenCubit>()) {
      await locator.unregister<TokenCubit>();
    }
  });

  testWidgets('saveAddress requires valid form and navigates on success', (
    tester,
  ) async {
    final formState = FormStateStore();
    formState.updateValue('fullName', 'أحمد');
    formState.updateValue('phone', '+963900000000');
    formState.updateValue('addressLine', 'دمشق');

    await sessionStore.saveDraft(
      const CheckoutDraft(latitude: 33.5138, longitude: 36.2765),
    );
    await locator<CheckoutCubit>().loadDraft();

    String? navigatedRoute;

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) {
            final dispatcher = EngineActionDispatcher(
              context: context,
              formState: formState,
            );
            return Scaffold(
              body: ElevatedButton(
                onPressed: () => dispatcher.dispatch({
                  'type': 'cubitCall',
                  'cubit': 'checkout',
                  'method': 'saveAddress',
                  'requireValidForm': true,
                  'formId': 'checkout-address-form',
                  'params': {
                    'recipientName': {
                      'source': 'form',
                      'field': 'fullName',
                    },
                    'phone': {'source': 'form', 'field': 'phone'},
                    'addressLabel': {
                      'source': 'form',
                      'field': 'addressLine',
                    },
                  },
                  'onSuccess': {
                    'type': 'navigate',
                    'route': '/checkout/payment',
                  },
                }),
                child: const Text('Continue'),
              ),
            );
          },
        ),
        GoRoute(
          path: '/checkout/payment',
          builder: (_, __) {
            navigatedRoute = '/checkout/payment';
            return const Scaffold(body: Text('Payment'));
          },
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(navigatedRoute, '/checkout/payment');
  });

  testWidgets('placeOrder does not navigate when cart is empty', (tester) async {
    await sessionStore.saveDraft(
      CheckoutDraft(
        latitude: 33.5138,
        longitude: 36.2765,
        shippingAddress: const ShippingAddress(
          latitude: 33.5138,
          longitude: 36.2765,
          recipientName: 'أحمد',
          phone: '+963900000000',
        ),
        paymentMethod: 'COD',
        guestEmail: 'guest@example.com',
      ),
    );
    await locator<CheckoutCubit>().loadDraft();

    var navigated = false;

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) {
            final dispatcher = EngineActionDispatcher(context: context);
            return Scaffold(
              body: ElevatedButton(
                onPressed: () => dispatcher.dispatch({
                  'type': 'cubitCall',
                  'cubit': 'checkout',
                  'method': 'placeOrder',
                  'onSuccess': {
                    'type': 'navigate',
                    'route': '/order/success',
                  },
                }),
                child: const Text('Place'),
              ),
            );
          },
        ),
        GoRoute(
          path: '/order/success',
          builder: (_, __) {
            navigated = true;
            return const Scaffold(body: Text('Success'));
          },
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('Place'));
    await tester.pumpAndSettle();

    expect(navigated, isFalse);
  });
}
