import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../l10n/app_localizations.dart';

class OwnerDashboardScreen extends StatefulWidget {
  const OwnerDashboardScreen({super.key});
  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> {
  bool _loading = true;
  String? _error;
  int _totalCustomers = 0;
  int _todayTransactions = 0;
  double _todaySales = 0;
  double _todayCashback = 0;
  int _totalStaff = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      if (!mounted) return;
      setState(() {
        _loading = true;
        _error = null;
      });

      final supabase = Supabase.instance.client;
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);

      // Customers count
      final customers = await supabase.from('customers').select('id');
      _totalCustomers = (customers as List).length;

      // Staff count
      final staff = await supabase
          .from('staff')
          .select('id')
          .eq('is_active', true);
      _totalStaff = (staff as List).length;

      // Today transactions
      final txList = await supabase
          .from('transactions')
          .select('amount, cashback_earned, type')
          .gte('created_at', '${todayStr}T00:00:00')
          .eq('is_undone', false);

      final txs = txList as List;
      _todayTransactions = txs.length;
      _todaySales = 0;
      _todayCashback = 0;

      for (final txRaw in txs) {
        if (txRaw is! Map) continue;
        final tx = Map<String, dynamic>.from(txRaw);
        if (tx['type'] == 'purchase') {
          _todaySales += (tx['amount'] as num?)?.toDouble() ?? 0;
        }
        _todayCashback += (tx['cashback_earned'] as num?)?.toDouble() ?? 0;
      }

      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final dateLine =
        '${l10n.today} — ${DateFormat.yMd(localeTag).format(DateTime.now())}';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          l10n.dashboard,
          style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            color: AppColors.primary,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        l10n.error,
                        style: GoogleFonts.cairo(color: AppColors.error),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _loadData,
                        child: Text(
                          l10n.retry,
                          style: GoogleFonts.cairo(),
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Text(
                        dateLine,
                        style: GoogleFonts.cairo(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.22,
                        children: [
                          _StatCard(
                            icon: Icons.people_rounded,
                            iconColor: AppColors.primary,
                            label: l10n.statTotalCustomers,
                            value: '$_totalCustomers',
                          ),
                          _StatCard(
                            icon: Icons.badge_rounded,
                            iconColor: AppColors.success,
                            label: l10n.statStaffMembers,
                            value: '$_totalStaff',
                          ),
                          _StatCard(
                            icon: Icons.receipt_rounded,
                            iconColor: const Color(0xFF7C3AED),
                            label: l10n.statTodayTransactionsCount,
                            value: '$_todayTransactions',
                          ),
                          _StatCard(
                            icon: Icons.payments_rounded,
                            iconColor: AppColors.warning,
                            label: l10n.statTodaySalesLabel,
                            value:
                                '${_todaySales.toStringAsFixed(0)}${l10n.sarSuffix}',
                          ),
                          _StatCard(
                            icon: Icons.auto_awesome_rounded,
                            iconColor: AppColors.gold,
                            label: l10n.statTodayCashbackLabel,
                            value:
                                '${_todayCashback.toStringAsFixed(0)}${l10n.sarSuffix}',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        mainAxisSize: MainAxisSize.max,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 19),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.cairo(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.cairo(
                  fontSize: 10.5,
                  color: AppColors.textSecondary,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
