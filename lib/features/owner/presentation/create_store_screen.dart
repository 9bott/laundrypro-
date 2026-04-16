import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/env.dart';
import '../../../core/constants/supabase_constants.dart';
import '../../../shared/widgets/wallet_card_preview.dart';

const Color _kPointBlue = Color(0xFF185FA5);
const Color _kPageBg = Color(0xFFF8F9FA);
const Color _kTeal = Color(0xFF1D9E75);

const List<Color> _kPresetBrandColors = [
  Color(0xFF185FA5),
  Color(0xFF1D9E75),
  Color(0xFF7F77DD),
  Color(0xFFD85A30),
  Color(0xFFBA7517),
  Color(0xFF639922),
  Color(0xFFD4537E),
  Color(0xFF444441),
];

class _BusinessTypeOption {
  const _BusinessTypeOption(this.labelAr, this.dbValue);
  final String labelAr;
  final String dbValue;
}

const List<_BusinessTypeOption> _kBusinessTypes = [
  _BusinessTypeOption('مغسلة ملابس', 'laundry'),
  _BusinessTypeOption('مغسلة سيارات', 'carwash'),
  _BusinessTypeOption('كافيه', 'cafe'),
  _BusinessTypeOption('صالون حلاقة', 'salon'),
  _BusinessTypeOption('مطعم', 'other'),
  _BusinessTypeOption('أخرى', 'other'),
];

String _generateShortCode() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final r = Random.secure();
  return List.generate(6, (_) => chars[r.nextInt(chars.length)]).join();
}

String _makeSlugAttempt(String storeName, int attempt) {
  var ascii = storeName
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'-+'), '-');
  ascii = ascii.replaceAll(RegExp(r'^-+|-+$'), '');
  final base = ascii.isEmpty ? 'store' : ascii.substring(0, ascii.length.clamp(0, 24));
  final suffix = List.generate(
    4,
    (_) => 'abcdefghijklmnopqrstuvwxyz0123456789'[Random.secure().nextInt(36)],
  ).join();
  return attempt == 0 ? '$base-$suffix' : '$base-$suffix-$attempt';
}

String _colorToHex(Color c) {
  final r = (c.r * 255.0).round().clamp(0, 255);
  final g = (c.g * 255.0).round().clamp(0, 255);
  final b = (c.b * 255.0).round().clamp(0, 255);
  return '#${r.toRadixString(16).padLeft(2, '0')}'
      '${g.toRadixString(16).padLeft(2, '0')}'
      '${b.toRadixString(16).padLeft(2, '0')}';
}

/// Step 1–3 create-store wizard + Supabase persistence.
class CreateStoreScreen extends StatefulWidget {
  const CreateStoreScreen({super.key});

  @override
  State<CreateStoreScreen> createState() => _CreateStoreScreenState();
}

class _CreateStoreScreenState extends State<CreateStoreScreen>
    with TickerProviderStateMixin {
  int _step = 0;
  final _nameCtrl = TextEditingController();
  _BusinessTypeOption _type = _kBusinessTypes.first;
  double _cashbackRate = 0.20;

  Color _brandColor = _kPresetBrandColors.first;
  XFile? _logoFile;
  Uint8List? _logoBytes;

  bool _submitting = false;
  String? _createdShortCode;
  String? _createdName;

  late AnimationController _checkCtrl;
  late Animation<double> _checkScale;

  @override
  void initState() {
    super.initState();
    _checkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _checkScale = CurvedAnimation(parent: _checkCtrl, curve: Curves.elasticOut);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _checkCtrl.dispose();
    super.dispose();
  }

  Future<String?> _uploadLogoIfAny(String userId) async {
    if (_logoBytes == null || _logoBytes!.isEmpty) return null;
    try {
      final path = 'store_logos/$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';
      await Supabase.instance.client.storage.from(kBucketProfilePhotos).uploadBinary(
            path,
            _logoBytes!,
            fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'),
          );
      return Supabase.instance.client.storage.from(kBucketProfilePhotos).getPublicUrl(path);
    } catch (_) {
      return null;
    }
  }

  void _goNextFromStep0() {
    if (_nameCtrl.text.trim().length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل اسماً صالحاً للمتجر (حرفان على الأقل).')),
      );
      return;
    }
    setState(() => _step = 1);
  }

  Future<void> _goNextFromStep1() async {
    setState(() {
      _step = 2;
      _submitting = true;
    });
    await _finishCreateStore();
  }

  Future<void> _finishCreateStore() async {
    if (!Env.hasSupabase) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _step = 1;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر الاتصال: Supabase غير مهيأ.')),
        );
      }
      return;
    }
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _step = 1;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('انتهت الجلسة. سجّل الدخول من جديد.')),
        );
      }
      return;
    }

    try {
      final logoUrl = await _uploadLogoIfAny(user.id);
      Map<String, dynamic>? row;

      for (var attempt = 0; attempt < 12; attempt++) {
        final slug = _makeSlugAttempt(_nameCtrl.text.trim(), attempt);
        final shortCode = _generateShortCode();
        try {
          row = await Supabase.instance.client
              .from('stores')
              .insert({
                'slug': slug,
                'short_code': shortCode,
                'name': _nameCtrl.text.trim(),
                'business_type': _type.dbValue,
                'logo_url': logoUrl,
                'brand_color': _colorToHex(_brandColor),
                'cashback_rate': _cashbackRate,
                'owner_id': user.id,
                'status': 'active',
              })
              .select('short_code, name')
              .single();
          break;
        } on PostgrestException catch (e) {
          if (e.code == '23505') {
            continue;
          }
          rethrow;
        }
      }

      if (row == null) {
        throw Exception('تعذر إنشاء المتجر، حاول مرة أخرى.');
      }

      final created = Map<String, dynamic>.from(row);

      if (!mounted) return;
      setState(() {
        _createdShortCode = created['short_code'] as String?;
        _createdName = created['name'] as String? ?? _nameCtrl.text.trim();
        _submitting = false;
      });
      await _checkCtrl.forward(from: 0);
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _step = 1;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل إنشاء المتجر: $e')),
        );
      }
    }
  }

  String _qrPayload() {
    final code = _createdShortCode ?? '';
    return '{"t":"store","c":"$code"}';
  }

  Future<void> _shareStore() async {
    final code = _createdShortCode ?? '';
    await SharePlus.instance.share(
      ShareParams(
        text: 'انضم لمتجرنا على بوينت\nكود المتجر: $code',
        subject: 'بوينت — دعوة للمتجر',
      ),
    );
  }

  Future<void> _pickLogo() async {
    final x = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
    );
    if (x == null) return;
    final bytes = await x.readAsBytes();
    if (!mounted) return;
    setState(() {
      _logoFile = x;
      _logoBytes = bytes;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _kPageBg,
        appBar: AppBar(
          backgroundColor: _kPointBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          title: const Text('إنشاء متجرك'),
          leading: _step == 0
              ? IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: _submitting
                      ? null
                      : () {
                          if (context.canPop()) {
                            context.pop();
                          } else {
                            context.go('/auth/phone');
                          }
                        },
                )
              : IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  onPressed: _submitting
                      ? null
                      : () {
                          if (_step == 2 && _createdShortCode != null) {
                            return;
                          }
                          if (_step == 2 && _createdShortCode == null) {
                            setState(() => _step = 1);
                            return;
                          }
                          setState(() => _step = (_step - 1).clamp(0, 2));
                        },
                ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(28),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (i) {
                  final active = i <= _step;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: Icon(
                      Icons.circle,
                      size: i == _step ? 11 : 8,
                      color: active ? Colors.white : Colors.white38,
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
        body: switch (_step) {
          0 => _buildStepInfo(),
          1 => _buildStepBranding(),
          _ => _buildStepDone(),
        },
      ),
    );
  }

  Widget _buildStepInfo() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'اسم المتجر',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameCtrl,
                  onChanged: (_) => setState(() {}),
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    hintText: 'مثال: مغسلة النخيل',
                    filled: true,
                    fillColor: const Color(0xFFF8F9FA),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E4E8)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E4E8)),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'نوع النشاط',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<_BusinessTypeOption>(
                  value: _type, // ignore: deprecated_member_use
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFFF8F9FA),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E4E8)),
                    ),
                  ),
                  items: _kBusinessTypes
                      .map(
                        (e) => DropdownMenuItem(
                          value: e,
                          child: Text(e.labelAr),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _type = v);
                  },
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Text(
                      'نسبة الكاش باك',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    const Spacer(),
                    Text(
                      '${(_cashbackRate * 100).round()}٪',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: _kPointBlue,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: _cashbackRate,
                  min: 0.05,
                  max: 0.30,
                  divisions: 25,
                  activeColor: _kPointBlue,
                  label: '${(_cashbackRate * 100).round()}٪',
                  onChanged: (v) => setState(() => _cashbackRate = v),
                ),
                Text(
                  'من ٥٪ إلى ٣٠٪ — الافتراضي ٢٠٪',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 54,
            child: FilledButton(
              onPressed: _goNextFromStep0,
              style: FilledButton.styleFrom(
                backgroundColor: _kPointBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'التالي',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepBranding() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'شعار المتجر',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const SizedBox(height: 12),
                Center(
                  child: GestureDetector(
                    onTap: _pickLogo,
                    child: CircleAvatar(
                      radius: 48,
                      backgroundColor: const Color(0xFFF0F2F5),
                      backgroundImage:
                          _logoBytes != null ? MemoryImage(_logoBytes!) : null,
                      child: _logoBytes == null
                          ? const Icon(Icons.add_a_photo_outlined, size: 32)
                          : null,
                    ),
                  ),
                ),
                if (kIsWeb && _logoFile != null)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'سيتم رفع الشعار عند إنشاء المتجر.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                const SizedBox(height: 20),
                const Text(
                  'لون المتجر',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: _kPresetBrandColors.map((c) {
                    final sel = c == _brandColor;
                    return GestureDetector(
                      onTap: () => setState(() => _brandColor = c),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: sel ? Colors.black87 : Colors.white,
                            width: sel ? 3 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: sel
                            ? const Icon(Icons.check_rounded, color: Colors.white, size: 22)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'معاينة بطاقة المحفظة',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const SizedBox(height: 12),
          Center(child: _walletPreview()),
          const SizedBox(height: 24),
          SizedBox(
            height: 54,
            child: FilledButton(
              onPressed: _submitting ? null : _goNextFromStep1,
              style: FilledButton.styleFrom(
                backgroundColor: _kPointBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'التالي',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _walletPreview() {
    final name = _nameCtrl.text.trim().isEmpty ? 'اسم المتجر' : _nameCtrl.text.trim();
    return WalletCardPreview(
      storeName: name,
      brandColor: _brandColor,
      logoImage: _logoBytes == null ? null : MemoryImage(_logoBytes!),
    );
  }

  Widget _buildStepDone() {
    if (_submitting || _createdShortCode == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: _kPointBlue),
            const SizedBox(height: 20),
            Text(
              _submitting ? 'جاري إنشاء المتجر…' : '…',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          ScaleTransition(
            scale: _checkScale,
            child: const Icon(Icons.check_circle_rounded, size: 88, color: _kTeal),
          ),
          const SizedBox(height: 16),
          const Text(
            'تم إنشاء متجرك بنجاح!',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _createdName ?? '',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                QrImageView(
                  data: _qrPayload(),
                  version: QrVersions.auto,
                  size: 200,
                  eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                  ),
                ),
                const SizedBox(height: 16),
                SelectableText(
                  'كود المتجر: ${_createdShortCode ?? ''}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                  textAlign: TextAlign.center,
                ),
                TextButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: _createdShortCode ?? ''));
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم نسخ الكود')),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded, size: 20),
                  label: const Text('نسخ الكود'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _shareStore,
                  icon: const Icon(Icons.share_rounded),
                  label: const Text('شارك مع عملائك'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton(
              onPressed: () => context.go('/staff/dashboard'),
              style: FilledButton.styleFrom(
                backgroundColor: _kPointBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'ابدأ الآن',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
