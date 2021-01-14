import 'package:enough_mail/enough_mail.dart';
import 'package:enough_mail_flutter/media/image_media_viewer.dart';
import 'package:flutter/cupertino.dart';

/// Base abstraction for any media viewer
class MediaViewer extends StatelessWidget {
  final MimeMessage mimeMessage;
  final MimePart mimePart;
  final MediaType mediaType;

  MediaViewer(this.mimeMessage, this.mimePart, this.mediaType);

  @override
  Widget build(BuildContext context) {
    if (mediaType.isImage) {
      return ImageMediaViewer(
          mimePart: this.mimePart, mediaType: this.mediaType);
    } else if (mediaType.isText) {
      return Text(mimePart.decodeContentText());
    } else {
      return Text('Unsupported content with media type ${mediaType.text}');
    }
  }
}
