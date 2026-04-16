import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/app_card.dart';
import '../data/owner_repository.dart';
import 'providers/owner_providers.dart';

class OwnerStaffScreen extends ConsumerStatefulWidget {
  const OwnerStaffScreen({super.key});

  @override
  ConsumerState<OwnerStaffScreen> createState() => _OwnerStaffScreenState();
}

class _OwnerStaffScreenState extends ConsumerState<OwnerStaffScreen> {
  bool _loading = true;
  List<StaffDirectoryRow> _staff = [];
  static const _kPageBg = Color(0xFFF8F9FA);
  static const _kPointBlue = Color(0xFF185FA5);

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _staff = await ref.read(ownerRepositoryProvider).fetchStaffDirectory();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final s = parts[0];
      if (s.isEmpty) return '?';
      return s[0].toUpperCase();
    }
    final a = parts[0].isEmpty ? '' : parts[0][0];
    final b = parts[1].isEmpty ? '' : parts[1][0];
    final raw = '$a$b';
    return raw.isEmpty ? '?' : raw.toUpperCase();
  }

  Future<void> _invite() async {
    final phone = TextEditingController();
    final name = TextEditingController();
    var role = 'staff';
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final pad = MediaQuery.viewInsetsOf(ctx).bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: pad),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
                child: Column(
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
                      'إضافة موظف',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                      textAlign: TextAlign.start,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: const Text(
                            '+966',
                            style: TextStyle(fontWeight: FontWeight.w900),
                            textDirection: TextDirection.ltr,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: phone,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              hintText: '5XXXXXXXX',
                              filled: true,
                              fillColor: Color(0xFFF8FAFC),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.all(Radius.circular(12)),
                                borderSide: BorderSide(color: Color(0xFFE5E7EB)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.all(Radius.circular(12)),
                                borderSide: BorderSide(color: Color(0xFFE5E7EB)),
                              ),
                            ),
                            textDirection: TextDirection.ltr,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: role,
                      decoration: const InputDecoration(
                        filled: true,
                        fillColor: Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'staff', child: Text('موظف')),
                        DropdownMenuItem(value: 'manager', child: Text('مدير')),
                      ],
                      onChanged: (v) {
                        role = v ?? 'staff';
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: name,
                      decoration: const InputDecoration(
                        hintText: 'اسم الموظف (اختياري)',
                        filled: true,
                        fillColor: Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final nine = phone.text.replaceAll(RegExp(r'\\D'), '');
                          if (nine.length != 9) {
                            messenger.showSnackBar(
                              const SnackBar(content: Text('رقم الجوال غير صحيح')),
                            );
                            return;
                          }
                          final l10n = AppLocalizations.of(context)!;
                          final nav = Navigator.of(ctx);
                          try {
                            await ref.read(ownerRepositoryProvider).inviteStaff(
                                  phoneE164: '+966$nine',
                                  name: name.text.trim().isEmpty
                                      ? (role == 'manager' ? 'مدير' : 'موظف')
                                      : name.text.trim(),
                                );
                            if (!mounted) return;
                            nav.pop();
                            await _load();
                            if (!mounted) return;
                            messenger.showSnackBar(
                              SnackBar(content: Text(l10n.staffCreatedOtpSent)),
                            );
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
                        child: const Text('إضافة', style: TextStyle(fontWeight: FontWeight.w900)),
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
    phone.dispose();
    name.dispose();
  }

  Future<void> _detail(StaffDirectoryRow s) async {
    List<TransactionListRow> txs = [];
    try {
      txs = await ref.read(ownerRepositoryProvider).fetchStaffTransactions(s.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 0.92,
        builder: (_, sc) => Column(
          children: [
            ListTile(
              title: Text(s.name),
              subtitle: Text(
                '${s.phone} · ${s.role} · ${l10n.branchLabel}: ${s.branch.isEmpty ? '—' : s.branch} · ${l10n.transactions}: ${s.txToday}',
                textDirection: TextDirection.ltr,
              ),
            ),
            Row(
              children: [
                TextButton(
                  onPressed: s.isActive
                      ? () async {
                          final outerMessenger = ScaffoldMessenger.of(context);
                          try {
                            await ref.read(ownerRepositoryProvider).setStaffActive(
                                  staffId: s.id,
                                  isActive: false,
                                );
                            if (ctx.mounted) Navigator.pop(ctx);
                            await _load();
                          } catch (e) {
                            if (context.mounted) {
                              outerMessenger.showSnackBar(
                                SnackBar(content: Text('$e')),
                              );
                            }
                          }
                        }
                      : () async {
                          final outerMessenger = ScaffoldMessenger.of(context);
                          try {
                            await ref.read(ownerRepositoryProvider).setStaffActive(
                                  staffId: s.id,
                                  isActive: true,
                                );
                            if (ctx.mounted) Navigator.pop(ctx);
                            await _load();
                          } catch (e) {
                            if (context.mounted) {
                              outerMessenger.showSnackBar(
                                SnackBar(content: Text('$e')),
                              );
                            }
                          }
                        },
                  child: Text(
                    s.isActive ? l10n.actionDeactivate : l10n.actionActivate,
                    style: TextStyle(color: s.isActive ? AppColors.error : AppColors.success),
                  ),
                ),
              ],
            ),
            Expanded(
              child: ListView(
                controller: sc,
                children: txs
                    .map(
                      (r) => ListTile(
                        title: Text(r.customerName),
                        subtitle: Text(r.transaction.type),
                        trailing: Text(r.transaction.amount.toStringAsFixed(2)),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: _kPageBg,
      appBar: AppBar(
        backgroundColor: _kPageBg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Row(
          children: [
            const Expanded(
              child: Text('الموظفون', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Text(
                '${_staff.length}',
                style: const TextStyle(fontWeight: FontWeight.w900, color: _kPointBlue),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _invite,
        label: const Text('إضافة', style: TextStyle(fontWeight: FontWeight.w900)),
        icon: const Icon(Icons.add_rounded),
        backgroundColor: _kPointBlue,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? ListView(
              padding: const EdgeInsets.all(16),
              children: List.generate(
                6,
                (_) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AppCard(
                    padding: const EdgeInsets.all(16),
                    child: Container(
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ),
            )
          : RefreshIndicator(
              color: _kPointBlue,
              onRefresh: _load,
              child: _staff.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(top: 120),
                      children: [
                        Center(
                          child: Text(
                            l10n.nothingToShow,
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                      itemCount: _staff.length,
                      itemBuilder: (_, i) {
                        final s = _staff[i];
                        final initials = _initials(s.name);
                        final role = (s.role).toLowerCase();
                        final roleUi = switch (role) {
                          'owner' => ('مالك', const Color(0xFFEEEDFE), const Color(0xFF3C3489)),
                          'manager' => ('مدير', const Color(0xFFEFF6FF), const Color(0xFF185FA5)),
                          _ => ('موظف', const Color(0xFFE1F5EE), const Color(0xFF085041)),
                        };
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Dismissible(
                            key: ValueKey(s.id),
                            direction: s.isActive
                                ? DismissDirection.endToStart
                                : DismissDirection.none,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 18),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFCEBEB),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.block_rounded, color: Color(0xFFA32D2D)),
                            ),
                            onDismissed: (_) async {
                              try {
                                await ref.read(ownerRepositoryProvider).setStaffActive(
                                      staffId: s.id,
                                      isActive: false,
                                    );
                                await _load();
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('$e')),
                                  );
                                }
                                await _load();
                              }
                            },
                            child: Material(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => _detail(s),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Color(0xFFF1F5F9),
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          initials,
                                          style: const TextStyle(fontWeight: FontWeight.w900),
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
                                                    s.name.isEmpty ? '—' : s.name,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.w900,
                                                      fontSize: 15,
                                                      color: Color(0xFF111827),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 6,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: roleUi.$2,
                                                    borderRadius: BorderRadius.circular(999),
                                                  ),
                                                  child: Text(
                                                    roleUi.$1,
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.w900,
                                                      fontSize: 11,
                                                      color: roleUi.$3,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Directionality(
                                              textDirection: TextDirection.ltr,
                                              child: Text(
                                                s.phone.isEmpty ? '—' : s.phone,
                                                style: const TextStyle(
                                                  color: Color(0xFF64748B),
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Switch(
                                        value: s.isActive,
                                        onChanged: (v) async {
                                          try {
                                            await ref.read(ownerRepositoryProvider).setStaffActive(
                                                  staffId: s.id,
                                                  isActive: v,
                                                );
                                            await _load();
                                          } catch (e) {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text('$e')),
                                              );
                                            }
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
