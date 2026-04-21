import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

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
    final l10n = AppLocalizations.of(context)!;
    final go = await showDialog<bool>(
          context: context,
          builder: (ctx) {
            final dl = AppLocalizations.of(ctx)!;
            return AlertDialog(
              title: Text(dl.inviteStaff),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      prefixText: '+966 ',
                      hintText: '5XXXXXXXX',
                    ),
                    textDirection: TextDirection.ltr,
                  ),
                  TextField(
                    controller: name,
                    decoration: InputDecoration(labelText: dl.name),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(dl.cancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(dl.save),
                ),
              ],
            );
          },
        ) ??
        false;
    final nine = phone.text.replaceAll(RegExp(r'\D'), '');
    final nameTrim = name.text.trim();
    phone.dispose();
    name.dispose();
    if (go != true) return;
    if (nine.length != 9) return;
    try {
      await ref.read(ownerRepositoryProvider).inviteStaff(
            phoneE164: '+966$nine',
            name: nameTrim,
          );
      if (mounted) {
        await _load();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.staffCreatedOtpSent),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
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
                          try {
                            await ref.read(ownerRepositoryProvider).setStaffActive(
                                  staffId: s.id,
                                  isActive: false,
                                );
                            if (ctx.mounted) Navigator.pop(ctx);
                            await _load();
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('$e')),
                              );
                            }
                          }
                        }
                      : () async {
                          try {
                            await ref.read(ownerRepositoryProvider).setStaffActive(
                                  staffId: s.id,
                                  isActive: true,
                                );
                            if (ctx.mounted) Navigator.pop(ctx);
                            await _load();
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
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
      appBar: AppBar(
        title: Text(l10n.staffListTitle),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _invite,
        label: Text(l10n.inviteStaff),
        icon: const Icon(Icons.person_add),
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
              color: AppColors.primary,
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
                        final status = s.isActive
                            ? l10n.statusActive
                            : l10n.statusInactive;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: AppCard(
                            borderColor: s.isActive
                                ? AppColors.border
                                : AppColors.textHint.withValues(alpha: 0.4),
                            child: InkWell(
                              onTap: () => _detail(s),
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 26,
                                      backgroundColor: AppColors.primaryTint,
                                      child: Text(
                                        initials,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontWeight: FontWeight.w900,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            s.name.isEmpty ? '—' : s.name,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 15,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${s.phone.isEmpty ? '—' : s.phone} · ${s.role}',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 12,
                                              color: AppColors.textSecondary,
                                            ),
                                            textDirection: TextDirection.ltr,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${l10n.branchLabel}: ${s.branch.isEmpty ? '—' : s.branch} · $status · '
                                            '${l10n.transactions} (${s.txToday})',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 11,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
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
