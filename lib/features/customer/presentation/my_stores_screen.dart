import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/active_store_provider.dart';
import 'providers/customer_providers.dart';

class MyStoresScreen extends ConsumerWidget {
  const MyStoresScreen({super.key});

  static const _kPageBg = Color(0xFFF8F9FA);
  static const _kPointBlue = Color(0xFF185FA5);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(
      authUserProvider.select((a) => a.asData?.value?.id),
    );
    final storesAsync = ref.watch(_myStoresProvider(userId));
    final activeAsync = ref.watch(activeStoreProvider);
    final activeId = activeAsync.asData?.value;

    return Scaffold(
      backgroundColor: _kPageBg,
      appBar: AppBar(
        backgroundColor: _kPageBg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('متاجري', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: storesAsync.when(
        loading: () => ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
          children: List.generate(
            6,
            (_) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                height: 92,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
              ),
            ),
          ),
        ),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text('$e', textAlign: TextAlign.center),
          ),
        ),
        data: (stores) {
          return Column(
            children: [
              Expanded(
                child: stores.isEmpty
                    ? const Center(
                        child: Text(
                          'لا توجد متاجر مرتبطة بحسابك بعد.',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                        itemCount: stores.length,
                        itemBuilder: (_, i) {
                          final s = stores[i];
                          final isActive = (activeId ?? stores.first.id) == s.id;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _StoreCard(
                              store: s,
                              isActive: isActive,
                              onTap: () async {
                                HapticFeedback.lightImpact();
                                await ref
                                    .read(activeStoreProvider.notifier)
                                    .setActiveStoreId(s.id);
                              },
                            ),
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                child: OutlinedButton(
                  onPressed: userId == null
                      ? null
                      : () => _openJoinSheet(context, ref, userId),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _kPointBlue,
                    side: const BorderSide(color: _kPointBlue),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    minimumSize: const Size.fromHeight(54),
                  ),
                  child: const Text(
                    'انضم لمتجر جديد',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openJoinSheet(
    BuildContext context,
    WidgetRef ref,
    String userId,
  ) async {
    final ctl = TextEditingController();
    var busy = false;

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
                    Future<void> join() async {
                      if (busy) return;
                      final code = ctl.text.trim().toUpperCase();
                      if (code.length != 6) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('أدخل كود مكوّن من 6 أحرف')),
                        );
                        return;
                      }
                      setSheet(() => busy = true);
                      try {
                        final supabase = Supabase.instance.client;
                        final res = await supabase.rpc(
                          'join_store_as_customer',
                          params: {'p_short_code': code},
                        );
                        final storeId = '$res';
                        await ref
                            .read(activeStoreProvider.notifier)
                            .setActiveStoreId(storeId);
                        ref.invalidate(_myStoresProvider(userId));
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('$e')),
                          );
                        }
                      } finally {
                        if (context.mounted) setSheet(() => busy = false);
                      }
                    }

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
                        const Text(
                          'أدخل كود المتجر',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: ctl,
                          textAlign: TextAlign.center,
                          textCapitalization: TextCapitalization.characters,
                          maxLength: 6,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            letterSpacing: 6,
                          ),
                          decoration: const InputDecoration(
                            counterText: '',
                            filled: true,
                            fillColor: Color(0xFFF8FAFC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(14)),
                            ),
                          ),
                          onSubmitted: (_) => join(),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 52,
                          child: FilledButton(
                            onPressed: busy ? null : join,
                            style: FilledButton.styleFrom(
                              backgroundColor: _kPointBlue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: busy
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.4,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'انضم',
                                    style: TextStyle(fontWeight: FontWeight.w900),
                                  ),
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
    ctl.dispose();
  }
}

final _myStoresProvider =
    FutureProvider.family<List<_StoreCardView>, String?>((ref, userId) async {
  if (userId == null) return const [];
  final supabase = Supabase.instance.client;

  final memberships = await supabase
      .from('customer_store_memberships')
      .select('store_id')
      .eq('user_id', userId) as List<dynamic>;

  final storeIds = memberships
      .map((e) => Map<String, dynamic>.from(e as Map)['store_id'] as String?)
      .whereType<String>()
      .toSet()
      .toList();
  if (storeIds.isEmpty) return const [];

  final stores = await supabase
      .from('stores')
      .select('id, name, business_type, brand_color, logo_url')
      .inFilter('id', storeIds) as List<dynamic>;

  final balancesRows = await supabase
      .from('customers')
      .select('store_id, cashback_balance, subscription_balance')
      .eq('auth_user_id', userId) as List<dynamic>;

  final balances = <String, ({double cb, double sub})>{};
  for (final raw in balancesRows) {
    final m = Map<String, dynamic>.from(raw as Map);
    final sid = m['store_id'] as String?;
    if (sid == null) continue;
    balances[sid] = (
      cb: (m['cashback_balance'] as num?)?.toDouble() ?? 0,
      sub: (m['subscription_balance'] as num?)?.toDouble() ?? 0,
    );
  }

  final list = stores.map((raw) {
    final m = Map<String, dynamic>.from(raw as Map);
    final id = '${m['id']}';
    final b = balances[id] ?? (cb: 0.0, sub: 0.0);
    return _StoreCardView(
      id: id,
      name: (m['name'] as String?)?.trim() ?? '—',
      businessType: (m['business_type'] as String?)?.trim() ?? '',
      brandColor: _parseHexColor(m['brand_color'] as String?),
      logoUrl: (m['logo_url'] as String?)?.trim(),
      cashback: b.cb,
      subscription: b.sub,
    );
  }).toList();

  list.sort((a, b) => a.name.compareTo(b.name));
  return list;
});

class _StoreCard extends StatelessWidget {
  const _StoreCard({
    required this.store,
    required this.isActive,
    required this.onTap,
  });

  final _StoreCardView store;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 64,
                decoration: BoxDecoration(
                  color: store.brandColor,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: store.brandColor,
                ),
                alignment: Alignment.center,
                child: Text(
                  _initials(store.name),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            store.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (isActive)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE1F5EE),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'نشط',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF085041),
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _businessTypeAr(store.businessType),
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 6,
                      children: [
                        Text(
                          'اشتراك: ${store.subscription.toStringAsFixed(0)} ر.س',
                          style: const TextStyle(
                            color: Color(0xFF085041),
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          'كاش باك: ${store.cashback.toStringAsFixed(0)} ر.س',
                          style: const TextStyle(
                            color: Color(0xFFBA7517),
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoreCardView {
  const _StoreCardView({
    required this.id,
    required this.name,
    required this.businessType,
    required this.brandColor,
    required this.logoUrl,
    required this.cashback,
    required this.subscription,
  });

  final String id;
  final String name;
  final String businessType;
  final Color brandColor;
  final String? logoUrl;
  final double cashback;
  final double subscription;
}

String _initials(String name) {
  final p = name.trim().split(RegExp(r'\\s+'));
  if (p.isEmpty) return '؟';
  if (p.length == 1) return p[0].isEmpty ? '؟' : p[0][0].toUpperCase();
  final a = p.first.isEmpty ? '' : p.first[0];
  final b = p.last.isEmpty ? '' : p.last[0];
  final r = '$a$b';
  return r.isEmpty ? '؟' : r.toUpperCase();
}

Color _parseHexColor(String? hex) {
  const fallback = Color(0xFF185FA5);
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

String _businessTypeAr(String bt) {
  switch (bt.toLowerCase()) {
    case 'cafe':
      return 'مقهى';
    case 'restaurant':
      return 'مطعم';
    case 'retail':
      return 'متجر';
    default:
      return 'نشاط تجاري';
  }
}
