import 'dart:io';

import 'package:enough_mail/enough_mail.dart';
import 'package:enough_mail_flutter/enough_mail_flutter.dart';
import 'package:enough_media/enough_media.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import 'mime_message_viewer.dart';

/// Downloads the mime message contents if required before showing them within a [MimeMesageViewer].
class MimeMessageDownloader extends StatefulWidget {
  final MimeMessage mimeMessage;
  final MailClient mailClient;
  final int maxDownloadSize;
  final int? maxImageWidth;
  final String downloadErrorMessage;
  final bool markAsSeen;
  final List<MediaToptype>? includedInlineTypes;
  final void Function(MimeMessage message)? onDownloaded;
  @deprecated
  final void Function(MailException e)? onDownloadError;
  final bool adjustHeight;
  final bool blockExternalImages;

  /// Defines if dark mode should be enabled.
  ///
  /// This might be required on devices with older browser implementations.
  final bool enableDarkMode;
  final String? emptyMessageText;
  final Future Function(Uri mailto, MimeMessage mimeMessage)? mailtoDelegate;
  final Future Function(InteractiveMediaWidget mediaWidget)? showMediaDelegate;
  final void Function(InAppWebViewController controller)? onWebViewCreated;
  final void Function(InAppWebViewController controller, double zoomFactor)?
      onZoomed;
  final void Function(Object? exception, StackTrace? stackTrace)? onError;

  /// With a builder you can take over the rendering for certain messages or mime types.
  final Widget? Function(BuildContext context, MimeMessage mimeMessage)?
      builder;

  /// Should the plain text be used instead of the HTML text?
  final bool preferPlainText;

  /// Creates a new message downloader widget
  ///
  /// [mimeMessage] The mime message which may not be downloaded yet.
  /// [mailClient] The initialized `MailClient` instance for downloading
  /// [maxDownloadSize] The maximum size in bytes of messages that are fully downloaded. The defaults to `128*1024` / `128kb`.
  /// When the message size is bigger, only inline parts are downloaded - at least over IMAP. Use `null` to download
  /// the complete message no matter what the message size is.
  /// Optionally specify the [maxImageWidth] to set the maximum width for embedded images.
  /// [downloadErrorMessage] The shown error message when the message cannot be downloaded
  /// Set [markAsSeen] to `true` to automatically mark a message with the `\Seen` flag when it is being downloaded.
  /// Optionally specify [includedInlineTypes] to exclude parts with an inline disposition and a different media type than specified.
  /// [onDownloaded] Optionally specify a callback to notify about a successful download.
  /// [adjustHeight] Should the webview measure itself and adapt its size? This defaults to `true`.
  /// [blockExternalImages] Should external images be prevented from loaded? This defaults to `false`.
  /// Set [enableDarkMode] to `true` to enforce dark mode on devices with older browsers.
  /// [emptyMessageText] The default text that should be shown for empty messages.
  /// [mailtoDelegate] Handler for mailto: links. Typically you will want to open a new compose view prepulated with a `MessageBuilder.prepareMailtoBasedMessage(uri,from)` instance.
  /// [showMediaDelegate] Handler for showing the given media widget, typically in its own screen
  /// Set the [onWebViewCreated] callback if you want a reference to the [InAppWebViewController].
  /// Set the [onZoomed] callback if you want to be notified when the webview is zoomed out after loading.
  /// Set the [onError] callback in case you want to be notfied about processing errors such as format exceptions.
  /// With a [builder] you can take over the rendering for certain messages or mime types.
  MimeMessageDownloader({
    Key? key,
    required this.mimeMessage,
    required this.mailClient,
    this.maxDownloadSize = 128 * 1024,
    this.maxImageWidth,
    this.downloadErrorMessage = 'Unable to download message.',
    this.markAsSeen = false,
    this.includedInlineTypes,
    this.onDownloaded,
    @Deprecated('use generic "onError" callback instead') this.onDownloadError,
    this.adjustHeight = true,
    this.blockExternalImages = false,
    this.preferPlainText = false,
    this.enableDarkMode = false,
    this.emptyMessageText,
    this.mailtoDelegate,
    this.showMediaDelegate,
    this.onWebViewCreated,
    this.onZoomed,
    this.onError,
    this.builder,
  }) : super(key: key);

  @override
  _MimeMessageDownloaderState createState() => _MimeMessageDownloaderState();
}

class _MimeMessageDownloaderState extends State<MimeMessageDownloader> {
  Future<MimeMessage>? downloader;
  late MimeMessage mimeMessage;

  @override
  void initState() {
    mimeMessage = widget.mimeMessage;
    if (!mimeMessage.isDownloaded) {
      downloader = _downloadMessageContents();
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
              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: Center(
                  child: (Platform.isIOS || Platform.isMacOS)
                      ? CupertinoActivityIndicator()
                      : CircularProgressIndicator(),
                ),
              );
            case ConnectionState.done:
              if (snapshot.hasError) {
                return Text(widget.downloadErrorMessage);
              }
              break;
          }
          return _buildMessageContent();
        },
      );
    }
    return _buildMessageContent();
  }

  Widget _buildMessageContent() {
    return MimeMessageViewer(
      mimeMessage: mimeMessage,
      adjustHeight: widget.adjustHeight,
      blockExternalImages: widget.blockExternalImages,
      preferPlainText: widget.preferPlainText,
      enableDarkMode: widget.enableDarkMode,
      emptyMessageText: widget.emptyMessageText,
      mailtoDelegate: widget.mailtoDelegate,
      showMediaDelegate: widget.showMediaDelegate,
      maxImageWidth: widget.maxImageWidth,
      onWebViewCreated: widget.onWebViewCreated,
      onZoomed: widget.onZoomed,
      onError: widget.onError,
      builder: widget.builder,
    );
  }

  Future<MimeMessage> _downloadMessageContents() async {
    try {
      // print('download message UID ${mimeMessage.uid} for state $this');
      mimeMessage = await widget.mailClient.fetchMessageContents(
        widget.mimeMessage,
        maxSize: widget.maxDownloadSize,
        markAsSeen: widget.markAsSeen,
        includedInlineTypes: widget.includedInlineTypes,
      );

      if (widget.onDownloaded != null) {
        widget.onDownloaded!(mimeMessage);
      }
    } on MailException catch (e, s) {
      if (widget.onError != null) {
        widget.onError!(e, s);
      } else if (widget.onDownloadError != null) {
        widget.onDownloadError!(e);
      } else {
        print(
            'Unable to download message ${widget.mimeMessage.decodeSubject()}: $e $s');
      }
    } catch (e, s) {
      print(
          'unexpected exception while downloading message with UID ${widget.mimeMessage.uid} / ID ${widget.mimeMessage.sequenceId}: $e $s');
      if (widget.onError != null) {
        widget.onError!(e, s);
      } else if (widget.onDownloadError != null) {
        widget.onDownloadError!(MailException(widget.mailClient, e.toString(),
            stackTrace: s, details: e));
      }
    }
    return mimeMessage;
  }
}
