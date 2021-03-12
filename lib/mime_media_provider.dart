import 'package:enough_mail/enough_mail.dart';
import 'package:enough_media/enough_media.dart';

class MimeMediaProviderFactory {
  MimeMediaProviderFactory._internal();

  static MediaProvider fromMime(MimeMessage mimeMessage, MimePart mimePart) {
    final name = mimePart.decodeFileName() ?? '';
    var mediaType = mimePart.mediaType;
    if (mediaType.sub == MediaSubtype.applicationOctetStream &&
        name.isNotEmpty) {
      mediaType = MediaType.guessFromFilName(name);
    }
    if (mediaType.isText) {
      return TextMediaProvider(
          name, mediaType.text, mimePart.decodeContentText()!);
    } else {
      return MemoryMediaProvider(
          name, mediaType.text, mimePart.decodeContentBinary()!,
          description: mimeMessage.decodeSubject());
    }
  }
}
