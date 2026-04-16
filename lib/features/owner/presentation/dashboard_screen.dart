import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/owner_repository.dart';
import '../../staff/presentation/providers/staff_providers.dart';
import 'providers/owner_providers.dart';

class OwnerDashboardScreen extends ConsumerStatefulWidget {
  const OwnerDashboardScreen({super.key});

  @override
  ConsumerState<OwnerDashboardScreen> createState() =>
      _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends ConsumerState<OwnerDashboardScreen> {
  static const _kPageBg = Color(0xFFF8F9FA);
  static const _kPointBlue = Color(0xFF185FA5);

  Future<_StoreHeaderView> _loadStoreHeader() async {
    final supabase = Supabase.instance.client;
    final rows = await supabase
        .from('stores')
        .select('name, logo_url, brand_color')
        .limit(1) as List<dynamic>;
    if (rows.isEmpty) {
      return const _StoreHeaderView(
        name: 'متجري',
        logoUrl: null,
        brandColor: _kPointBlue,
      );
    }
    final m = Map<String, dynamic>.from(rows.first as Map);
    final name = (m['name'] as String?)?.trim();
    final logoUrl = (m['logo_url'] as String?)?.trim();
    final brandHex = (m['brand_color'] as String?)?.trim();
    return _StoreHeaderView(
      name: name == null || name.isEmpty ? 'متجري' : name,
      logoUrl: (logoUrl == null || logoUrl.isEmpty) ? null : logoUrl,
      brandColor: _parseHexColor(brandHex, fallback: _kPointBlue),
    );
  }

  @override
  Widget build(BuildContext context) {
    final range = ref.watch(ownerDateRangeProvider);
    final dashAsync = ref.watch(ownerDashboardProvider((from: range.$1, to: range.$2)));
    final todayAsync = ref.watch(ownerTodayOverviewProvider);
    final staffMember = ref.watch(staffMemberProvider).maybeWhen(
          data: (m) => m,
          orElse: () => null,
        );
    final isOwnerOrManager = () {
      final r = (staffMember?.role ?? '').toLowerCase();
      return r == 'owner' || r == 'manager';
    }();

    return Scaffold(
      backgroundColor: _kPageBg,
      body: SafeArea(
        child: RefreshIndicator(
          color: _kPointBlue,
          onRefresh: () async {
            ref.invalidate(ownerTodayOverviewProvider);
            ref.invalidate(ownerDashboardProvider);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
            children: [
              FutureBuilder<_StoreHeaderView>(
                future: _loadStoreHeader(),
                builder: (context, snap) {
                  final header = snap.data ??
                      const _StoreHeaderView(
                        name: 'متجري',
                        logoUrl: null,
                        brandColor: _kPointBlue,
                      );
                  return _Header(
                    brandColor: header.brandColor,
                    storeName: header.name,
                    logoUrl: header.logoUrl,
                    dateLine: _arabicTodayLine(),
                    onNotifications: () {},
                  );
                },
              ),
              const SizedBox(height: 16),
              todayAsync.when(
                loading: () => _metricsSkeleton(),
                error: (e, _) => _errorCard(
                  title: 'تعذر تحميل الأرقام',
                  details: '$e',
                  onRetry: () => ref.invalidate(ownerTodayOverviewProvider),
                ),
                data: (stats) {
                  final metrics = <_MetricCardData>[
                    _MetricCardData(
                      label: 'مبيعات اليوم',
                      value: _money(stats.todaySalesTotal),
                      icon: Icons.payments_rounded,
                      bg: const Color(0xFFE6F1FB),
                      fg: const Color(0xFF0C447C),
                      changeText: '↗︎ +0%',
                    ),
                    _MetricCardData(
                      label: 'العملاء النشطون',
                      value: '${stats.totalCustomers}',
                      icon: Icons.people_rounded,
                      bg: const Color(0xFFE1F5EE),
                      fg: const Color(0xFF085041),
                      changeText: '↗︎ +0%',
                    ),
                    const _MetricCardData(
                      label: 'اشتراكات جديدة',
                      value: '0',
                      icon: Icons.credit_card_rounded,
                      bg: Color(0xFFFAEEDA),
                      fg: Color(0xFF633806),
                      changeText: '→ 0%',
                    ),
                    _MetricCardData(
                      label: 'إجمالي الكاش باك',
                      value: _money(stats.todayCashbackTotal),
                      icon: Icons.percent_rounded,
                      bg: const Color(0xFFEEEDFE),
                      fg: const Color(0xFF3C3489),
                      changeText: '↗︎ +0%',
                    ),
                  ];
                  return _MetricGrid(cards: metrics);
                },
              ),
              const SizedBox(height: 14),
              if (isOwnerOrManager)
                dashAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (d) {
                    if (d.fraudAlertsCount <= 0) return const SizedBox.shrink();
                    return _FraudBanner(
                      count: d.fraudAlertsCount,
                      onTap: () => context.push('/staff/fraud'),
                    );
                  },
                ),
              const SizedBox(height: 14),
              _RecentTransactions(
                onSeeAll: () => context.push('/staff/transactions'),
                loader: () async {
                  final repo = ref.read(ownerRepositoryProvider);
                  return repo.fetchTransactionsPage(offset: 0, limit: 5);
                },
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _OwnerBottomNav(
        current: _OwnerTab.home,
        onSelect: (t) {
          switch (t) {
            case _OwnerTab.home:
              context.go('/staff/dashboard');
              return;
            case _OwnerTab.customers:
              context.go('/staff/customers');
              return;
            case _OwnerTab.staff:
              context.go('/owner/staff');
              return;
            case _OwnerTab.settings:
              context.go('/owner/settings');
              return;
          }
        },
      ),
    );
  }

  Widget _metricsSkeleton() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.18,
      children: List.generate(
        4,
        (_) => Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
        ),
      ),
    );
  }
}

enum _OwnerTab { home, customers, staff, settings }

class _OwnerBottomNav extends StatelessWidget {
  const _OwnerBottomNav({
    required this.current,
    required this.onSelect,
  });

  final _OwnerTab current;
  final ValueChanged<_OwnerTab> onSelect;

  static const _kActive = Color(0xFF185FA5);

  @override
  Widget build(BuildContext context) {
    Widget item({
      required _OwnerTab tab,
      required IconData icon,
      required String label,
    }) {
      final on = tab == current;
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => onSelect(tab),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: on ? _kActive : const Color(0xFF94A3B8)),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: on ? _kActive : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              item(tab: _OwnerTab.home, icon: Icons.home_rounded, label: 'الرئيسية'),
              item(tab: _OwnerTab.customers, icon: Icons.people_rounded, label: 'العملاء'),
              item(tab: _OwnerTab.staff, icon: Icons.badge_rounded, label: 'الموظفون'),
              item(tab: _OwnerTab.settings, icon: Icons.settings_rounded, label: 'الإعدادات'),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.brandColor,
    required this.storeName,
    required this.logoUrl,
    required this.dateLine,
    required this.onNotifications,
  });

  final Color brandColor;
  final String storeName;
  final String? logoUrl;
  final String dateLine;
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              _StoreLogoCircle(
                size: 44,
                brandColor: brandColor,
                logoUrl: logoUrl,
                fallbackText: _initials(storeName),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      storeName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateLine,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onNotifications,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              color: Color(0xFF0F172A),
            ),
          ),
        ),
      ],
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.cards});

  final List<_MetricCardData> cards;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.18,
      children: cards.map((c) => _MetricCard(data: c)).toList(),
    );
  }
}

class _MetricCardData {
  const _MetricCardData({
    required this.label,
    required this.value,
    required this.icon,
    required this.bg,
    required this.fg,
    required this.changeText,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color bg;
  final Color fg;
  final String changeText;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.data});

  final _MetricCardData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: data.bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(data.icon, color: data.fg, size: 22),
          ),
          const Spacer(),
          Text(
            data.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: data.fg,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            data.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
              height: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: data.bg.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  data.changeText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: data.fg,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FraudBanner extends StatelessWidget {
  const _FraudBanner({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFCEBEB),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF6B7B7)),
          ),
          child: Row(
            children: [
              const Icon(Icons.report_gmailerrorred_rounded, color: Color(0xFFA32D2D)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '! تنبيه احتيال — راجع المعاملات المشبوهة ($count)',
                  style: const TextStyle(
                    color: Color(0xFFA32D2D),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFFA32D2D)),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentTransactions extends StatelessWidget {
  const _RecentTransactions({
    required this.onSeeAll,
    required this.loader,
  });

  final VoidCallback onSeeAll;
  final Future<List<TransactionListRow>> Function() loader;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'آخر المعاملات',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              TextButton(
                onPressed: onSeeAll,
                child: const Text(
                  'عرض الكل',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF185FA5),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FutureBuilder<List<TransactionListRow>>(
            future: loader(),
            builder: (context, snap) {
              if (!snap.hasData) {
                return Column(
                  children: List.generate(
                    5,
                    (_) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Container(
                        height: 54,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                );
              }
              final items = snap.data ?? const [];
              if (items.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Text(
                    'لا توجد معاملات بعد.',
                    style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center,
                  ),
                );
              }
              return Column(
                children: items.map((r) => _TxRow(row: r)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TxRow extends StatelessWidget {
  const _TxRow({required this.row});

  final TransactionListRow row;

  @override
  Widget build(BuildContext context) {
    final t = row.transaction;
    final type = (t.type).toLowerCase();
    final badge = switch (type) {
      'purchase' => ('شراء', const Color(0xFFEFF6FF), const Color(0xFF185FA5)),
      'redeem' => ('استرداد', const Color(0xFFFFF7ED), const Color(0xFF9A3412)),
      'subscription' => ('باقة', const Color(0xFFEEEDFE), const Color(0xFF3C3489)),
      _ => ('عملية', const Color(0xFFF1F5F9), const Color(0xFF334155)),
    };
    final dt = t.createdAt.toLocal();
    final time = DateFormat.Hm('ar').format(dt);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          _InitialsCircle(text: _initials(row.customerName)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.customerName.isEmpty ? '—' : row.customerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: badge.$2,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        badge.$1,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: badge.$3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      time,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              _money(t.amount),
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InitialsCircle extends StatelessWidget {
  const _InitialsCircle({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: const BoxDecoration(
        color: Color(0xFFEFF6FF),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w900,
          color: Color(0xFF185FA5),
        ),
      ),
    );
  }
}

class _StoreLogoCircle extends StatelessWidget {
  const _StoreLogoCircle({
    required this.size,
    required this.brandColor,
    required this.logoUrl,
    required this.fallbackText,
  });

  final double size;
  final Color brandColor;
  final String? logoUrl;
  final String fallbackText;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: brandColor,
      ),
      alignment: Alignment.center,
      child: Text(
        fallbackText,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _StoreHeaderView {
  const _StoreHeaderView({
    required this.name,
    required this.logoUrl,
    required this.brandColor,
  });

  final String name;
  final String? logoUrl;
  final Color brandColor;
}

Widget _errorCard({
  required String title,
  required String details,
  required VoidCallback onRetry,
}) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE5E7EB)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          details,
          style: const TextStyle(color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: onRetry,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF185FA5),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: const Text('إعادة المحاولة'),
        ),
      ],
    ),
  );
}

String _arabicTodayLine() {
  final now = DateTime.now();
  return DateFormat('EEEE، d MMMM', 'ar').format(now);
}

String _money(double v) {
  final f = NumberFormat.currency(locale: 'ar', symbol: 'ر.س', decimalDigits: 0);
  return f.format(v);
}

String _initials(String name) {
  final p = name.trim().split(RegExp(r'\s+'));
  if (p.isEmpty) return '؟';
  if (p.length == 1) return p[0].isEmpty ? '؟' : p[0][0].toUpperCase();
  final a = p.first.isEmpty ? '' : p.first[0];
  final b = p.last.isEmpty ? '' : p.last[0];
  final r = '$a$b';
  return r.isEmpty ? '؟' : r.toUpperCase();
}

Color _parseHexColor(String? hex, {Color fallback = const Color(0xFF185FA5)}) {
  if (hex == null) return fallback;
  var h = hex.trim();
  if (h.isEmpty) return fallback;
  if (h.startsWith('#')) h = h.substring(1);
  if (h.length == 6) h = 'FF$h';
  if (h.length != 8) return fallback;
  final v = int.tryParse(h, radix: 16);
  if (v == null) return fallback;
  return Color(v);
}
