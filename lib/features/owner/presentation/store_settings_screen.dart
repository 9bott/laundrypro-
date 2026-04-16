import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/widgets/wallet_card_preview.dart';

class StoreSettingsScreen extends StatefulWidget {
  const StoreSettingsScreen({super.key});

  @override
  State<StoreSettingsScreen> createState() => _StoreSettingsScreenState();
}

class _StoreSettingsScreenState extends State<StoreSettingsScreen> {
  static const _kPageBg = Color(0xFFF8F9FA);
  static const _kPointBlue = Color(0xFF185FA5);

  static const _presetColors = <Color>[
    Color(0xFF185FA5),
    Color(0xFF1D9E75),
    Color(0xFF7F77DD),
    Color(0xFFD85A30),
    Color(0xFFBA7517),
    Color(0xFF639922),
    Color(0xFFD4537E),
    Color(0xFF444441),
  ];

  bool _loading = true;
  bool _saving = false;
  String? _error;

  String? _storeId;
  String? _shortCode;

  final _nameCtl = TextEditingController();
  String _businessType = 'other';
  double _cashbackRate = 0.2;
  Color _brandColor = _kPointBlue;
  String? _logoUrl;
  Uint8List? _logoBytes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final supabase = Supabase.instance.client;
      final rows = await supabase
          .from('stores')
          .select('id, name, business_type, logo_url, brand_color, cashback_rate, short_code')
          .limit(1) as List<dynamic>;
      if (rows.isEmpty) {
        setState(() {
          _storeId = null;
          _shortCode = null;
          _nameCtl.text = '';
          _businessType = 'other';
          _logoUrl = null;
          _cashbackRate = 0.2;
          _brandColor = _kPointBlue;
        });
        return;
      }
      final m = Map<String, dynamic>.from(rows.first as Map);
      _storeId = '${m['id']}';
      _shortCode = (m['short_code'] as String?)?.trim();
      _nameCtl.text = (m['name'] as String?)?.trim() ?? '';
      _businessType = (m['business_type'] as String?)?.trim() ?? 'other';
      _logoUrl = (m['logo_url'] as String?)?.trim();
      _cashbackRate = (m['cashback_rate'] as num?)?.toDouble() ?? 0.2;
      _brandColor = _parseHexColor(m['brand_color'] as String?, fallback: _kPointBlue);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() => _logoBytes = bytes);
  }

  Future<String?> _uploadLogoIfNeeded() async {
    if (_logoBytes == null) return _logoUrl;
    final storeId = _storeId;
    if (storeId == null) return _logoUrl;
    final supabase = Supabase.instance.client;
    final path = 'stores/$storeId/logo_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await supabase.storage.from('public').uploadBinary(
          path,
          _logoBytes!,
          fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'),
        );
    return supabase.storage.from('public').getPublicUrl(path);
  }

  Future<void> _save() async {
    final storeId = _storeId;
    if (storeId == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final supabase = Supabase.instance.client;
      final logoUrl = await _uploadLogoIfNeeded();
      await supabase.from('stores').update({
        'name': _nameCtl.text.trim(),
        'business_type': _businessType,
        'cashback_rate': _cashbackRate,
        'brand_color': _colorToHex(_brandColor),
        'logo_url': logoUrl,
      }).eq('id', storeId);
      if (!mounted) return;
      setState(() {
        _logoUrl = logoUrl;
        _logoBytes = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ الإعدادات')),
      );
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _copyCode() {
    final code = _shortCode;
    if (code == null || code.isEmpty) return;
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم نسخ الكود')),
    );
  }

  void _shareCode() {
    final code = _shortCode;
    if (code == null || code.isEmpty) return;
    SharePlus.instance.share(
      ShareParams(
        text: 'انضم لمتجري على بوينت باستخدام الكود: $code',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = _nameCtl.text.trim().isEmpty ? 'اسم المتجر' : _nameCtl.text.trim();
    final ImageProvider<Object>? logoImage = _logoBytes != null
        ? MemoryImage(_logoBytes!) as ImageProvider<Object>
        : (_logoUrl != null && _logoUrl!.isNotEmpty
            ? NetworkImage(_logoUrl!) as ImageProvider<Object>
            : null);

    return Scaffold(
      backgroundColor: _kPageBg,
      appBar: AppBar(
        backgroundColor: _kPageBg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('إعدادات المتجر', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(
              _saving ? '...' : 'حفظ',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: _kPointBlue,
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _kPointBlue))
          : RefreshIndicator(
              color: _kPointBlue,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 26),
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFCEBEB),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFF6B7B7)),
                        ),
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            color: Color(0xFFA32D2D),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  Center(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: _pickLogo,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _brandColor,
                          border: Border.all(color: Colors.white, width: 4),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 18,
                              offset: const Offset(0, 10),
                            ),
                          ],
                          image: logoImage == null
                              ? null
                              : DecorationImage(image: logoImage, fit: BoxFit.cover),
                        ),
                        alignment: Alignment.center,
                        child: logoImage == null
                            ? Text(
                                _initials(name),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 22,
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const _FieldLabel('اسم المتجر'),
                  TextField(
                    controller: _nameCtl,
                    decoration: _inputDeco(hint: 'مثال: مقهى بوينت'),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 14),
                  const _FieldLabel('نوع النشاط'),
                  DropdownButtonFormField<String>(
                    initialValue: _businessType,
                    decoration: _inputDeco(hint: ''),
                    items: const [
                      DropdownMenuItem(value: 'cafe', child: Text('مقهى')),
                      DropdownMenuItem(value: 'restaurant', child: Text('مطعم')),
                      DropdownMenuItem(value: 'retail', child: Text('متجر')),
                      DropdownMenuItem(value: 'other', child: Text('أخرى')),
                    ],
                    onChanged: (v) => setState(() => _businessType = v ?? 'other'),
                  ),
                  const SizedBox(height: 14),
                  const _FieldLabel('نسبة الكاش باك'),
                  Row(
                    children: [
                      Expanded(
                        child: Slider(
                          value: _cashbackRate.clamp(0.05, 0.30),
                          min: 0.05,
                          max: 0.30,
                          divisions: 25,
                          activeColor: _kPointBlue,
                          onChanged: (v) => setState(() => _cashbackRate = v),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Text(
                          '${(_cashbackRate * 100).round()}%',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            color: _kPointBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const _FieldLabel('لون المتجر'),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _presetColors.map((c) {
                      final on = c.toARGB32() == _brandColor.toARGB32();
                      return InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () => setState(() => _brandColor = c),
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: on ? Colors.black.withValues(alpha: 0.22) : Colors.white,
                              width: on ? 3 : 2,
                            ),
                          ),
                          child: on
                              ? const Icon(Icons.check_rounded, color: Colors.white)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),
                  const _FieldLabel('معاينة بطاقة المحفظة'),
                  const SizedBox(height: 10),
                  WalletCardPreview(
                    storeName: name,
                    brandColor: _brandColor,
                    logoImage: logoImage,
                  ),
                  const SizedBox(height: 18),
                  const _FieldLabel('رمز QR للمتجر'),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: QrImageView(
                            data: _shortCode ?? '',
                            size: 220,
                            backgroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _shareCode,
                                icon: const Icon(Icons.share_rounded),
                                label: const Text('مشاركة'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _copyCode,
                                icon: const Icon(Icons.copy_rounded),
                                label: const Text('نسخ الكود'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Text(
                                'كود المتجر:',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Directionality(
                                  textDirection: TextDirection.ltr,
                                  child: Text(
                                    _shortCode ?? '—',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  const _FieldLabel('منطقة خطرة'),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFA32D2D),
                      side: const BorderSide(color: Color(0xFFF6B7B7)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      minimumSize: const Size.fromHeight(54),
                    ),
                    child: const Text(
                      'حذف المتجر',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  static InputDecoration _inputDeco({required String hint}) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _kPointBlue, width: 1.4),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w900,
          color: Color(0xFF0F172A),
        ),
      ),
    );
  }
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

String _colorToHex(Color c) {
  final argb = c.toARGB32();
  final a = (argb >> 24) & 0xFF;
  final r = (argb >> 16) & 0xFF;
  final g = (argb >> 8) & 0xFF;
  final b = (argb) & 0xFF;
  return '#'
      '${a.toRadixString(16).padLeft(2, '0')}'
      '${r.toRadixString(16).padLeft(2, '0')}'
      '${g.toRadixString(16).padLeft(2, '0')}'
      '${b.toRadixString(16).padLeft(2, '0')}'
      .toUpperCase();
}

Color _parseHexColor(String? hex, {required Color fallback}) {
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
