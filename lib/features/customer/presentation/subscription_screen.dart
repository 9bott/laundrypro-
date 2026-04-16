import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/models/subscription_plan_model.dart';
import 'providers/customer_providers.dart';

class SubscriptionScreen extends ConsumerWidget {
  const SubscriptionScreen({super.key});

  static const _kPageBg = Color(0xFFF8F9FA);
  static const _kPointBlue = Color(0xFF185FA5);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plansAsync = ref.watch(subscriptionPlansProvider);
    final custAsync = ref.watch(customerStreamProvider);

    return Scaffold(
      backgroundColor: _kPageBg,
      appBar: AppBar(
        backgroundColor: _kPageBg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('باقات الاشتراك', style: TextStyle(fontWeight: FontWeight.w900)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(24),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: custAsync.maybeWhen(
              data: (c) {
                if (c == null) return const SizedBox.shrink();
                return FutureBuilder<String>(
                  future: _storeNameById(c.storeId),
                  builder: (context, snap) {
                    final name = snap.data ?? '...';
                    return Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        name,
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    );
                  },
                );
              },
              orElse: () => const SizedBox.shrink(),
            ),
          ),
        ),
      ),
      body: plansAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: _kPointBlue)),
        error: (e, _) => Center(child: Text('$e')),
        data: (plans) {
          final active = plans.where((p) => p.isActive).toList()
            ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
          if (active.isEmpty) {
            return const _EmptyState();
          }
          final popular = _mostPopular(active);
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            children: [
              for (final p in active)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _PlanCard(
                    plan: p,
                    popular: popular?.id == p.id,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  static _PopularPick? _mostPopular(List<SubscriptionPlanModel> plans) {
    if (plans.isEmpty) return null;
    SubscriptionPlanModel best = plans.first;
    for (final p in plans.skip(1)) {
      if ((p.credit - p.price) > (best.credit - best.price)) best = p;
    }
    return _PopularPick(best.id);
  }

  Future<String> _storeNameById(String storeId) async {
    final supabase = Supabase.instance.client;
    final rows =
        await supabase.from('stores').select('name').eq('id', storeId).limit(1) as List<dynamic>;
    if (rows.isEmpty) return 'المتجر';
    final m = Map<String, dynamic>.from(rows.first as Map);
    return (m['name'] as String?)?.trim() ?? 'المتجر';
  }
}

class _PopularPick {
  const _PopularPick(this.id);
  final String id;
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.credit_card_off_rounded, size: 46, color: Color(0xFF94A3B8)),
            SizedBox(height: 10),
            Text(
              'لا توجد باقات متاحة حالياً',
              style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF334155)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan, required this.popular});

  final SubscriptionPlanModel plan;
  final bool popular;

  static const _kPointBlue = Color(0xFF185FA5);

  @override
  Widget build(BuildContext context) {
    final savings = (plan.credit - plan.price) < 0 ? 0.0 : (plan.credit - plan.price);
    String money(double v) {
      final f = NumberFormat.currency(locale: 'ar', symbol: 'ر.س', decimalDigits: 0);
      return f.format(v);
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: popular ? _kPointBlue : const Color(0xFFE5E7EB),
          width: popular ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (popular)
            PositionedDirectional(
              top: -12,
              end: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: const Text(
                  'الأكثر طلباً',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: _kPointBlue,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                plan.nameAr.isNotEmpty ? plan.nameAr : plan.name,
                textAlign: TextAlign.end,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'ادفع ${money(plan.price)}',
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w800,
                      ),
                      textDirection: TextDirection.ltr,
                    ),
                  ),
                  const Icon(Icons.arrow_left_rounded, color: Color(0xFF94A3B8)),
                  Expanded(
                    child: Text(
                      'احصل ${money(plan.credit)}',
                      style: const TextStyle(
                        color: Color(0xFF085041),
                        fontWeight: FontWeight.w900,
                      ),
                      textAlign: TextAlign.end,
                      textDirection: TextDirection.ltr,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE1F5EE),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'وفّر ${money(savings)}',
                    style: const TextStyle(
                      color: Color(0xFF085041),
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                    textDirection: TextDirection.ltr,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 10),
              const Text(
                'أبلغ الموظف بالباقة التي تريدها',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
