import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/supabase_constants.dart';

class SubscriptionPlansScreen extends StatefulWidget {
  const SubscriptionPlansScreen({super.key});

  @override
  State<SubscriptionPlansScreen> createState() => _SubscriptionPlansScreenState();
}

class _SubscriptionPlansScreenState extends State<SubscriptionPlansScreen> {
  static const _kPageBg = Color(0xFFF8F9FA);
  static const _kPointBlue = Color(0xFF185FA5);

  bool _loading = true;
  String? _error;
  List<_Plan> _plans = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final supabase = Supabase.instance.client;
      final rows = await supabase
          .from(kTableSubscriptionPlans)
          .select()
          .order(kSubscriptionPlansSortOrder, ascending: true) as List<dynamic>;
      final list = rows
          .map((e) => _Plan.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      setState(() {
        _plans = list;
      });
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  _Plan? get _mostPopular {
    if (_plans.isEmpty) return null;
    _Plan best = _plans.first;
    for (final p in _plans.skip(1)) {
      if (p.savings > best.savings) best = p;
    }
    return best;
  }

  Future<void> _openEditor({_Plan? existing}) async {
    final nameCtl = TextEditingController(text: existing?.nameAr ?? existing?.name ?? '');
    final priceCtl = TextEditingController(
      text: existing == null ? '' : _trimZeros(existing.price.toStringAsFixed(2)),
    );
    final creditCtl = TextEditingController(
      text: existing == null ? '' : _trimZeros(existing.credit.toStringAsFixed(2)),
    );
    double parseNum(String s) => double.tryParse(s.trim()) ?? 0;

    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final bottom = MediaQuery.viewInsetsOf(ctx).bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
                child: StatefulBuilder(
                  builder: (context, setSheet) {
                    final price = parseNum(priceCtl.text);
                    final credit = parseNum(creditCtl.text);
                    final bonus = (credit - price).clamp(0, double.infinity);
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: 46,
                            height: 5,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          existing == null ? 'إضافة باقة' : 'تعديل الباقة',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: nameCtl,
                          decoration: const InputDecoration(
                            hintText: 'اسم الباقة',
                            filled: true,
                            fillColor: Color(0xFFF8FAFC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: priceCtl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            hintText: 'ما يدفعه العميل (ر.س)',
                            filled: true,
                            fillColor: Color(0xFFF8FAFC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(12)),
                            ),
                          ),
                          onChanged: (_) => setSheet(() {}),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: creditCtl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            hintText: 'ما يحصل عليه (ر.س)',
                            filled: true,
                            fillColor: Color(0xFFF8FAFC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(12)),
                            ),
                          ),
                          onChanged: (_) => setSheet(() {}),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE1F5EE),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFA7F3D0)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.savings_rounded, color: Color(0xFF085041)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'الربح/البونص: ${_trimZeros(bonus.toStringAsFixed(2))} ر.س',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF085041),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          height: 52,
                          child: FilledButton(
                            onPressed: () async {
                              HapticFeedback.lightImpact();
                              final nav = Navigator.of(ctx);
                              final messenger = ScaffoldMessenger.of(context);
                              final name = nameCtl.text.trim();
                              final price = parseNum(priceCtl.text);
                              final credit = parseNum(creditCtl.text);
                              if (name.isEmpty || price <= 0 || credit <= 0 || credit < price) {
                                messenger.showSnackBar(
                                  const SnackBar(content: Text('تأكد من إدخال قيم صحيحة')),
                                );
                                return;
                              }
                              final supabase = Supabase.instance.client;
                              try {
                                final payload = {
                                  kSubscriptionPlansName: name,
                                  kSubscriptionPlansNameAr: name,
                                  kSubscriptionPlansPrice: price,
                                  kSubscriptionPlansCredit: credit,
                                  kSubscriptionPlansBonusPercentage:
                                      ((credit - price) / price) * 100,
                                  kSubscriptionPlansIsActive: true,
                                };
                                if (existing == null) {
                                  await supabase.from(kTableSubscriptionPlans).insert(payload);
                                } else {
                                  await supabase
                                      .from(kTableSubscriptionPlans)
                                      .update(payload)
                                      .eq(kSubscriptionPlansId, existing.id);
                                }
                                if (!mounted) return;
                                nav.pop();
                                await _load();
                              } catch (e) {
                                if (context.mounted) {
                                  messenger.showSnackBar(
                                    SnackBar(content: Text('$e')),
                                  );
                                }
                              }
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: _kPointBlue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text('حفظ', style: TextStyle(fontWeight: FontWeight.w900)),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
    nameCtl.dispose();
    priceCtl.dispose();
    creditCtl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final popular = _mostPopular;
    return Scaffold(
      backgroundColor: _kPageBg,
      appBar: AppBar(
        backgroundColor: _kPageBg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('باقات الاشتراك', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(),
        backgroundColor: _kPointBlue,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add_rounded),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _kPointBlue))
          : _error != null
              ? Center(child: Text(_error!, textAlign: TextAlign.center))
              : RefreshIndicator(
                  color: _kPointBlue,
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 90),
                    children: [
                      for (final p in _plans)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _PlanCard(
                            plan: p,
                            popular: popular?.id == p.id,
                            onEdit: () => _openEditor(existing: p),
                          ),
                        ),
                      if (_plans.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 120),
                          child: Center(
                            child: Text(
                              'لا توجد باقات بعد.',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}

class _Plan {
  const _Plan({
    required this.id,
    required this.name,
    required this.nameAr,
    required this.price,
    required this.credit,
    required this.isActive,
    required this.sortOrder,
  });

  final String id;
  final String name;
  final String nameAr;
  final double price;
  final double credit;
  final bool isActive;
  final int sortOrder;

  double get savings => (credit - price).clamp(0, double.infinity);

  factory _Plan.fromJson(Map<String, dynamic> m) {
    return _Plan(
      id: '${m[kSubscriptionPlansId]}',
      name: (m[kSubscriptionPlansName] as String?) ?? '',
      nameAr: (m[kSubscriptionPlansNameAr] as String?) ?? '',
      price: (m[kSubscriptionPlansPrice] as num?)?.toDouble() ?? 0,
      credit: (m[kSubscriptionPlansCredit] as num?)?.toDouble() ?? 0,
      isActive: m[kSubscriptionPlansIsActive] as bool? ?? true,
      sortOrder: m[kSubscriptionPlansSortOrder] as int? ?? 0,
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.popular,
    required this.onEdit,
  });

  final _Plan plan;
  final bool popular;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final savings = plan.savings;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: popular ? const Color(0xFF185FA5) : const Color(0xFFE5E7EB),
          width: popular ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_rounded, color: Color(0xFF0F172A)),
                tooltip: 'تعديل',
              ),
              const Spacer(),
              if (popular)
                Container(
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
                      color: Color(0xFF185FA5),
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          Text(
            (plan.nameAr.isNotEmpty ? plan.nameAr : plan.name),
            textAlign: TextAlign.start,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 18,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 10),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              'ادفع ${_trimZeros(plan.price.toStringAsFixed(2))} ر.س  ←  احصل ${_trimZeros(plan.credit.toStringAsFixed(2))} ر.س',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: Color(0xFF334155),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFE1F5EE),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'وفّر ${_trimZeros(savings.toStringAsFixed(2))} ر.س',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF085041),
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _trimZeros(String s) {
  if (!s.contains('.')) return s;
  var x = s;
  while (x.endsWith('0')) {
    x = x.substring(0, x.length - 1);
  }
  if (x.endsWith('.')) x = x.substring(0, x.length - 1);
  return x;
}
