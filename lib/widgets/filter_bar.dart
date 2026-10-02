import 'package:flutter/material.dart';

import '../core/responsive.dart';
import '../core/theme.dart';
import '../models/prefs.dart';
import 'animations.dart';

/// Option d'un groupe de filtres.
class FilterOption {
  const FilterOption(this.key, this.label, {this.icon, this.caption});
  final String key;
  final String label;
  final IconData? icon;

  /// Petite précision sous le libellé (ex. date d'un jour).
  final String? caption;
}

/// Groupe de filtres affiché dans la feuille « Filtres ».
class FilterGroup {
  const FilterGroup({
    required this.id,
    required this.title,
    required this.options,
    this.icon,
    this.single = false,
    this.help,
    this.grid = false,
  });

  final String id;
  final String title;
  final IconData? icon;
  final List<FilterOption> options;

  /// Un seul choix possible dans ce groupe.
  final bool single;

  /// Explication courte sous le titre (« Je dispose de… »).
  final String? help;

  /// Affichage en tuiles régulières (jours de la semaine).
  final bool grid;
}

/// Barre de recherche + bouton « Filtres » (avec le nombre de filtres
/// actifs) + rappel des filtres actifs sous forme d'étiquettes
/// supprimables. Remplace les rangées de boutons à faire défiler.
class FilterSearchBar extends StatelessWidget {
  const FilterSearchBar({
    super.key,
    required this.groups,
    required this.values,
    required this.onChanged,
    required this.resultCount,
    this.hint = 'Rechercher',
    this.query,
    this.onQuery,
    this.trailing,
    this.maxWidth = 1200,
  });

  final List<FilterGroup> groups;
  final FilterValues values;
  final ValueChanged<FilterValues> onChanged;

  /// Nombre de résultats pour des filtres donnés (aperçu en direct).
  final int Function(FilterValues) resultCount;
  final String hint;

  /// Contrôleur de recherche (null : pas de champ de recherche).
  final TextEditingController? query;
  final ValueChanged<String>? onQuery;
  final Widget? trailing;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final pad = pagePadding(context, maxWidth: maxWidth, top: Gap.s, bottom: 0);
    final count = values.activeCount;
    final active = [
      for (final g in groups)
        for (final o in g.options)
          if (values.has(g.id, o.key)) (g, o),
    ];
    final q = query;
    return Padding(
      padding: pad,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (q != null)
                Expanded(
                  child: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: q,
                    builder: (context, v, _) => TextField(
                      controller: q,
                      onChanged: onQuery,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: hint,
                        prefixIcon: const Icon(Icons.search),
                        isDense: true,
                        suffixIcon: v.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Effacer',
                                icon: const Icon(Icons.close),
                                onPressed: () {
                                  q.clear();
                                  onQuery?.call('');
                                },
                              ),
                      ),
                    ),
                  ),
                )
              else
                const Spacer(),
              const SizedBox(width: Gap.s),
              _FilterButton(
                count: count,
                onTap: () async {
                  final next = await showFilterSheet(
                    context,
                    groups: groups,
                    initial: values,
                    resultCount: resultCount,
                  );
                  if (next != null) onChanged(next);
                },
              ),
              ?trailing,
            ],
          ),
          AnimatedSize(
            duration: kAnim,
            curve: kCurve,
            alignment: Alignment.topCenter,
            child: active.isEmpty
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: Gap.s),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        for (final (g, o) in active)
                          InputChip(
                            key: ValueKey('active_${g.id}_${o.key}'),
                            label: Text(o.label),
                            avatar: o.icon == null
                                ? null
                                : Icon(o.icon, size: 16, color: AppColors.navy),
                            labelStyle: AppText.label(
                              color: AppColors.navy,
                              size: 13,
                            ),
                            backgroundColor: AppColors.cream,
                            side: BorderSide.none,
                            deleteIcon: const Icon(Icons.close, size: 16),
                            deleteButtonTooltipMessage: 'Retirer ce filtre',
                            onDeleted: () =>
                                onChanged(values.toggled(g.id, o.key)),
                          ),
                        TextButton(
                          key: const Key('filters_clear'),
                          onPressed: () => onChanged({}),
                          child: const Text('Tout effacer'),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final on = count > 0;
    return Badge(
      isLabelVisible: on,
      label: Text('$count'),
      backgroundColor: AppColors.red,
      textColor: AppColors.white,
      child: OutlinedButton.icon(
        key: const Key('filters_button'),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          backgroundColor: on ? AppColors.navy : AppColors.white,
          foregroundColor: on ? AppColors.white : AppColors.navy,
          side: const BorderSide(color: AppColors.navy),
          padding: const EdgeInsets.symmetric(horizontal: Gap.m),
        ),
        onPressed: onTap,
        icon: const Icon(Icons.tune, size: 20),
        label: const Text('Filtres'),
      ),
    );
  }
}

/// Feuille des filtres : groupes clairement titrés, aperçu en direct du
/// nombre de résultats, « Réinitialiser » et « Voir N résultats ».
Future<FilterValues?> showFilterSheet(
  BuildContext context, {
  required List<FilterGroup> groups,
  required FilterValues initial,
  required int Function(FilterValues) resultCount,
}) {
  return showModalBottomSheet<FilterValues>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: AppColors.background,
    constraints: const BoxConstraints(maxWidth: 720),
    builder: (_) => _FilterSheet(
      groups: groups,
      initial: initial,
      resultCount: resultCount,
    ),
  );
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({
    required this.groups,
    required this.initial,
    required this.resultCount,
  });
  final List<FilterGroup> groups;
  final FilterValues initial;
  final int Function(FilterValues) resultCount;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late FilterValues _v = {
    for (final e in widget.initial.entries) e.key: {...e.value},
  };

  @override
  Widget build(BuildContext context) {
    final n = widget.resultCount(_v);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scroll) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.m, 0, Gap.s, Gap.s),
            child: Row(
              children: [
                Expanded(
                  child: Text('Filtres', style: AppText.title(size: 20)),
                ),
                TextButton(
                  key: const Key('filters_reset'),
                  onPressed: _v.isEmpty ? null : () => setState(() => _v = {}),
                  child: const Text('Réinitialiser'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(Gap.m, Gap.s, Gap.m, Gap.m),
              children: [
                for (final g in widget.groups) ...[
                  const SizedBox(height: Gap.s),
                  Row(
                    children: [
                      if (g.icon != null) ...[
                        Icon(g.icon, size: 18, color: AppColors.red),
                        const SizedBox(width: 6),
                      ],
                      Expanded(child: Text(g.title, style: AppText.subtitle())),
                      if (_v.isActive(g.id))
                        Text(
                          '${_v.of(g.id).length} choisi${_v.of(g.id).length > 1 ? 's' : ''}',
                          style: AppText.label(size: 12, color: AppColors.red),
                        ),
                    ],
                  ),
                  if (g.help != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(g.help!, style: AppText.label(size: 12)),
                    ),
                  const SizedBox(height: Gap.s),
                  if (g.grid) _grid(g) else _chips(g),
                  const SizedBox(height: Gap.s),
                ],
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Gap.m, Gap.s, Gap.m, Gap.m),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  key: const Key('filters_apply'),
                  onPressed: () => Navigator.pop(context, _v),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      n == 0
                          ? 'Aucun résultat'
                          : 'Voir $n résultat${n > 1 ? 's' : ''}',
                      key: ValueKey(n),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _toggle(FilterGroup g, FilterOption o) =>
      setState(() => _v = _v.toggled(g.id, o.key, single: g.single));

  Widget _chips(FilterGroup g) => Wrap(
    spacing: Gap.s,
    runSpacing: Gap.s,
    children: [
      for (final o in g.options)
        FilterChip(
          key: ValueKey('opt_${g.id}_${o.key}'),
          label: Text(o.label),
          avatar: o.icon == null ? null : Icon(o.icon, size: 18),
          showCheckmark: o.icon == null,
          selected: _v.has(g.id, o.key),
          onSelected: (_) => _toggle(g, o),
          selectedColor: AppColors.navy,
          checkmarkColor: AppColors.white,
          backgroundColor: AppColors.white,
          labelStyle: AppText.body(
            size: 14,
            color: _v.has(g.id, o.key) ? AppColors.white : AppColors.navy,
          ),
          iconTheme: IconThemeData(
            color: _v.has(g.id, o.key) ? AppColors.white : AppColors.navy,
          ),
          side: const BorderSide(color: AppColors.outline),
        ),
    ],
  );

  /// Tuiles régulières : idéal pour les jours (« Lun » + date).
  Widget _grid(FilterGroup g) => LayoutBuilder(
    builder: (context, c) {
      const gap = 6.0;
      final cols = g.options.length.clamp(1, 7);
      final w = (c.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final o in g.options)
            _DayTile(
              key: ValueKey('opt_${g.id}_${o.key}'),
              width: w,
              option: o,
              selected: _v.has(g.id, o.key),
              onTap: () => _toggle(g, o),
            ),
        ],
      );
    },
  );
}

class _DayTile extends StatelessWidget {
  const _DayTile({
    super.key,
    required this.width,
    required this.option,
    required this.selected,
    required this.onTap,
  });
  final double width;
  final FilterOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColors.white : AppColors.navy;
    return Semantics(
      button: true,
      selected: selected,
      label: '${option.label} ${option.caption ?? ''}',
      child: Material(
        color: selected ? AppColors.navy : AppColors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: AnimatedContainer(
            duration: kAnim,
            width: width,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? AppColors.navy : AppColors.outline,
              ),
            ),
            child: Column(
              children: [
                Text(
                  option.label,
                  style: AppText.subtitle(size: 14, color: fg),
                ),
                if (option.caption != null)
                  Text(
                    option.caption!,
                    style: AppText.label(size: 11, color: fg),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
