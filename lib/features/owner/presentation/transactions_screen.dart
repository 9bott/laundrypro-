import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../l10n/app_localizations.dart';
import '../data/owner_repository.dart';
import 'providers/owner_providers.dart';

class OwnerTransactionsScreen extends ConsumerStatefulWidget {
  const OwnerTransactionsScreen({super.key});

  @override
  ConsumerState<OwnerTransactionsScreen> createState() =>
      _OwnerTransactionsScreenState();
}

class _OwnerTransactionsScreenState extends ConsumerState<OwnerTransactionsScreen> {
  final _search = TextEditingController();
  final List<TransactionListRow> _all = [];
  String? _type;
  String? _staffId;
  int _page = 0;
  bool _loading = false;
  bool _done = false;
  static const _pageSize = 25;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadMore);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadMore({bool reset = false}) async {
    if (_loading) return;
    if (_done && !reset) return;
    setState(() => _loading = true);
    try {
      final repo = ref.read(ownerRepositoryProvider);
      final offset = reset ? 0 : _page * _pageSize;
      final rows = await repo.fetchTransactionsPage(
        offset: offset,
        limit: _pageSize,
        search: _search.text.trim().isEmpty ? null : _search.text.trim(),
        typeFilter: _type,
        staffIdFilter: _staffId,
      );
      if (!mounted) return;
      setState(() {
        if (reset) {
          _all.clear();
          _page = 0;
          _done = false;
        }
        _all.addAll(rows);
        _page++;
        if (rows.length < _pageSize) _done = true;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _exportCsv() async {
    try {
      final buf = StringBuffer(
        'time,customer,phone,staff,type,amount,cashback_earned,id\n',
      );
      for (final r in _all) {
        final t = r.transaction;
        buf.writeln(
          '${t.createdAt.toIso8601String()},'
          '"${r.customerName}",'
          '${r.customerPhone},'
          '"${r.staffName ?? ""}",'
          '${t.type},'
          '${t.amount},'
          '${t.cashbackEarned},'
          '${t.id}',
        );
      }
      await SharePlus.instance.share(
        ShareParams(
          text: buf.toString(),
          subject: 'transactions.csv',
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final staffAsync = ref.watch(ownerStaffDirectoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.transactions),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share),
            onPressed: _all.isEmpty ? null : _exportCsv,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: l10n.searchHint,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () {
                    setState(() {
                      _page = 0;
                      _done = false;
                      _all.clear();
                    });
                    _loadMore(reset: true);
                  },
                ),
              ),
              onSubmitted: (_) {
                setState(() {
                  _page = 0;
                  _done = false;
                  _all.clear();
                });
                _loadMore(reset: true);
              },
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                ChoiceChip(
                  label: Text(l10n.filterAll),
                  selected: _type == null,
                  onSelected: (_) {
                    setState(() {
                      _type = null;
                      _page = 0;
                      _done = false;
                      _all.clear();
                    });
                    _loadMore(reset: true);
                  },
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  label: Text(l10n.filterPurchase),
                  selected: _type == 'purchase',
                  onSelected: (_) {
                    setState(() {
                      _type = 'purchase';
                      _page = 0;
                      _done = false;
                      _all.clear();
                    });
                    _loadMore(reset: true);
                  },
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  label: Text(l10n.filterRedemption),
                  selected: _type == 'redemption',
                  onSelected: (_) {
                    setState(() {
                      _type = 'redemption';
                      _page = 0;
                      _done = false;
                      _all.clear();
                    });
                    _loadMore(reset: true);
                  },
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  label: Text(l10n.filterSubscription),
                  selected: _type == 'subscription',
                  onSelected: (_) {
                    setState(() {
                      _type = 'subscription';
                      _page = 0;
                      _done = false;
                      _all.clear();
                    });
                    _loadMore(reset: true);
                  },
                ),
                const SizedBox(width: 12),
                staffAsync.when(
                  data: (staff) {
                    return DropdownButton<String?>(
                      value: _staffId,
                      hint: Text(l10n.staffListTitle),
                      items: [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text(l10n.filterAll),
                        ),
                        ...staff.map(
                          (s) => DropdownMenuItem(
                            value: s.id,
                            child: Text(s.name),
                          ),
                        ),
                      ],
                      onChanged: (v) {
                        setState(() {
                          _staffId = v;
                          _page = 0;
                          _done = false;
                          _all.clear();
                        });
                        _loadMore(reset: true);
                      },
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          Expanded(
            child: _all.isEmpty && !_loading
                ? Center(
                    child: Text(
                      l10n.nothingToShow,
                    ),
                  )
                : ListView.builder(
                    itemCount: _all.length + 1,
                    itemBuilder: (ctx, i) {
                      if (i == _all.length) {
                        if (_done) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.all(16),
                          child: Center(
                            child: _loading
                                ? const CircularProgressIndicator()
                                : TextButton(
                                    onPressed: () => _loadMore(),
                                    child: Text(
                                      l10n.loadMore,
                                    ),
                                  ),
                          ),
                        );
                      }
                      final r = _all[i];
                      final t = r.transaction;
                      return Card(
                        child: ExpansionTile(
                          title: Text(r.customerName),
                          subtitle: Text(
                            '${t.createdAt.toLocal()} · ${t.type} · ${t.amount.toStringAsFixed(2)}',
                          ),
                          children: [
                            ListTile(
                              title: Text(
                                l10n.phoneLabelShort,
                              ),
                              subtitle: Text(r.customerPhone),
                            ),
                            ListTile(
                              title: Text(l10n.staffListTitle),
                              subtitle: Text(r.staffName ?? '—'),
                            ),
                            ListTile(
                              title: Text(
                                l10n.cashbackBalance,
                              ),
                              subtitle: Text('cb: ${t.cashbackEarned.toStringAsFixed(2)}'),
                            ),
                            ListTile(
                              title: Text(l10n.idLabel),
                              subtitle: SelectableText(t.id),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
