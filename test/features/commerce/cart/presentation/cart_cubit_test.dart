import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sooq_merchant/core/errors/failures.dart';
import 'package:sooq_merchant/features/commerce/cart/data/repos/cart_repo.dart';
import 'package:sooq_merchant/features/commerce/cart/presentation/manager/cart_cubit/cart_cubit.dart';
import 'package:sooq_merchant/features/commerce/cart/presentation/manager/cart_cubit/cart_state.dart';
import 'package:sooq_merchant/features/commerce/data/models/cart.dart';

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

void main() {
  late _MemoryCartRepo repo;
  late CartCubit cubit;

  setUp(() {
    repo = _MemoryCartRepo();
    cubit = CartCubit(repo);
  });

  tearDown(() => cubit.close());

  test('addItem upserts by variantId and persists', () async {
    await cubit.addItem(
      variantId: 'v1',
      productTitle: 'منتج أ',
      quantity: 1,
      unitPrice: 5000,
    );
    await cubit.addItem(
      variantId: 'v1',
      productTitle: 'منتج أ',
      quantity: 2,
      unitPrice: 5000,
    );

    final state = cubit.state;
    expect(state, isA<CartActionSuccess>());
    final loaded = (state as CartActionSuccess).cart;
    expect(loaded.items, hasLength(1));
    expect(loaded.items.first.quantity, 3);
    expect((await repo.load()).getOrElse(() => const Cart()).itemCount, 3);
  });

  test('addItem fails when variantId is empty', () async {
    await cubit.addItem(
      variantId: '  ',
      productTitle: 'منتج',
      quantity: 1,
      unitPrice: 100,
    );

    expect(cubit.state, isA<CartFailureState>());
    expect(
      (cubit.state as CartFailureState).message,
      contains('اختيار الخيار'),
    );
  });

  test('updateQuantity with delta removes line at zero', () async {
    await cubit.addItem(
      variantId: 'v1',
      productTitle: 'منتج',
      quantity: 1,
      unitPrice: 100,
    );
    await cubit.updateQuantity(variantId: 'v1', delta: -1);

    expect(cubit.state, isA<CartLoaded>());
    expect((cubit.state as CartLoaded).cart.isEmpty, isTrue);
  });

  test('assertNotEmpty emits failure for empty cart', () async {
    await cubit.assertNotEmpty();

    expect(cubit.state, isA<CartFailureState>());
    expect((cubit.state as CartFailureState).message, 'السلة فارغة');
  });

  test('setVariantPriceIndex resolves unit price on addItem', () async {
    cubit.setVariantPriceIndex({'v-index': 9000});
    await cubit.addItem(
      variantId: 'v-index',
      productTitle: 'منتج',
      quantity: 1,
    );

    final state = cubit.state as CartActionSuccess;
    expect(state.cart.items.first.unitPrice, 9000);
  });
}
