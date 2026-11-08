import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../services/pdf_service.dart';
import '../widgets/common.dart';

class PdfPreviewScreen extends StatelessWidget {
  const PdfPreviewScreen({super.key, required this.document});
  final GeneratedPdf document;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Visualizar PDF')),
    body: PdfPreview(
      build: (_) async => document.bytes,
      pdfFileName: document.filename,
      initialPageFormat: PdfPageFormat.a4,
      canChangePageFormat: false,
      canChangeOrientation: false,
      canDebug: false,
      allowPrinting: false,
      allowSharing: false,
      onError: (_, error) => LoadError(
        message:
            'Não foi possível visualizar o PDF. Volte e tente gerar novamente.',
        onRetry: () => Navigator.pop(context),
      ),
    ),
    bottomNavigationBar: _PdfActions(document: document),
  );
}

class _PdfActions extends StatefulWidget {
  const _PdfActions({required this.document});
  final GeneratedPdf document;
  @override
  State<_PdfActions> createState() => _PdfActionsState();
}

class _PdfActionsState extends State<_PdfActions> {
  bool _busy = false;
  Future<void> _act(bool share) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (share) {
        final box = context.findRenderObject() as RenderBox?;
        await Printing.sharePdf(
          bytes: widget.document.bytes,
          filename: widget.document.filename,
          bounds: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        );
      } else {
        await Printing.layoutPdf(
          onLayout: (_) async => widget.document.bytes,
          name: widget.document.filename,
          format: PdfPageFormat.a4,
          dynamicLayout: false,
        );
      }
    } catch (error) {
      if (mounted) {
        showMessage(
          context,
          errorMessage(
            error,
            share ? 'Não foi possível compartilhar o PDF. Tente novamente.' : 'Não foi possível imprimir o PDF. Verifique o serviço de impressão.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _act(false),
            icon: const Icon(Icons.print_outlined),
            label: const Text('Imprimir'),
          ),
          FilledButton.icon(
            onPressed: _busy ? null : () => _act(true),
            icon: const Icon(Icons.share_outlined),
            label: Text(_busy ? 'Aguarde…' : 'Compartilhar'),
          ),
        ],
      ),
    ),
  );
}
