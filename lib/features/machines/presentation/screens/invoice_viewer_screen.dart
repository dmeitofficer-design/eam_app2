// lib/features/machines/presentation/screens/invoice_viewer_screen.dart
//
// Shows a Supabase Storage PDF inline using SyncfusionFlutterPdfViewer.
// Receives a signed URL from MachinesBloc before opening.

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../../../../core/theme/app_theme.dart';

class InvoiceViewerScreen extends StatefulWidget {
  const InvoiceViewerScreen({
    super.key,
    required this.signedUrl,
    this.title = 'Invoice',
  });

  final String signedUrl;
  final String title;

  static Route<void> route({
    required String signedUrl,
    String title = 'Invoice',
  }) {
    return MaterialPageRoute(
      builder: (_) =>
          InvoiceViewerScreen(signedUrl: signedUrl, title: title),
    );
  }

  @override
  State<InvoiceViewerScreen> createState() => _InvoiceViewerScreenState();
}

class _InvoiceViewerScreenState extends State<InvoiceViewerScreen> {
  late final PdfViewerController _controller = PdfViewerController();
  bool _isReady = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.surface0,
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          // Zoom in
          IconButton(
            icon: const Icon(Icons.zoom_in_rounded),
            onPressed: () => _controller.zoomLevel =
                (_controller.zoomLevel + 0.25).clamp(1.0, 4.0),
          ),
          // Zoom out
          IconButton(
            icon: const Icon(Icons.zoom_out_rounded),
            onPressed: () => _controller.zoomLevel =
                (_controller.zoomLevel - 0.25).clamp(1.0, 4.0),
          ),
        ],
      ),
      body: Stack(
        children: [
          SfPdfViewer.network(
            widget.signedUrl,
            controller: _controller,
            onDocumentLoaded: (_) => setState(() => _isReady = true),
            onDocumentLoadFailed: (details) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to load PDF: ${details.description}'),
                ),
              );
            },
          ),
          if (!_isReady)
            Container(
              color: AppColors.surface0,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(
                      color: AppColors.accent,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Loading invoice…',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
