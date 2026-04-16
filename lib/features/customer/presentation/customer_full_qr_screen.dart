import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/active_store_provider.dart';
import 'providers/customer_providers.dart';

class CustomerFullQrScreen extends ConsumerWidget {
  const CustomerFullQrScreen({super.key});

  static const _kBlue = Color(0xFF185FA5);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final custAsync = ref.watch(customerStreamProvider);
    final activeStoreId = ref.watch(activeStoreProvider).asData?.value;

    return custAsync.when(
      loading: () => const Scaffold(
        backgroundColor: _kBlue,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: _kBlue,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text('$e', style: const TextStyle(color: Colors.white)),
          ),
        ),
      ),
      data: (c) {
        if (c == null) {
          return const Scaffold(
            backgroundColor: _kBlue,
            body: Center(
              child: Text('تعذر تحميل بيانات العميل', style: TextStyle(color: Colors.white)),
            ),
          );
        }

        final storeId = activeStoreId ?? c.storeId;
        return FutureBuilder<_StoreMini>(
          future: _loadStore(storeId),
          builder: (context, snap) {
            final store = snap.data ??
                const _StoreMini(
                  name: 'المتجر',
                  logoUrl: null,
                );
            return Scaffold(
              backgroundColor: _kBlue,
              body: SafeArea(
                child: Stack(
                  children: [
                    PositionedDirectional(
                      top: 10,
                      start: 10,
                      child: IconButton(
                        onPressed: () => context.pop(),
                        icon: const Icon(Icons.close_rounded, color: Colors.white),
                        tooltip: 'إغلاق',
                      ),
                    ),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: const Icon(Icons.store_rounded, color: _kBlue),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              store.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 18),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: QrImageView(
                                data: c.id,
                                size: 240,
                                backgroundColor: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              c.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'أريه للموظف ليمسحه',
                              style: TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<_StoreMini> _loadStore(String storeId) async {
    final supabase = Supabase.instance.client;
    final rows = await supabase
        .from('stores')
        .select('name, logo_url')
        .eq('id', storeId)
        .limit(1) as List<dynamic>;
    if (rows.isEmpty) return const _StoreMini(name: 'المتجر', logoUrl: null);
    final m = Map<String, dynamic>.from(rows.first as Map);
    return _StoreMini(
      name: (m['name'] as String?)?.trim() ?? 'المتجر',
      logoUrl: (m['logo_url'] as String?)?.trim(),
    );
  }
}

class _StoreMini {
  const _StoreMini({required this.name, required this.logoUrl});
  final String name;
  final String? logoUrl;
}
