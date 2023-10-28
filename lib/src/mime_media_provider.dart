import 'package:enough_mail/enough_mail.dart';
import 'package:enough_media/enough_media.dart';
import 'package:flutter/foundation.dart';

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
    return mediaType.isText
        ? TextMediaProvider(
            name, mediaType.text, mimePart.decodeContentText() ?? '')
        : MemoryMediaProvider(
            name,
            mediaType.text,
            mimePart.decodeContentBinary() ?? Uint8List(0),
            description: mimeMessage.decodeSubject(),
          );
  }

  /// Creates a new [TextMediaProvider] or [MemoryMediaProvider] from
  /// the given [title] and [text].
  static MediaProvider fromError({
    required String title,
    required String text,
  }) =>
      TextMediaProvider(
        title,
        MediaType.textPlain.text,
        text,
      );
}
