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
  final void Function(MimeMessage message) onDownloaded;
  final bool adjustHeight;
  final bool blockExternalImages;
  final String emptyMessageText;
  final Future Function(Uri mailto, MimeMessage mimeMessage) mailtoDelegate;

  /// Creates a new message downloader widget
  MimeMessageDownloader({
    Key key,

    /// The mime message which may not be downloaded yet.
    @required this.mimeMessage,

    /// The initialized mail client
    @required this.mailClient,

    /// The maximum size in bytes of messages that are fully downloaded. The defaults to `128*1024` / `128kb`.
    /// When the message size is bigger, only inline parts are downloaded - at least over IMAP. Use `null` to download
    /// the complete message no matter what the message size is.
    this.maxDownloadSize = 128 * 1024,

    /// The shown error message when the message cannot be downloaded
    this.downloadErrorMessage = 'Unable to download message.',

    /// A callback to notify about a successful download
    this.onDownloaded,

    /// Should the webview measure itself and adapt its size? This defaults to `true`.
    this.adjustHeight = true,

    /// Should external images be prevented from loaded? This defaults to `false`.
    this.blockExternalImages = false,

    /// The default text that should be shown for empty messages.
    this.emptyMessageText,

    /// Handler for mailto: links. Typically you will want to open a new compose view prepulated with a `MessageBuilder.prepareMailtoBasedMessage(uri,from)` instance.
    this.mailtoDelegate,
  }) : super(key: key);

  @override
  _MimeMessageDownloaderState createState() => _MimeMessageDownloaderState();
}

class _MimeMessageDownloaderState extends State<MimeMessageDownloader> {
  MimeMessage mimeMessage;

  @override
  void initState() {
    mimeMessage = widget.mimeMessage;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (!mimeMessage.isDownloaded) {
      return FutureBuilder(
        future: downloadMessageContents(),
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
    var mimeResponse = await widget.mailClient
        .fetchMessageContents(mimeMessage, maxSize: widget.maxDownloadSize);
    if (mimeResponse.isOkStatus) {
      mimeMessage = mimeResponse.result;
      if (widget.onDownloaded != null) {
        widget.onDownloaded(mimeMessage);
      }
    }
    return mimeMessage;
  }
}
