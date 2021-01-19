import 'package:enough_mail/enough_mail.dart';
import 'package:enough_media/enough_media.dart';

class MimeMediaProviderFactory {
  MimeMediaProviderFactory._internal();

  static MediaProvider fromMime(MimePart mimePart) {
    final name = mimePart.decodeFileName();
    final mediaType = mimePart.mediaType.text;
    if (mimePart.mediaType?.isText ?? false) {
      return TextMediaProvider(name, mediaType, mimePart.decodeContentText());
    } else {
      return MemoryMediaProvider(
          name, mediaType, mimePart.decodeContentBinary());
    }
  }
}
