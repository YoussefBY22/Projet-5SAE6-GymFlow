import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/core/errors.dart';
import 'package:gymflow/models/enums.dart';
import 'package:gymflow/models/shop.dart';
import 'package:gymflow/services/backend.dart';
import 'package:gymflow/services/payment/payment_gateway.dart';

import 'helpers.dart';

Future<PaymentResult> _pay(Backend b, String card, double amount) =>
    (b.payment as SimulatedPaymentGateway).charge(
      cardNumber: card,
      expiry: '12/30',
      cvc: '123',
      amount: amount,
      now: b.now(),
    );

void main() {
  test('Luhn, expiration et CVC de la passerelle simulée', () async {
    expect(SimulatedPaymentGateway.luhnValid('4242 4242 4242 4242'), isTrue);
    expect(SimulatedPaymentGateway.luhnValid('4242 4242 4242 4241'), isFalse);
    expect(SimulatedPaymentGateway.luhnValid('abc'), isFalse);
    expect(
      SimulatedPaymentGateway.validateExpiry('01/20', testNow),
      'Carte expirée.',
    );
    expect(
      SimulatedPaymentGateway.validateExpiry('13/30', testNow),
      'Mois invalide.',
    );
    expect(SimulatedPaymentGateway.validateExpiry('09/26', testNow), isNull);
    final b = await makeBackend();
    expect(
      () => _pay(b, '4000 0000 0000 0002', 10),
      throwsA(isA<BusinessRuleException>()),
    );
    expect(
      () => _pay(b, '4000 0000 0000 9995', 10),
      throwsA(isA<BusinessRuleException>()),
    );
    expect(
      () => _pay(b, '4242 4242 4242 4241', 10),
      throwsA(isA<ValidationException>()),
    );
    final ok = await _pay(b, '4242 4242 4242 4242', 10);
    expect(ok.success, isTrue);
    expect(ok.reference, startsWith('SIM-'));
  });

  test('panier : rupture et stock insuffisant refusés', () async {
    final b = await makeBackend();
    await loginAs(b, 'nour@gymflow.tn');
    expect(
      () => b.cart.add(b.products.byId('pr_bcaa')!),
      throwsA(isA<BusinessRuleException>()),
    );
    expect(
      () => b.cart.add(b.products.byId('pr_whey')!, 20),
      throwsA(isA<BusinessRuleException>()),
    );
    b.cart.add(b.products.byId('pr_whey')!, 2);
    b.cart.add(b.products.byId('pr_isolate')!);
    expect(b.cart.count, 3);
    // Prix promo appliqué : 2 × 189 + 129.
    expect(b.cart.total, 2 * 189 + 129);
  });

  test(
    'achat : stock décrémenté, commande numérotée, CA et notification',
    () async {
      final b = await makeBackend();
      await loginAs(b, 'nour@gymflow.tn');
      final before = b.orderService.revenue();
      b.cart.add(b.products.byId('pr_shaker')!, 2);
      final lines = b.cart.lines;
      b.orderService.checkStock(lines);
      final payment = await _pay(
        b,
        '4242424242424242',
        b.orderService.totalOf(lines),
      );
      final order = await b.orderService.placeOrder(lines, payment);
      expect(order.status, OrderStatus.paid);
      expect(order.number, matches(RegExp(r'^GF-2026-\d{4}$')));
      expect(b.products.byId('pr_shaker')!.stock, 38);
      expect(b.orderService.revenue(), before + 36);
      expect(b.orderService.mine().first.id, order.id);
      expect(b.notifications.mine().first.title, contains(order.number));
    },
  );

  test(
    'stock revérifié après paiement : commande refusée si épuisé entre-temps',
    () async {
      final b = await makeBackend();
      await loginAs(b, 'nour@gymflow.tn');
      final towel = b.products.byId('pr_towel')!; // stock 3
      final lines = [CartLine(product: towel, quantity: 3)];
      b.orderService.checkStock(lines);
      final payment = await _pay(b, '4242424242424242', 66);
      // Un autre client achète la dernière serviette pendant le paiement.
      await b.products.save(towel.copyWith(stock: 1));
      expect(
        () => b.orderService.placeOrder(lines, payment),
        throwsA(isA<BusinessRuleException>()),
      );
      expect(b.products.byId('pr_towel')!.stock, 1);
    },
  );

  test(
    'gestion boutique réservée au super admin ; suivi des commandes',
    () async {
      final b = await makeBackend();
      await loginAs(b, 'mehdi@gymflow.tn');
      expect(
        () => b.productService.save(
          name: 'Test',
          description: 'Produit de test pour les droits.',
          category: ProductCategory.accessories,
          price: 10,
          stock: 1,
          images: const [],
        ),
        throwsA(isA<PermissionDeniedException>()),
      );
      expect(
        () => b.orderService.all(),
        throwsA(isA<PermissionDeniedException>()),
      );
      await b.auth.logout();
      await loginAs(b, 'admin@gymflow.tn');
      final paid = b.orderService.all(status: OrderStatus.paid).first;
      final prepared = await b.orderService.advance(paid.id);
      expect(prepared.status, OrderStatus.prepared);
      final delivered = await b.orderService.advance(paid.id);
      expect(delivered.status, OrderStatus.delivered);
      expect(
        () => b.orderService.advance(paid.id),
        throwsA(isA<BusinessRuleException>()),
      );
      expect(
        () => b.productService.save(
          name: 'Promo absurde',
          description: 'Prix promo supérieur au prix.',
          category: ProductCategory.accessories,
          price: 10,
          promoPrice: 12,
          stock: 1,
          images: const [],
        ),
        throwsA(isA<ValidationException>()),
      );
    },
  );

  test('produit déjà commandé : archivé plutôt que supprimé', () async {
    final b = await makeBackend();
    await loginAs(b, 'admin@gymflow.tn');
    await b.productService.delete('pr_whey');
    expect(b.products.byId('pr_whey')!.active, isFalse);
    await b.productService.delete('pr_gloves');
    expect(b.products.byId('pr_gloves'), isNull);
  });

  test('Stripe : conversion TND → centimes d\'euro', () {
    expect(StripeCheckoutGateway.eurCents(34), 1000);
    expect(StripeCheckoutGateway.eurCents(189), 5559);
  });
}
