import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../models/enums.dart';
import '../../services/backend.dart';
import '../../services/calorie_service.dart';
import '../../services/smartwatch_service.dart';
import '../../services/weather_service.dart';
import '../../widgets/animations.dart';
import '../../widgets/bits.dart';
import '../../widgets/cards.dart';
import '../../widgets/common.dart';

/// Ouvre la feuille modale de gestion et connexion à la smartwatch Bluetooth.
Future<void> showSmartwatchModal(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const SmartwatchSheet(),
  );
}

/// Bouton d'accès rapide Smartwatch avec badge d'état pour les AppBars.
class SmartwatchAppBarButton extends StatelessWidget {
  const SmartwatchAppBarButton({super.key});

  @override
  Widget build(BuildContext context) {
    final sw = Backend.I.smartwatch;
    return ListenableBuilder(
      listenable: sw.connectedDevice,
      builder: (context, _) {
        final connected = sw.isConnected;
        return IconButton(
          tooltip: connected ? 'Montre connectée' : 'Connecter une smartwatch',
          onPressed: () => showSmartwatchModal(context),
          icon: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                connected ? Icons.watch : Icons.watch_outlined,
                color: connected ? AppColors.gold : AppColors.white,
              ),
              if (connected)
                Positioned(
                  right: 0,
                  top: 2,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.navy, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Contenu de la feuille de gestion de la montre connectée.
class SmartwatchSheet extends StatefulWidget {
  const SmartwatchSheet({super.key});

  @override
  State<SmartwatchSheet> createState() => _SmartwatchSheetState();
}

class _SmartwatchSheetState extends State<SmartwatchSheet> {
  WeatherInfo? _weather;
  bool _loadingWeather = true;

  @override
  void initState() {
    super.initState();
    _loadWeather();
  }

  Future<void> _loadWeather() async {
    try {
      final w = await Backend.I.weather.getCurrentWeather();
      if (mounted) {
        setState(() {
          _weather = w;
          _loadingWeather = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingWeather = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sw = Backend.I.smartwatch;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: Gap.m,
        left: Gap.m,
        right: Gap.m,
        bottom: MediaQuery.of(context).viewInsets.bottom + Gap.l,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.outline,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: Gap.m),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.navy.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.bluetooth_searching, color: AppColors.navy),
                  ),
                  const SizedBox(width: Gap.s),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Smartwatch & Télémétrie BLE', style: AppText.title(size: 18)),
                        Text(
                          'Profil standard GATT Heart Rate (0x180D)',
                          style: AppText.label(size: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: Gap.s),

              // Bannière conditions climatiques (API 2 : Open-Meteo)
              _buildWeatherBanner(),
              const SizedBox(height: Gap.m),

              // État connecté ou liste de scan
              ListenableBuilder(
                listenable: sw.connectedDevice,
                builder: (context, _) {
                  final dev = sw.connectedDevice.value;
                  if (dev != null) {
                    return _ConnectedDeviceView(device: dev);
                  }
                  return const _ScanDeviceView();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeatherBanner() {
    if (_loadingWeather) {
      return const SizedBox(
        height: 38,
        child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }
    final w = _weather;
    if (w == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Gap.m, vertical: Gap.s),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gold.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Icon(w.icon, color: AppColors.gold, size: 22),
          const SizedBox(width: Gap.s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Météo en direct · ${w.temperature.toStringAsFixed(1)}°C (Lac 2)',
                  style: AppText.subtitle(size: 13),
                ),
                Text(
                  '${w.conditionDescription} · Humidité ${w.humidity}% · Facteur thermique ×${w.thermalStressFactor.toStringAsFixed(2)}',
                  style: AppText.label(size: 11),
                ),
              ],
            ),
          ),
          Tooltip(
            message: 'API Open-Meteo (stress thermique sur la FC & calories)',
            child: Icon(Icons.info_outline, size: 16, color: AppColors.inkSoft),
          ),
        ],
      ),
    );
  }
}

/// Vue lorsque la montre est appairée et connectée.
class _ConnectedDeviceView extends StatelessWidget {
  const _ConnectedDeviceView({required this.device});
  final SmartwatchDevice device;

  @override
  Widget build(BuildContext context) {
    final sw = Backend.I.smartwatch;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GfCard(
          color: AppColors.navy,
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.bluetooth_connected, color: AppColors.success, size: 22),
                  ),
                  const SizedBox(width: Gap.s),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          device.name,
                          style: AppText.subtitle(color: AppColors.white, size: 16),
                        ),
                        Text(
                          '${device.brand} · ${device.macAddress}',
                          style: AppText.label(color: AppColors.cream, size: 11),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.battery_std, color: AppColors.gold, size: 18),
                      Text(
                        '${device.batteryLevel}%',
                        style: AppText.label(color: AppColors.white, size: 12),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(color: Color(0xFF1E3A5F), height: Gap.l),
              // Métriques en direct
              ListenableBuilder(
                listenable: sw.telemetry,
                builder: (context, _) {
                  final telem = sw.telemetry.value;
                  final hr = telem?.heartRate ?? 0;
                  final zone = telem?.zone.label ?? 'En attente';
                  final cal = telem?.caloriesInt ?? 0;
                  final steps = telem?.stepCount ?? 0;

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _StatItem(
                        icon: Icons.favorite,
                        iconColor: AppColors.red,
                        value: hr > 0 ? '$hr' : '--',
                        unit: 'BPM',
                        label: zone,
                      ),
                      _StatItem(
                        icon: Icons.local_fire_department,
                        iconColor: AppColors.gold,
                        value: '$cal',
                        unit: 'kcal',
                        label: 'Dépense Keytel',
                      ),
                      _StatItem(
                        icon: Icons.directions_walk,
                        iconColor: AppColors.success,
                        value: '$steps',
                        unit: 'pas',
                        label: 'Podomètre',
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: Gap.m),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.red,
              side: const BorderSide(color: AppColors.red),
            ),
            onPressed: sw.disconnect,
            icon: const Icon(Icons.link_off),
            label: const Text('Déconnecter la montre'),
          ),
        ),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.unit,
    required this.label,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final String unit;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: iconColor, size: 18),
            const SizedBox(width: 4),
            Text(value, style: AppText.stat(color: AppColors.white, size: 20)),
            const SizedBox(width: 2),
            Text(unit, style: AppText.label(color: AppColors.cream, size: 10)),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppText.label(color: AppColors.cream, size: 10),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// Vue de recherche et de sélection des montres Bluetooth disponibles.
class _ScanDeviceView extends StatelessWidget {
  const _ScanDeviceView();

  @override
  Widget build(BuildContext context) {
    final sw = Backend.I.smartwatch;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Appareils Bluetooth détectés', style: AppText.subtitle(size: 15)),
            ListenableBuilder(
              listenable: sw.isScanning,
              builder: (context, _) {
                if (sw.isScanning.value) {
                  return const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  );
                }
                return TextButton.icon(
                  onPressed: sw.startScan,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Actualiser'),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: Gap.s),
        ListenableBuilder(
          listenable: Listenable.merge([sw.availableDevices, sw.isScanning]),
          builder: (context, _) {
            final devices = sw.availableDevices.value;
            if (sw.isScanning.value && devices.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: Gap.l),
                child: Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: Gap.s),
                      Text('Recherche des montres BLE à proximité…'),
                    ],
                  ),
                ),
              );
            }

            if (devices.isEmpty) {
              return GfCard(
                child: Column(
                  children: [
                    const Icon(Icons.bluetooth_searching, size: 44, color: AppColors.outline),
                    const SizedBox(height: Gap.s),
                    Text('Aucune montre connectée pour le moment', style: AppText.subtitle(size: 14)),
                    const SizedBox(height: 4),
                    Text(
                      'Appuyez sur « Lancer la recherche » pour scanner les montres Bluetooth BLE.',
                      style: AppText.label(size: 12),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: Gap.m),
                    ElevatedButton.icon(
                      onPressed: sw.startScan,
                      icon: const Icon(Icons.search),
                      label: const Text('Lancer la recherche Bluetooth'),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: [
                for (final d in devices)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Gap.s),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.outline),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.navy.withOpacity(0.08),
                          child: const Icon(Icons.watch, color: AppColors.navy),
                        ),
                        title: Text(d.name, style: AppText.subtitle(size: 14)),
                        subtitle: Text(
                          '${d.brand} · ${d.rssi} dBm · Batterie ${d.batteryLevel}%',
                          style: AppText.label(size: 11),
                        ),
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            minimumSize: Size.zero,
                          ),
                          onPressed: () {
                            sw.connect(d);
                            Navigator.pop(context);
                          },
                          child: const Text('Connecter'),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
