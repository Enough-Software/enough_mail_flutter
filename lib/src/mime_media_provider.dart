import 'package:enough_mail/enough_mail.dart';
import 'package:enough_media/enough_media.dart';

/// Provides a simple way to generate a media provider from a mime message
class MimeMediaProviderFactory {
  MimeMediaProviderFactory._internal();

  /// Creates a new [TextMediaProvider] or [MemoryMediaProvider] from
  /// the given [mimePart] in the [mimeMessage].
  static MediaProvider fromMime(MimeMessage mimeMessage, MimePart mimePart) {
    final name = mimePart.decodeFileName() ?? '';
    var mediaType = mimePart.mediaType;
    if (mediaType.sub == MediaSubtype.applicationOctetStream &&
        name.isNotEmpty) {
      mediaType = MediaType.guessFromFileName(name);
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
