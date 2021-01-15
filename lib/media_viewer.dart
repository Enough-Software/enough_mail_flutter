import 'package:enough_mail/enough_mail.dart';
import 'package:enough_mail_flutter/media/audio_media_viewer.dart';
import 'package:enough_mail_flutter/media/image_media_viewer.dart';
import 'package:enough_mail_flutter/media/pdf_media_viewer.dart';
import 'package:flutter/material.dart';

/// Base abstraction for any media viewer
class MediaViewer extends StatelessWidget {
  final MimeMessage mimeMessage;
  final MimePart mimePart;
  final MediaType mediaType;

  MediaViewer(this.mimeMessage, this.mimePart, this.mediaType);

  @override
  Widget build(BuildContext context) {
    if (mediaType.isImage) {
      return ImageMediaViewer(mimePart: mimePart, mediaType: mediaType);
    } else if (mediaType.sub == MediaSubtype.applicationPdf) {
      return PdfMediaViewer(mimePart: mimePart, mediaType: mediaType);
    } else if (mediaType.isAudio) {
      return AudioMediaViewer(mimePart: mimePart, mediaType: mediaType);
    } else if (mediaType.isText) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: SelectableText(mimePart.decodeContentText()),
      );
    } else {
      return Text('Unsupported content with media type ${mediaType.text}');
    }
  }
}
