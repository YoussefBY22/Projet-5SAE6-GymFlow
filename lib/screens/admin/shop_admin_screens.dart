import 'package:flutter/material.dart';

import '../../core/errors.dart';
import '../../core/responsive.dart';
import '../../core/formatters.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../core/validators.dart';
import '../../models/enums.dart';
import '../../models/nutrition.dart';
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
                crossAxisCount: isWide(context) ? 4 : 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: Gap.s,
                crossAxisSpacing: Gap.s,
                childAspectRatio: 1.45,
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

  // Fiche produit intelligente : Open Food Facts + IA.
  final _barcode = TextEditingController();
  final _brand = TextEditingController();
  final _nameEn = TextEditingController();
  final _summary = TextEditingController();
  final _allergens = TextEditingController();
  final _nutri = {
    for (final k in _nutriFields.keys) k: TextEditingController(),
  };
  String? _nutriScore;
  String? _nutritionSource;
  bool _offLoading = false;
  bool _draftLoading = false;
  bool _summaryLoading = false;
  int _imports = 0;

  /// Champs nutritionnels saisis (clé → libellé, valeur maximale).
  static const _nutriFields = {
    'proteins': ('Protéines (g/100 g)', 100.0),
    'carbs': ('Glucides (g/100 g)', 100.0),
    'sugars': ('dont sucres (g/100 g)', 100.0),
    'fat': ('Lipides (g/100 g)', 100.0),
    'kcal': ('Énergie (kcal/100 g)', 900.0),
    'serving': ('Portion (g)', 2000.0),
    'netWeight': ('Poids net (g)', 50000.0),
  };

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
      _barcode.text = p.barcode ?? '';
      _brand.text = p.brand ?? '';
      _nameEn.text = p.nameEn ?? '';
      _summary.text = p.aiSummary ?? '';
      final n = p.nutrition;
      if (n != null) _fillNutrition(n);
    }
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _description,
      _price,
      _promo,
      _stock,
      _barcode,
      _brand,
      _nameEn,
      _summary,
      _allergens,
      ..._nutri.values,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _fillNutrition(Nutrition n) {
    String f(double? v) => v == null
        ? ''
        : (v == v.roundToDouble()
              ? '${v.toInt()}'
              : v.toStringAsFixed(1).replaceAll('.', ','));
    _nutri['proteins']!.text = f(n.proteins);
    _nutri['carbs']!.text = f(n.carbs);
    _nutri['sugars']!.text = f(n.sugars);
    _nutri['fat']!.text = f(n.fat);
    _nutri['kcal']!.text = f(n.kcal);
    _nutri['serving']!.text = f(n.servingG);
    _nutri['netWeight']!.text = f(n.netWeightG);
    _nutriScore = n.nutriScore;
    _allergens.text = n.allergens.join(', ');
    _nutritionSource = n.source;
  }

  /// Nutrition telle que saisie dans le formulaire.
  Nutrition _nutrition() {
    double? v(String k) => Validators.parseDecimal(_nutri[k]!.text);
    return Nutrition(
      proteins: v('proteins'),
      carbs: v('carbs'),
      sugars: v('sugars'),
      fat: v('fat'),
      kcal: v('kcal'),
      servingG: v('serving'),
      netWeightG: v('netWeight'),
      nutriScore: _nutriScore,
      allergens: _allergens.text
          .split(',')
          .map((a) => a.trim())
          .where((a) => a.isNotEmpty)
          .toList(),
      source: _nutritionSource,
    );
  }

  /// Remplit la fiche depuis Open Food Facts ; l'admin relit avant
  /// d'enregistrer.
  Future<void> _importOff() async {
    setState(() => _offLoading = true);
    try {
      final off = await Backend.I.openFoodFacts.fetch(_barcode.text);
      if (!mounted) return;
      setState(() {
        _barcode.text = off.barcode;
        if (off.name != null) _name.text = off.name!;
        if (off.brand != null) _brand.text = off.brand!;
        if (off.imageUrl != null && !_images.contains(off.imageUrl)) {
          _images.insert(0, off.imageUrl!);
        }
        _fillNutrition(off.nutrition);
        _summary.clear();
        _imports++;
      });
      showSnack(
        context,
        off.complete
            ? 'Fiche importée d\'Open Food Facts : relisez-la puis enregistrez.'
            : 'Fiche importée, valeurs manquantes : ${off.missing.join(', ')}. '
                  'Complétez-les à la main.',
      );
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _offLoading = false);
    }
  }

  Future<void> _draftWithAi() async {
    setState(() => _draftLoading = true);
    try {
      final d = await Backend.I.productAi.draftListing(
        name: _name.text,
        category: _category,
        price: Validators.parseDecimal(_price.text),
        brand: _brand.text,
        nutrition: _nutrition(),
      );
      if (!mounted) return;
      setState(() {
        _description.text = d.description;
        _nameEn.text = d.nameEn;
      });
      showSnack(
        context,
        'Texte proposé par l\'IA : relisez-le et modifiez-le.',
      );
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _draftLoading = false);
    }
  }

  Future<void> _summarizeWithAi() async {
    setState(() => _summaryLoading = true);
    try {
      final s = await Backend.I.productAi.nutritionSummary(
        name: _name.text,
        category: _category,
        price:
            Validators.parseDecimal(_promo.text) ??
            Validators.parseDecimal(_price.text),
        brand: _brand.text,
        nutrition: _nutrition(),
      );
      if (!mounted) return;
      setState(() => _summary.text = s);
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _summaryLoading = false);
    }
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
        barcode: _barcode.text,
        brand: _brand.text,
        nameEn: _nameEn.text,
        nutrition: _nutrition(),
        aiSummary: _summary.text,
      ),
      success: 'Produit enregistré.',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context);
  }

  /// Valeurs nutritionnelles (modifiables à la main) et résumé IA.
  Widget _nutritionSection() {
    final hasData =
        _nutri.values.any((c) => c.text.isNotEmpty) || _summary.text.isNotEmpty;
    return GfCard(
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        // Nouvelle clé seulement après un import, pour ouvrir la section
        // sans perdre le focus pendant la saisie.
        key: ValueKey('nutrition_$_imports'),
        initiallyExpanded: hasData,
        leading: const Icon(Icons.restaurant_menu, color: AppColors.navy),
        title: Text('Nutrition', style: AppText.subtitle(size: 15)),
        subtitle: Text(
          _nutritionSource == null
              ? 'Facultatif : compléments, barres, boissons'
              : 'Source : $_nutritionSource',
          style: AppText.label(size: 12),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(Gap.s, 0, Gap.s, Gap.s),
        children: [
          LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth >= 520
                  ? (c.maxWidth - 2 * Gap.s) / 3
                  : (c.maxWidth - Gap.s) / 2;
              return Wrap(
                spacing: Gap.s,
                runSpacing: Gap.s,
                children: [
                  for (final e in _nutriFields.entries)
                    SizedBox(
                      width: w,
                      child: TextFormField(
                        controller: _nutri[e.key],
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(labelText: e.value.$1),
                        validator: Validators.decimalRange(
                          field: 'La valeur',
                          min: 0,
                          max: e.value.$2,
                          optional: true,
                        ),
                      ),
                    ),
                  SizedBox(
                    width: w,
                    child: DropdownButtonFormField<String?>(
                      initialValue: _nutriScore,
                      decoration: const InputDecoration(
                        labelText: 'Nutri-Score',
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('Inconnu'),
                        ),
                        for (final s in ['a', 'b', 'c', 'd', 'e'])
                          DropdownMenuItem(
                            value: s,
                            child: Text(s.toUpperCase()),
                          ),
                        const DropdownMenuItem(
                          value: 'not-applicable',
                          child: Text('Non applicable'),
                        ),
                      ],
                      onChanged: (v) => setState(() => _nutriScore = v),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: Gap.s),
          TextFormField(
            controller: _allergens,
            decoration: const InputDecoration(
              labelText: 'Allergènes (séparés par des virgules)',
            ),
            validator: Validators.text(
              field: 'Les allergènes',
              max: 200,
              optional: true,
            ),
          ),
          const SizedBox(height: Gap.m),
          TextFormField(
            key: const Key('ai_summary_field'),
            controller: _summary,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Résumé pour le sportif (affiché aux abonnés)',
              helperText: 'Généré par l\'IA puis relu ; modifiable.',
            ),
            validator: Validators.text(
              field: 'Le résumé',
              max: 450,
              optional: true,
            ),
          ),
          if (Backend.I.productAi.enabled) ...[
            const SizedBox(height: Gap.s),
            _AiButton(
              key: const Key('ai_summary'),
              label: 'Générer le résumé avec l\'IA',
              icon: Icons.auto_awesome,
              loading: _summaryLoading,
              onPressed: _summarizeWithAi,
            ),
          ],
        ],
      ),
    );
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
          padding: pagePadding(context, maxWidth: 760, bottom: Gap.m),
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
              GfCard(
                color: AppColors.cream,
                padding: const EdgeInsets.all(Gap.s),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      key: const Key('barcode_field'),
                      controller: _barcode,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Code-barres (facultatif)',
                        prefixIcon: Icon(Icons.qr_code_2),
                      ),
                      validator: (v) {
                        final t = (v ?? '').replaceAll(RegExp(r'\s'), '');
                        return t.isEmpty || RegExp(r'^\d{8,14}$').hasMatch(t)
                            ? null
                            : '8 à 14 chiffres.';
                      },
                    ),
                    const SizedBox(height: Gap.s),
                    _AiButton(
                      key: const Key('off_import'),
                      label: 'Remplir depuis Open Food Facts',
                      icon: Icons.cloud_download_outlined,
                      loading: _offLoading,
                      onPressed: _importOff,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Nom, image, marque et nutrition depuis la base ouverte '
                      'Open Food Facts. Relisez avant d\'enregistrer.',
                      style: AppText.label(size: 12),
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
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Description'),
                validator: Validators.text(
                  field: 'La description',
                  min: 10,
                  max: 600,
                ),
              ),
              if (Backend.I.productAi.enabled) ...[
                const SizedBox(height: Gap.s),
                _AiButton(
                  key: const Key('ai_draft'),
                  label: 'Rédiger avec l\'IA',
                  icon: Icons.auto_awesome,
                  loading: _draftLoading,
                  onPressed: _draftWithAi,
                ),
              ],
              const SizedBox(height: Gap.m),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _brand,
                      decoration: const InputDecoration(labelText: 'Marque'),
                      validator: Validators.text(
                        field: 'La marque',
                        max: 40,
                        optional: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: Gap.s),
                  Expanded(
                    child: TextFormField(
                      controller: _nameEn,
                      decoration: const InputDecoration(
                        labelText: 'Nom en anglais (recherche)',
                      ),
                      validator: Validators.text(
                        field: 'Le nom anglais',
                        max: 80,
                        optional: true,
                      ),
                    ),
                  ),
                ],
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
              const SizedBox(height: Gap.m),
              _nutritionSection(),
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

/// Bouton secondaire avec indicateur de chargement (import, IA).
class _AiButton extends StatelessWidget {
  const _AiButton({
    super.key,
    required this.label,
    required this.icon,
    required this.loading,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: loading ? null : onPressed,
    icon: loading
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(icon),
    label: Text(loading ? 'Patientez…' : label),
  );
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
                        padding: pagePadding(
                          context,
                          maxWidth: 900,
                          bottom: Gap.m,
                        ),
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
