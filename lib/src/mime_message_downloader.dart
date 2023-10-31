import 'package:enough_mail/enough_mail.dart';
import 'package:enough_media/enough_media.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:logger/logger.dart';

import 'logger.dart';
import 'mime_message_viewer.dart';
import 'progress_indicator.dart';

/// Downloads the mime message contents if required
/// before showing them within a [MimeMessageViewer].
class MimeMessageDownloader extends StatefulWidget {
  /// Creates a new message downloader widget
  const MimeMessageDownloader({
    super.key,
    required this.mimeMessage,
    required this.fetchMessageContents,
    this.maxDownloadSize = 128 * 1024,
    this.maxImageWidth,
    this.downloadErrorMessage = 'Unable to download message.',
    this.markAsSeen = false,
    this.downloadTimeout,
    this.includedInlineTypes,
    this.onDownloaded,
    this.adjustHeight = true,
    this.blockExternalImages = false,
    this.preferPlainText = false,
    this.enableDarkMode = false,
    this.emptyMessageText,
    this.mailtoDelegate,
    this.showMediaDelegate,
    this.urlLauncherDelegate,
    this.onWebViewCreated,
    this.onZoomed,
    this.onError,
    this.builder,
    this.logger,
  });

  /// The partial MIME message
  final MimeMessage mimeMessage;

  /// The required message loader, usually [MailClient.fetchMessageContents].
  ///
  /// Alternative load the message from disk or somewhere else.
  final Future<MimeMessage> Function(
    MimeMessage message, {
    int? maxSize,
    bool markAsSeen,
    List<MediaToptype>? includedInlineTypes,
    Duration? responseTimeout,
  }) fetchMessageContents;

  /// The maximum size in bytes of messages that are fully downloaded.
  /// The defaults to `128*1024` / `128kb`.
  ///
  /// When the message size is bigger, only inline parts are downloaded -
  /// at least over IMAP. Use `null` to download the complete message no matter
  /// what the message size is.
  final int maxDownloadSize;

  /// The maximum image width for inline images
  final int? maxImageWidth;

  /// The error message to be shown when message downloading failed
  final String downloadErrorMessage;

  /// Set to `true` when the message should be marked as with the downloading
  final bool markAsSeen;

  /// Optional list of media types to be shown inline
  final List<MediaToptype>? includedInlineTypes;

  /// The optional timeout for the download operation
  final Duration? downloadTimeout;

  /// Callback to get informed when the message has been downloaded
  final void Function(MimeMessage message)? onDownloaded;

  /// Should the height of the displayed mime message be limited?
  ///
  /// This must be the case when the message contents are shown within
  /// a scrollable view.
  final bool adjustHeight;

  /// Defines if external images should be removed
  final bool blockExternalImages;

  /// Defines if dark mode should be enabled.
  ///
  /// This might be required on devices with older browser implementations.
  final bool enableDarkMode;

  /// The text shown when an image has no inline content
  final String? emptyMessageText;

  /// Handler for mailto: links.
  ///
  /// Typically you will want to open a new compose view pre-populated with
  /// a `MessageBuilder.prepareMailtoBasedMessage(uri,from)` instance.
  final Future Function(Uri mailto, MimeMessage mimeMessage)? mailtoDelegate;

  /// Handler for showing the given media widget, typically in its own screen
  final Future Function(InteractiveMediaWidget mediaWidget)? showMediaDelegate;

  /// Handler for any non-media URLs that the user taps on the website.
  ///
  /// Returns `true` when the given `url` was handled.
  final Future<bool> Function(String url)? urlLauncherDelegate;

  /// Retrieve a reference to the [InAppWebViewController].
  final void Function(InAppWebViewController controller)? onWebViewCreated;

  /// This callback will be called when the webview zooms out after loading.
  ///
  /// Usually this is a sign that the user might want to zoom in again.
  final void Function(InAppWebViewController controller, double zoomFactor)?
      onZoomed;

  /// Is notified about any errors that might occur
  final void Function(Object? exception, StackTrace? stackTrace)? onError;

  /// With a builder you can take over the rendering
  /// for certain messages or mime types.
  final Widget? Function(BuildContext context, MimeMessage mimeMessage)?
      builder;

  /// Should the plain text be used instead of the HTML text?
  final bool preferPlainText;

  /// The logger used by the library
  final Logger? logger;

  @override
  State<MimeMessageDownloader> createState() => _MimeMessageDownloaderState();
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
              return const Padding(
                padding: EdgeInsets.all(8),
                child: Center(
                  child: PlatformProgressIndicator(),
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

  Widget _buildMessageContent() => MimeMessageViewer(
        mimeMessage: mimeMessage,
        adjustHeight: widget.adjustHeight,
        blockExternalImages: widget.blockExternalImages,
        preferPlainText: widget.preferPlainText,
        enableDarkMode: widget.enableDarkMode,
        emptyMessageText: widget.emptyMessageText,
        mailtoDelegate: widget.mailtoDelegate,
        showMediaDelegate: widget.showMediaDelegate,
        urlLauncherDelegate: widget.urlLauncherDelegate,
        maxImageWidth: widget.maxImageWidth,
        onWebViewCreated: widget.onWebViewCreated,
        onZoomed: widget.onZoomed,
        onError: widget.onError,
        builder: widget.builder,
        logger: widget.logger,
      );

  Future<MimeMessage> _downloadMessageContents() async {
    try {
      // print('download message UID ${mimeMessage.uid} for state $this');

      mimeMessage = await widget.fetchMessageContents(
        widget.mimeMessage,
        maxSize: widget.maxDownloadSize,
        markAsSeen: widget.markAsSeen,
        includedInlineTypes: widget.includedInlineTypes,
        responseTimeout: widget.downloadTimeout,
      );
      widget.onDownloaded?.call(mimeMessage);
    } on MailException catch (e, s) {
      widget.onError?.call(e, s);
      if (widget.onError == null) {
        (widget.logger ?? defaultLogger).e(
          'Unable to download message '
          '${widget.mimeMessage.decodeSubject()}: $e',
          error: e,
          stackTrace: s,
        );
      }
    } catch (e, s) {
      (widget.logger ?? defaultLogger).e(
        'unexpected exception while downloading message with '
        'GUID ${widget.mimeMessage.guid} / '
        'UID ${widget.mimeMessage.uid} / '
        'ID ${widget.mimeMessage.sequenceId}: $e',
        error: e,
        stackTrace: s,
      );
      widget.onError?.call(e, s);
    }

    return mimeMessage;
  }
}
