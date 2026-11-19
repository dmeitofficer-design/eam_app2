// lib/features/purchases/presentation/screens/add_bill_flow.dart
//
// Add bill: choose Manual, Scan (on-device OCR) or AI-fill (Gemini),
// get the photo/file, then open the form prefilled with what was found.

import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/error_formatter.dart';
import '../../../../core/utils/feedback.dart';
import '../../data/models/bill_draft.dart';
import '../../data/repositories/purchases_repository.dart';
import 'add_bill_page.dart';

enum _Mode { manual, ocr, ai }

/// ML Kit text recognition only exists on Android and iOS.
bool get ocrSupported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);
bool get _isPhone => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

const _maxFileBytes = 8 * 1024 * 1024;

/// Runs the whole Add bill flow. Returns the new bill's id, or null.
Future<String?> startAddBill(BuildContext context) async {
  final mode = await _showSheet<_Mode>(context, (c) => const _ModeSheet());
  if (mode == null || !context.mounted) return null;

  Future<BillPrefill>? prefill;
  var source = 'Manual';

  if (mode == _Mode.ocr) {
    final file = await _pickBillFile(context, allowPdf: false);
    if (file == null || !context.mounted) return null;
    source = 'Scan (OCR)';
    prefill = _runOcr(file.path!);
  } else if (mode == _Mode.ai) {
    final accepted = await _showSheet<bool>(context, (c) => const _AiTermsSheet());
    if (accepted != true || !context.mounted) return null;
    final file = await _pickBillFile(context, allowPdf: true);
    if (file == null || !context.mounted) return null;
    source = 'AI-fill (Gemini)';
    final repo = context.read<PurchasesRepository>();
    prefill = repo.scanWithAi(file.bytes, file.mimeType).then((d) => BillPrefill(draft: d));
  }

  return Navigator.of(context).push<String>(
    MaterialPageRoute(builder: (_) => AddBillPage(prefill: prefill, sourceLabel: source)),
  );
}

Future<BillPrefill> _runOcr(String path) async {
  final recognizer = TextRecognizer();
  try {
    final result = await recognizer.processImage(InputImage.fromFilePath(path));
    return BillPrefill(draft: BillDraft.fromOcrText(result.text), rawText: result.text);
  } finally {
    unawaited(recognizer.close());
  }
}

typedef _PickedFile = ({Uint8List bytes, String mimeType, String? path});

Future<_PickedFile?> _pickBillFile(BuildContext context, {required bool allowPdf}) async {
  try {
    if (_isPhone) {
      final choice = await _showSheet<String>(context, (c) => _SourceSheet(allowPdf: allowPdf));
      if (choice == null) return null;
      if (choice != 'pdf') {
        // Downscaled: sharp enough for serials, small enough to upload quickly.
        final x = await ImagePicker().pickImage(
          source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
          maxWidth: 2400,
          maxHeight: 2400,
          imageQuality: 85,
        );
        if (x == null) return null;
        return (bytes: await x.readAsBytes(), mimeType: _mime(x.name), path: x.path);
      }
    }
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', if (allowPdf) 'pdf'],
    );
    final f = result?.files.single;
    if (f == null) return null;
    if (f.size > _maxFileBytes) {
      throw const AppException('That file is over 8 MB. Use a smaller photo or a one-page scan.');
    }
    return (bytes: await f.readAsBytes(), mimeType: _mime(f.name), path: f.path);
  } catch (e) {
    if (context.mounted) AppFeedback.error(context, ErrorFormatter.format(e));
    return null;
  }
}

String _mime(String name) {
  final ext = name.split('.').last.toLowerCase();
  return switch (ext) {
    'png' => 'image/png',
    'webp' => 'image/webp',
    'heic' => 'image/heic',
    'pdf' => 'application/pdf',
    _ => 'image/jpeg',
  };
}

Future<T?> _showSheet<T>(BuildContext context, WidgetBuilder builder) => showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface1,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: builder,
    );

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.title, required this.children, this.subtitle});
  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(color: AppColors.surface3, borderRadius: AppRadius.chip),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            if (subtitle != null) ...[
              const SizedBox(height: AppSpacing.xxs),
              Text(subtitle!, style: theme.textTheme.bodySmall),
            ],
            const SizedBox(height: AppSpacing.md),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _ModeSheet extends StatelessWidget {
  const _ModeSheet();

  @override
  Widget build(BuildContext context) {
    Widget option(_Mode mode, IconData icon, String title, String body, {bool enabled = true}) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Material(
            color: AppColors.surface0,
            borderRadius: AppRadius.card,
            child: ListTile(
              enabled: enabled,
              shape: RoundedRectangleBorder(borderRadius: AppRadius.card),
              leading: Icon(icon, color: enabled ? AppColors.accent : AppColors.textTertiary),
              title: Text(title),
              subtitle: Text(body),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                HapticFeedback.selectionClick();
                Navigator.pop(context, mode);
              },
            ),
          ),
        );

    return _SheetFrame(
      title: 'Add bill',
      subtitle: 'Every option ends in the same form; nothing is saved until you check it and tap Save.',
      children: [
        option(_Mode.manual, Icons.edit_note_rounded, 'Manual', 'Type the bill in yourself.'),
        option(
          _Mode.ocr,
          Icons.document_scanner_rounded,
          'Scan (OCR)',
          ocrSupported
              ? 'Reads the photo on this phone, offline. Fills bill no, date and total; shows the text to copy from.'
              : 'Available in the Android app (reads the photo on the phone, offline).',
          enabled: ocrSupported,
        ),
        option(
          _Mode.ai,
          Icons.auto_awesome_rounded,
          'AI-fill (Gemini)',
          'Google Gemini reads the photo or PDF and fills the whole form. Needs internet.',
        ),
      ],
    );
  }
}

class _SourceSheet extends StatelessWidget {
  const _SourceSheet({required this.allowPdf});
  final bool allowPdf;

  @override
  Widget build(BuildContext context) => _SheetFrame(
        title: 'Bill photo',
        subtitle: 'Lay the bill flat in good light; keep the serial numbers sharp.',
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_rounded),
            title: const Text('Take a photo'),
            onTap: () => Navigator.pop(context, 'camera'),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_rounded),
            title: const Text('Choose from gallery'),
            onTap: () => Navigator.pop(context, 'gallery'),
          ),
          if (allowPdf)
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_rounded),
              title: const Text('Choose a PDF or image file'),
              onTap: () => Navigator.pop(context, 'pdf'),
            ),
        ],
      );
}

/// Shown before every AI-fill: the photo leaves the company and goes to Google.
class _AiTermsSheet extends StatefulWidget {
  const _AiTermsSheet();

  @override
  State<_AiTermsSheet> createState() => _AiTermsSheetState();
}

class _AiTermsSheetState extends State<_AiTermsSheet> {
  bool _agreed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget point(IconData icon, String text) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: AppColors.warning),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
            ],
          ),
        );

    return _SheetFrame(
      title: 'Before you use AI-fill',
      subtitle: 'AI-fill uses the free tier of the Google Gemini API.',
      children: [
        point(Icons.cloud_upload_rounded,
            'The bill photo or PDF is sent to Google to be read. It leaves DME\'s systems.',),
        point(Icons.policy_rounded,
            'On the free tier, Google may use what you send to improve its products (Gemini API terms).',),
        point(Icons.lock_rounded,
            'Don\'t scan bills with information you\'re not allowed to share outside the company.',),
        point(Icons.fact_check_rounded,
            'The AI can misread numbers and serials. Check every field before you save.',),
        const SizedBox(height: AppSpacing.xs),
        CheckboxListTile(
          value: _agreed,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text('I understand and agree to send this bill to Google'),
          onChanged: (v) {
            HapticFeedback.selectionClick();
            setState(() => _agreed = v ?? false);
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context, false),
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48), shape: const StadiumBorder()),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: ElevatedButton(
                onPressed: _agreed ? () => Navigator.pop(context, true) : null,
                style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48), shape: const StadiumBorder()),
                child: const Text('Continue'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
