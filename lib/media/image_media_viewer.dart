import 'dart:typed_data';

import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';

/// Displays images
class ImageMediaViewer extends StatefulWidget {
  final MimePart mimePart;
  final MediaType mediaType;
  ImageMediaViewer({Key key, @required this.mimePart, @required this.mediaType})
      : super(key: key);

  @override
  _ImageMediaViewerState createState() => _ImageMediaViewerState();
}

class _ImageMediaViewerState extends State<ImageMediaViewer> {
  Uint8List imageData;

  @override
  void initState() {
    imageData = widget.mimePart.decodeContentBinary();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return PhotoView(
      imageProvider: MemoryImage(imageData),
      basePosition: Alignment.center,
    );
  }
}
