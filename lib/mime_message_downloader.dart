import 'package:enough_mail/enough_mail.dart';
import 'package:enough_mail_flutter/enough_mail_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

/// Downloads the mime message contents if required before showing them within a [MimeMesageViewer].
class MimeMessageDownloader extends StatefulWidget {
  final MimeMessage mimeMessage;
  final MailClient mailClient;
  final int maxDownloadSize;
  final String downloadErrorMessage;
  final bool markAsSeen;
  final void Function(MimeMessage message) onDownloaded;
  final void Function(MailException e) onDownloadError;
  final bool adjustHeight;
  final bool blockExternalImages;
  final String emptyMessageText;
  final Future Function(Uri mailto, MimeMessage mimeMessage) mailtoDelegate;

  /// Creates a new message downloader widget
  /// [mimeMessage] The mime message which may not be downloaded yet.
  /// [mailClient] The initialized `MailClient` instance for downloading
  /// [maxDownloadSize] The maximum size in bytes of messages that are fully downloaded. The defaults to `128*1024` / `128kb`.
  /// When the message size is bigger, only inline parts are downloaded - at least over IMAP. Use `null` to download
  /// the complete message no matter what the message size is.
  /// [downloadErrorMessage] The shown error message when the message cannot be downloaded
  /// Set [markAsSeen] to `true` to automatically mark a message with the `\Seen` flag when it is being downloaded.
  /// [onDownloaded] Optionally specify a callback to notify about a successful download.
  /// [adjustHeight] Should the webview measure itself and adapt its size? This defaults to `true`.
  /// [blockExternalImages] Should external images be prevented from loaded? This defaults to `false`.
  /// [emptyMessageText] The default text that should be shown for empty messages.
  /// [mailtoDelegate] Handler for mailto: links. Typically you will want to open a new compose view prepulated with a `MessageBuilder.prepareMailtoBasedMessage(uri,from)` instance.
  MimeMessageDownloader({
    Key key,
    @required this.mimeMessage,
    @required this.mailClient,
    this.maxDownloadSize = 128 * 1024,
    this.downloadErrorMessage = 'Unable to download message.',
    this.markAsSeen,
    this.onDownloaded,
    this.onDownloadError,
    this.adjustHeight = true,
    this.blockExternalImages = false,
    this.emptyMessageText,
    this.mailtoDelegate,
  }) : super(key: key);

  @override
  _MimeMessageDownloaderState createState() => _MimeMessageDownloaderState();
}

class _MimeMessageDownloaderState extends State<MimeMessageDownloader> {
  MimeMessage mimeMessage;
  Future<MimeMessage> downloader;

  @override
  void initState() {
    mimeMessage = widget.mimeMessage;
    if (!mimeMessage.isDownloaded) {
      downloader = downloadMessageContents();
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (!mimeMessage.isDownloaded) {
      return FutureBuilder<MimeMessage>(
        future: downloader,
        builder: (context, snapshot) {
          switch (snapshot.connectionState) {
            case ConnectionState.none:
            case ConnectionState.waiting:
            case ConnectionState.active:
              return Container(child: CircularProgressIndicator());
              break;
            case ConnectionState.done:
              if (snapshot.hasError) {
                return Text(widget.downloadErrorMessage);
              }
              break;
          }
          return buildMessageContent();
        },
      );
    }
    return buildMessageContent();
  }

  Widget buildMessageContent() {
    return MimeMessageViewer(
      mimeMessage: mimeMessage,
      adjustHeight: widget.adjustHeight,
      blockExternalImages: widget.blockExternalImages,
      emptyMessageText: widget.emptyMessageText,
      mailtoDelegate: widget.mailtoDelegate,
    );
  }

  Future<MimeMessage> downloadMessageContents() async {
    try {
      mimeMessage = await widget.mailClient.fetchMessageContents(mimeMessage,
          maxSize: widget.maxDownloadSize, markAsSeen: widget.markAsSeen);
      if (widget.onDownloaded != null) {
        widget.onDownloaded(mimeMessage);
      }
    } on MailException catch (e) {
      if (widget.onDownloadError != null) {
        widget.onDownloadError(e);
      } else {
        print('Unable to download message ${mimeMessage.decodeSubject()}: $e');
      }
    }
    return mimeMessage;
  }
}
