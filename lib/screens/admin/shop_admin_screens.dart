import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../core/validators.dart';
import '../../models/enums.dart';
import '../../models/shop.dart';
import '../../services/backend.dart';
import '../../widgets/animations.dart';
import '../../widgets/bits.dart';
import '../../widgets/common.dart';
import '../../widgets/pickers.dart';
import '../coach/coach_home.dart';
import '../shell/main_shell.dart';
import '../shop/shop_screens.dart';

/// Dashboard boutique (super admin) : CA, stock, commandes, catalogue.
class ShopDashboardScreen extends StatelessWidget {
  const ShopDashboardScreen({super.key, this.standalone = false});
  final bool standalone;

  @override
  Widget build(BuildContext context) {
    final b = Backend.I;
    return Scaffold(
      appBar: AppBar(
        leading: standalone ? null : const ShellMenuButton(),
        title: const Text('Gestion boutique'),
        actions: [
          IconButton(
            tooltip: 'Commandes',
            icon: const Icon(Icons.receipt_long_outlined),
            onPressed: () => Navigator.pushNamed(context, Routes.adminOrders),
          ),
          const NotificationBell(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'product_fab',
        onPressed: () => Navigator.pushNamed(context, Routes.productForm),
        icon: const Icon(Icons.add),
        label: const Text('Produit'),
      ),
      body: ListenableBuilder(
        listenable: b.bus,
        builder: (context, _) {
          final products = b.productService.list();
          final now = b.now();
          final month = b.orderService.revenue(
            since: DateTime(now.year, now.month),
          );
          final pending = b.orderService
              .all()
              .where((o) => o.status != OrderStatus.delivered)
              .length;
          final lowStock = products.where((p) => p.stock <= 5).length;
          return ListView(
            padding: const EdgeInsets.fromLTRB(Gap.m, Gap.m, Gap.m, 96),
            children: [
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: Gap.s,
                crossAxisSpacing: Gap.s,
                childAspectRatio: 1.6,
                children: [
                  KpiCard(
                    icon: Icons.payments,
                    value: b.orderService.revenue(),
                    label: 'CA total',
                    format: (v) => '${v.round()} DT',
                    color: AppColors.success,
                  ),
                  KpiCard(
                    icon: Icons.calendar_month,
                    value: month,
                    label: 'CA du mois',
                    format: (v) => '${v.round()} DT',
                  ),
                  KpiCard(
                    icon: Icons.inventory_2,
                    value: pending.toDouble(),
                    label: 'Commandes à traiter',
                    color: AppColors.red,
                    onTap: () =>
                        Navigator.pushNamed(context, Routes.adminOrders),
                  ),
                  KpiCard(
                    icon: Icons.warning_amber,
                    value: lowStock.toDouble(),
                    label: 'Stocks faibles (≤ 5)',
                    color: AppColors.red,
                  ),
                ],
              ),
              const SizedBox(height: Gap.s),
              OutlinedButton.icon(
                onPressed: () =>
                    Navigator.push(context, gfRoute(const ShopScreen())),
                icon: const Icon(Icons.storefront),
                label: const Text('Voir la boutique comme un client'),
              ),
              SectionHeader('Catalogue (${products.length})'),
              for (var i = 0; i < products.length; i++)
                FadeSlideIn(
                  index: i,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: Gap.s),
                    child: _AdminProductTile(product: products[i]),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _AdminProductTile extends StatelessWidget {
  const _AdminProductTile({required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
    final p = product;
    final b = Backend.I;
    return GfCard(
      padding: const EdgeInsets.all(Gap.s),
      onTap: () =>
          Navigator.pushNamed(context, Routes.productForm, arguments: p.id),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Opacity(
              opacity: p.active ? 1 : 0.45,
              child: NetImage(
                p.images.isEmpty ? null : p.images.first,
                width: 64,
                height: 64,
                cacheWidth: 200,
              ),
            ),
          ),
          const SizedBox(width: Gap.s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.subtitle(size: 14),
                ),
                Text(
                  '${p.category.label} · ${Fmt.money(p.effectivePrice)}',
                  style: AppText.label(size: 12),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  children: [
                    Pill(
                      p.stock == 0 ? 'Rupture' : 'Stock ${p.stock}',
                      color: p.stock == 0
                          ? AppColors.red
                          : (p.stock <= 5 ? AppColors.gold : AppColors.cream),
                    ),
                    if (p.onPromo)
                      Pill(
                        'Promo -${p.discountPercent} %',
                        color: AppColors.gold,
                      ),
                    if (!p.active)
                      const Pill('Archivé', color: AppColors.inkSoft),
                  ],
                ),
              ],
            ),
          ),
          Column(
            children: [
              IconButton(
                tooltip: 'Ajouter 5 au stock',
                visualDensity: VisualDensity.compact,
                onPressed: () => runAction(
                  context,
                  () => b.productService.adjustStock(p.id, 5),
                  success: 'Stock +5',
                ),
                icon: const Icon(
                  Icons.add_box_outlined,
                  color: AppColors.success,
                ),
              ),
              IconButton(
                tooltip: 'Retirer 1 du stock',
                visualDensity: VisualDensity.compact,
                onPressed: p.stock == 0
                    ? null
                    : () => runAction(
                        context,
                        () => b.productService.adjustStock(p.id, -1),
                      ),
                icon: const Icon(
                  Icons.indeterminate_check_box_outlined,
                  color: AppColors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Formulaire produit (CRUD super admin, upload d'image).
class ProductFormScreen extends StatefulWidget {
  const ProductFormScreen({super.key, this.productId});
  final String? productId;

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _price = TextEditingController();
  final _promo = TextEditingController();
  final _stock = TextEditingController(text: '10');
  ProductCategory _category = ProductCategory.supplements;
  final List<String> _images = [];
  bool _active = true;
  bool _featured = false;
  bool _saving = false;
  Product? _existing;

  @override
  void initState() {
    super.initState();
    final p = widget.productId == null
        ? null
        : Backend.I.productService.byId(widget.productId!);
    if (p != null) {
      _existing = p;
      _name.text = p.name;
      _description.text = p.description;
      _price.text = p.price.toStringAsFixed(2);
      _promo.text = p.promoPrice?.toStringAsFixed(2) ?? '';
      _stock.text = '${p.stock}';
      _category = p.category;
      _images.addAll(p.images);
      _active = p.active;
      _featured = p.featured;
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _description, _price, _promo, _stock]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _addImage() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Photo du téléphone'),
              onTap: () => Navigator.pop(ctx, 'file'),
            ),
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('Adresse web'),
              onTap: () => Navigator.pop(ctx, 'url'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    final String? src = choice == 'file'
        ? await pickImageFile(context)
        : await askText(
            context,
            title: 'Image web',
            label: 'Adresse de l\'image',
            validator: (v) => Validators.url(v, optional: false),
          );
    if (src != null) setState(() => _images.add(src));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final ok = await runAction(
      context,
      () => Backend.I.productService.save(
        id: _existing?.id,
        name: _name.text,
        description: _description.text,
        category: _category,
        price: Validators.parseDecimal(_price.text)!,
        promoPrice: _promo.text.trim().isEmpty
            ? null
            : Validators.parseDecimal(_promo.text),
        stock: int.parse(_stock.text.trim()),
        images: _images,
        active: _active,
        featured: _featured,
      ),
      success: 'Produit enregistré.',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _existing == null ? 'Nouveau produit' : 'Modifier le produit',
        ),
        actions: [
          if (_existing != null)
            IconButton(
              tooltip: 'Supprimer',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final ok = await confirm(
                  context,
                  title: 'Supprimer le produit ?',
                  message:
                      'S\'il a déjà été commandé, il sera archivé (retiré de la vente).',
                  confirmLabel: 'Supprimer',
                  destructive: true,
                );
                if (!ok || !context.mounted) return;
                final done = await runAction(
                  context,
                  () => Backend.I.productService.delete(_existing!.id),
                  success: 'Produit retiré.',
                );
                if (done && context.mounted) Navigator.pop(context);
              },
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Gap.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 110,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (var i = 0; i < _images.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(right: Gap.s),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: NetImage(
                                _images[i],
                                width: 110,
                                height: 110,
                                cacheWidth: 300,
                              ),
                            ),
                            Positioned(
                              right: 0,
                              top: 0,
                              child: IconButton.filled(
                                tooltip: 'Retirer',
                                style: IconButton.styleFrom(
                                  backgroundColor: AppColors.red,
                                  foregroundColor: AppColors.white,
                                  minimumSize: const Size(32, 32),
                                ),
                                onPressed: () =>
                                    setState(() => _images.removeAt(i)),
                                icon: const Icon(Icons.close, size: 16),
                              ),
                            ),
                          ],
                        ),
                      ),
                    InkWell(
                      onTap: _addImage,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 110,
                        decoration: BoxDecoration(
                          color: AppColors.cream,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.outline),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_a_photo_outlined,
                              color: AppColors.navy,
                            ),
                            Text('Photo'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Gap.m),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Nom du produit'),
                validator: Validators.text(field: 'Le nom', min: 3, max: 80),
              ),
              const SizedBox(height: Gap.m),
              TextFormField(
                controller: _description,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Description'),
                validator: Validators.text(
                  field: 'La description',
                  min: 10,
                  max: 600,
                ),
              ),
              const SizedBox(height: Gap.m),
              EnumDropdown<ProductCategory>(
                label: 'Catégorie',
                value: _category,
                values: ProductCategory.values,
                labelOf: (c) => c.label,
                onChanged: (c) => setState(() => _category = c),
              ),
              const SizedBox(height: Gap.m),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _price,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Prix (TND)',
                      ),
                      validator: Validators.decimalRange(
                        field: 'Le prix',
                        min: 0.1,
                        max: 5000,
                      ),
                    ),
                  ),
                  const SizedBox(width: Gap.s),
                  Expanded(
                    child: TextFormField(
                      controller: _promo,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Prix promo',
                      ),
                      validator: (v) {
                        final base = Validators.decimalRange(
                          field: 'Le prix promo',
                          min: 0.1,
                          max: 5000,
                          optional: true,
                        )(v);
                        if (base != null) return base;
                        final promo = Validators.parseDecimal(v);
                        final price = Validators.parseDecimal(_price.text);
                        if (promo != null && price != null && promo >= price) {
                          return 'Doit être < prix.';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: Gap.s),
                  Expanded(
                    child: TextFormField(
                      controller: _stock,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Stock'),
                      validator: Validators.intRange(
                        field: 'Le stock',
                        min: 0,
                        max: 10000,
                      ),
                    ),
                  ),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _active,
                onChanged: (v) => setState(() => _active = v),
                title: Text('En vente', style: AppText.body()),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _featured,
                onChanged: (v) => setState(() => _featured = v),
                title: Text('À la une (accueil)', style: AppText.body()),
              ),
              const SizedBox(height: Gap.m),
              LoadingButton(
                label: 'Enregistrer',
                loading: _saving,
                onPressed: _save,
                icon: Icons.check,
              ),
              const SizedBox(height: Gap.l),
            ],
          ),
        ),
      ),
    );
  }
}

/// Commandes à traiter (super admin).
class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  OrderStatus? _status;

  @override
  Widget build(BuildContext context) {
    final b = Backend.I;
    return Scaffold(
      appBar: AppBar(title: const Text('Commandes')),
      body: ListenableBuilder(
        listenable: b.bus,
        builder: (context, _) {
          final orders = b.orderService.all(status: _status);
          return Column(
            children: [
              const SizedBox(height: Gap.s),
              ChipBar(
                children: [
                  GfFilterChip(
                    label: 'Toutes',
                    selected: _status == null,
                    onTap: () => setState(() => _status = null),
                  ),
                  for (final s in OrderStatus.values)
                    GfFilterChip(
                      label: s.label,
                      selected: _status == s,
                      onTap: () => setState(() => _status = s),
                    ),
                ],
              ),
              Expanded(
                child: orders.isEmpty
                    ? const EmptyState(
                        icon: Icons.inbox,
                        title: 'Aucune commande',
                        message: 'Rien à traiter pour ce filtre.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(Gap.m),
                        itemCount: orders.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: Gap.s),
                        itemBuilder: (_, i) {
                          final o = orders[i];
                          return OrderTile(
                            order: o,
                            showClient: true,
                            trailing: o.status == OrderStatus.delivered
                                ? null
                                : TextButton(
                                    onPressed: () => runAction(
                                      context,
                                      () => b.orderService.advance(o.id),
                                      success: 'Client prévenu.',
                                    ),
                                    child: Text(
                                      o.status == OrderStatus.paid
                                          ? 'Préparée'
                                          : 'Remise',
                                    ),
                                  ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
