import 'dart:typed_data';

import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

/// Displays PDFs
class PdfMediaViewer extends StatefulWidget {
  final MimePart mimePart;
  final MediaType mediaType;
  PdfMediaViewer({Key key, this.mimePart, this.mediaType}) : super(key: key);

  @override
  _PdfMediaViewerState createState() => _PdfMediaViewerState();
}

class _PdfMediaViewerState extends State<PdfMediaViewer> {
  Uint8List pdfData;
  PdfViewerController pdfViewerController;
  OverlayEntry overlayEntry;

  @override
  void initState() {
    pdfData = widget.mimePart.decodeContentBinary();
    pdfViewerController = PdfViewerController();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return SfPdfViewer.memory(
      pdfData,
      controller: pdfViewerController,
      onTextSelectionChanged: onTextSelectionChanged,
    );
  }

  void onTextSelectionChanged(PdfTextSelectionChangedDetails details) {
    if (details.selectedText == null && overlayEntry != null) {
      overlayEntry.remove();
      overlayEntry = null;
    } else if (details.selectedText != null && overlayEntry == null) {
      final OverlayState overlayState = Overlay.of(context);
      overlayEntry = OverlayEntry(
        builder: (context) => Positioned(
          top: details.globalSelectedRegion.center.dy - 55,
          left: details.globalSelectedRegion.bottomLeft.dx,
          child: RaisedButton(
            child: Text('Copy', style: TextStyle(fontSize: 17)),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: details.selectedText));
              pdfViewerController.clearSelection();
            },
            color: Colors.white,
            elevation: 10,
          ),
        ),
      );
      overlayState.insert(overlayEntry);
    }
  }
}
