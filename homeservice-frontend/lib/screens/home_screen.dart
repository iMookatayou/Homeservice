import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import '../state/auth_state.dart';
import '../state/weather_provider.dart';
import '../models/weather.dart';

class AppColors {
  static const deepNavy = Color(0xFF0F2D5C);
  static const softBlue = Color(0xFF2D5BFF);
  static const mint = Color(0xFF14B8A6);
  static const cardBorder = Color(0xFFE7ECF4);
  static const textMuted = Color(0xFF6B7280);
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final user = auth.user;
    final weather = ref.watch(currentWeatherProvider);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.deepNavy,
        titleSpacing: 16,
        title: const Text('HomeService'),
        actions: [
          IconButton(
            tooltip: 'Logout',
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (!context.mounted) return;
              context.go('/login');
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF8FAFC),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(locationProvider);
          ref.invalidate(currentWeatherProvider);
          await ref.read(currentWeatherProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _WelcomeHeader(name: user?.name),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Current Weather',
              subtitle: 'Local conditions',
              trailing: const _AutoSyncChip(),
              child: _WeatherBody(weather: weather),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Tools',
              subtitle: 'Manage your home quickly',
              child: const _QuickToolsSection(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _WelcomeHeader extends StatelessWidget {
  const _WelcomeHeader({this.name});
  final String? name;

  @override
  Widget build(BuildContext context) {
    final now = DateFormat('EEE, MMM d • HH:mm').format(DateTime.now());
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Color(0xFFF1F5FF)],
        ),
        border: Border.all(color: AppColors.cardBorder),
      ),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            height: 52,
            width: 52,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.cardBorder),
              boxShadow: const [
                BoxShadow(
                  blurRadius: 10,
                  color: Color(0x14000000),
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.person_pin,
              size: 32,
              color: AppColors.deepNavy,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, ${name ?? "Guest"}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.deepNavy,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Ready to manage your home • $now',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const _PillChip(
            icon: Icons.verified_user_outlined,
            label: 'Secure',
            color: AppColors.mint,
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _SectionHeader(title: title, subtitle: subtitle),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 8),
            const Divider(height: 24, color: AppColors.cardBorder),
            child,
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.subtitle});
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppColors.deepNavy,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
          ),
        ],
      ],
    );
  }
}

class _AutoSyncChip extends ConsumerWidget {
  const _AutoSyncChip({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const _PillChip(
      icon: Icons.sync,
      label: 'Auto-sync',
      color: AppColors.softBlue,
    );
  }
}

class _PillChip extends StatelessWidget {
  const _PillChip({
    required this.icon,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeatherBody extends StatelessWidget {
  const _WeatherBody({required this.weather});
  final AsyncValue<WeatherNow> weather;

  @override
  Widget build(BuildContext context) {
    return weather.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => _EmptyState(
        icon: Icons.cloud_off,
        title: 'Failed to load weather',
        message: '$e',
        actionLabel: 'Retry',
        onAction: () {},
      ),
      data: (w) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _MetricTile(
                    icon: Icons.thermostat_outlined,
                    title: 'Temperature',
                    value: '${w.temperature.toStringAsFixed(1)} °C',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricTile(
                    icon: Icons.wb_sunny_outlined,
                    title: 'Condition',
                    value: w.conditionLabel,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _InfoRow(
                    icon: Icons.air,
                    label: 'Wind',
                    value: '${w.windSpeed.toStringAsFixed(1)} m/s',
                  ),
                ),
                Expanded(
                  child: _InfoRow(
                    icon: Icons.schedule_outlined,
                    label: 'Updated',
                    value: DateFormat('HH:mm').format(w.time),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.title,
    required this.value,
  });
  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: AppColors.softBlue),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppColors.deepNavy,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textMuted),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.deepNavy),
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Column(
        children: [
          Icon(icon, size: 40, color: AppColors.textMuted),
          const SizedBox(height: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.deepNavy,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: onAction,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.softBlue,
                side: const BorderSide(color: AppColors.softBlue),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

// ===================================================================
// =====================  Quick Tools (TH captions)  ==================
// ===================================================================

class _QuickToolsSection extends StatelessWidget {
  const _QuickToolsSection();

  @override
  Widget build(BuildContext context) {
    final items = <_ToolItem>[
      const _ToolItem(
        Icons.handyman,
        'Contractors',
        '/contractors',
        'เรียกช่างถึงบ้าน',
      ),
      const _ToolItem(
        Icons.event_note,
        'Important Notes',
        '/notes',
        'บันทึกสำคัญกันลืม',
      ),
      const _ToolItem(
        Icons.videocam_outlined,
        'Home Cameras',
        '/cameras',
        'ดูกล้องวงจรปิดที่บ้าน',
      ),
      const _ToolItem(
        Icons.shopping_cart_checkout,
        'Purchases',
        '/purchases',
        'ติดตามของที่ซื้อเข้าบ้าน',
      ),
      const _ToolItem(
        Icons.receipt_long,
        'Bills',
        '/bills',
        'บิลค่าใช้จ่ายประจำ',
      ),
      const _ToolItem(Icons.calculate, 'Calculator', '/calc', 'เครื่องคิดเลข'),
      const _ToolItem(
        Icons.medical_services_outlined,
        'Medicine Stock',
        '/meds',
        'เช็คสต็อกยาประจำบ้าน',
      ),
      const _ToolItem(
        Icons.trending_up,
        'Household Stocks',
        '/stocks',
        'หุ้นน่าซื้อประจำบ้าน',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LauncherSearch(
          hintText: 'Search contractors (electrician, plumber, AC...)',
          onSubmit: (q) => _goTo(context, '/contractors', query: q),
        ),
        const SizedBox(height: 12),
        _ToolGrid(items: items, large: true),
      ],
    );
  }

  void _goTo(BuildContext context, String route, {String? query}) {
    final uri = Uri(
      path: route,
      queryParameters: {
        if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
      },
    ).toString();
    context.push(uri);
  }
}

class _LauncherSearch extends StatefulWidget {
  const _LauncherSearch({
    required this.hintText,
    required this.onSubmit,
    super.key,
  });
  final String hintText;
  final void Function(String query) onSubmit;

  @override
  State<_LauncherSearch> createState() => _LauncherSearchState();
}

class _LauncherSearchState extends State<_LauncherSearch> {
  final _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onSubmitted: widget.onSubmit,
      decoration: InputDecoration(
        hintText: widget.hintText,
        prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
        filled: true,
        fillColor: const Color(0xFFF7FAFF),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.softBlue),
        ),
      ),
    );
  }
}

class _ToolGrid extends StatelessWidget {
  const _ToolGrid({required this.items, this.large = false});

  final List<_ToolItem> items;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final iconSize = large ? 36.0 : 30.0;
    final aspect = large ? 1.1 : 1.25;

    return GridView.builder(
      shrinkWrap: true,
      itemCount: items.length,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: aspect,
      ),
      itemBuilder: (_, i) =>
          _ToolCard(item: items[i], iconSize: iconSize, large: large),
    );
  }
}

class _ToolItem {
  final IconData icon;
  final String label;
  final String route;
  final String caption;
  const _ToolItem(this.icon, this.label, this.route, this.caption);
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({
    required this.item,
    required this.iconSize,
    required this.large,
  });
  final _ToolItem item;
  final double iconSize;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final titleStyle = large
        ? Theme.of(context).textTheme.titleMedium
        : Theme.of(context).textTheme.titleSmall;

    return InkWell(
      onTap: () => context.push(item.route),
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(item.icon, size: iconSize, color: AppColors.softBlue),
              const SizedBox(height: 10),
              Text(
                item.label,
                textAlign: TextAlign.center,
                style: titleStyle?.copyWith(
                  color: AppColors.deepNavy,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item.caption,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
