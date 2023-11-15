import 'dart:async';

import 'package:enough_mail/enough_mail.dart';
import 'package:enough_mail_html/enough_mail_html.dart';
import 'package:enough_media/enough_media.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:logger/logger.dart';
import 'package:url_launcher/url_launcher.dart' as launcher;

import 'logger.dart';
import 'mime_media_provider.dart';
import 'progress_indicator.dart';

/// Viewer for mime message contents
class MimeMessageViewer extends StatelessWidget {
  /// Creates a new mime message viewer
  const MimeMessageViewer({
    super.key,
    required this.mimeMessage,
    this.adjustHeight = true,
    this.blockExternalImages = false,
    this.preferPlainText = false,
    this.enableDarkMode = false,
    this.emptyMessageText,
    this.mailtoDelegate,
    this.showMediaDelegate,
    this.urlLauncherDelegate,
    this.maxImageWidth,
    this.onWebViewCreated,
    this.onZoomed,
    this.onError,
    this.builder,
    this.logger,
  });

  /// The mime message that should be shown
  final MimeMessage mimeMessage;

  /// The optional maximum width for inline images
  final int? maxImageWidth;

  /// Sets if the height of this view should be set automatically.
  ///
  /// This is required to be `true` when using the MimeMessageViewer
  /// in a scrollable view.
  final bool adjustHeight;

  /// Defines if external images should be removed
  final bool blockExternalImages;

  /// Should the plain text be used instead of the HTML text?
  final bool preferPlainText;

  /// Defines if dark mode should be enabled.
  ///
  /// This might be required on devices with older browser implementations.
  final bool enableDarkMode;

  /// The default text that should be shown for empty messages.
  final String? emptyMessageText;

  /// Handler for mailto: links.
  ///
  /// Typically you will want to open a new compose view pre-populated with
  /// a `MessageBuilder.prepareMailtoBasedMessage(uri,from)` instance.
  final Future Function(Uri mailto, MimeMessage mimeMessage)? mailtoDelegate;

  /// Handler for showing the given media widget, typically in its own screen
  final Future Function(InteractiveMediaWidget mediaViewer)? showMediaDelegate;

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

  /// The logger instance used by the library
  final Logger? logger;

  @override
  Widget build(BuildContext context) {
    final callback = builder;
    if (callback != null) {
      final builtWidget = callback(context, mimeMessage);
      if (builtWidget != null) {
        return builtWidget;
      }
    }

    return mimeMessage.mediaType.isImage
        ? _ImageMimeMessageViewer(config: this)
        : _HtmlMimeMessageViewer(config: this);
  }
}

class _HtmlGenerationArguments {
  const _HtmlGenerationArguments(
    this.mimeMessage,
    this.emptyMessageText,
    this.maxImageWidth, {
    required this.enableDarkMode,
    required this.preferPlainText,
    required this.blockExternalImages,
    required this.logger,
  });

  final MimeMessage mimeMessage;
  final bool blockExternalImages;
  final bool preferPlainText;
  final bool enableDarkMode;
  final String? emptyMessageText;
  final int? maxImageWidth;
  final Logger logger;
}

class _HtmlGenerationResult {
  const _HtmlGenerationResult.success(this.html) : errorDetails = null;

  const _HtmlGenerationResult.error(this.errorDetails) : html = null;

  final String? html;
  final String? errorDetails;
}

class _HtmlMimeMessageViewer extends StatefulWidget {
  const _HtmlMimeMessageViewer({required this.config});
  final MimeMessageViewer config;

  @override
  State<StatefulWidget> createState() => _HtmlViewerState();
}

class _HtmlViewerState extends State<_HtmlMimeMessageViewer> {
  String? _htmlData;
  bool? _wereExternalImagesBlocked;
  bool _isGenerating = false;
  Widget? _mediaView;

  double? _webViewHeight;
  bool _isHtmlMessage = true;
  bool _isLoading = true;

  @override
  void initState() {
    _generateHtml(
      widget.config.blockExternalImages,
      widget.config.preferPlainText,
      widget.config.enableDarkMode,
    );
    super.initState();
  }

  Future<void> _generateHtml(
    bool blockExternalImages,
    bool preferPlainText,
    bool enableDarkMode,
  ) async {
    _wereExternalImagesBlocked = blockExternalImages;
    _isGenerating = true;
    final mimeMessage = widget.config.mimeMessage;
    _isHtmlMessage = mimeMessage.hasPart(MediaSubtype.textHtml);
    final args = _HtmlGenerationArguments(
      mimeMessage,
      widget.config.emptyMessageText,
      widget.config.maxImageWidth,
      preferPlainText: preferPlainText,
      enableDarkMode: enableDarkMode,
      blockExternalImages: blockExternalImages,
      logger: widget.config.logger ?? defaultLogger,
    );
    final result = await compute(_generateHtmlImpl, args);
    _htmlData = result.html;
    if (_htmlData == null) {
      widget.config.onError?.call(result.errorDetails, null);
    }
    if (mounted) {
      setState(() {
        _isGenerating = false;
      });
    }
  }

  static _HtmlGenerationResult _generateHtmlImpl(
    _HtmlGenerationArguments args,
  ) {
    try {
      final html = args.mimeMessage.transformToHtml(
        blockExternalImages: args.blockExternalImages,
        preferPlainText: args.preferPlainText,
        enableDarkMode: args.enableDarkMode,
        emptyMessageText: args.emptyMessageText,
        maxImageWidth: args.maxImageWidth,
      );
      args.logger.d(html);

      return _HtmlGenerationResult.success(html);
    } catch (e, s) {
      args.logger.e(
        'unable to transform mime message to HTML: $e',
        error: e,
        stackTrace: s,
      );
      final errorDetails = '$e\n\n$s';

      return _HtmlGenerationResult.error(errorDetails);
    }
  }

  Logger get logger => widget.config.logger ?? defaultLogger;

  @override
  Widget build(BuildContext context) {
    final mediaView = _mediaView;
    if (mediaView != null) {
      return WillPopScope(
        child: mediaView,
        onWillPop: () {
          setState(() {
            _mediaView = null;
          });

          return Future.value(false);
        },
      );
    }
    if (_isGenerating) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: Center(
          child: PlatformProgressIndicator(),
        ),
      );
    }
    if (widget.config.blockExternalImages != _wereExternalImagesBlocked) {
      _generateHtml(
        widget.config.blockExternalImages,
        widget.config.preferPlainText,
        widget.config.enableDarkMode,
      );
    }

    if (widget.config.adjustHeight) {
      final size = MediaQuery.of(context).size;
      final height = _webViewHeight ?? size.height;

      return SizedBox(
        height: height,
        child: _buildWebViewWithLoadingIndicator(),
      );
    } else {
      return _buildWebViewWithLoadingIndicator();
    }
  }

  Widget _buildWebViewWithLoadingIndicator() => Stack(
        children: [
          _buildWebView(),
          if (_isLoading)
            const Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: PlatformProgressIndicator(),
              ),
            ),
        ],
      );

  Widget _buildWebView() {
    final htmlData = _htmlData;
    if (htmlData == null) {
      return const SizedBox.shrink();
    }

    return InAppWebView(
      key: ValueKey(htmlData),
      initialSettings: InAppWebViewSettings(
        useShouldOverrideUrlLoading: true,
        transparentBackground: true,
        forceDark: widget.config.enableDarkMode ? ForceDark.ON : ForceDark.AUTO,
      ),
      onWebViewCreated: (controller) async {
        await controller.loadData(data: htmlData);
        widget.config.onWebViewCreated?.call(controller);
      },
      onLoadStop: (controller, uri) async {
        logger.d('onPageFinished $uri');

        if (widget.config.adjustHeight) {
          final scrollHeightJs = await controller.evaluateJavascript(
            source: 'document.body.scrollHeight',
          );
          final scrollHeight =
              scrollHeightJs is num ? scrollHeightJs.toDouble() : 0.0;
          final scrollWidthJs = await controller.evaluateJavascript(
            source: 'document.body.scrollWidth',
          );
          var scrollWidth =
              scrollWidthJs is num ? scrollWidthJs.toDouble() : 0.0;
          if (mounted) {
            final size = MediaQuery.sizeOf(context);
            logger.d(
              'detected scrollWidth: $scrollWidth, '
              'scrollHeight: $scrollHeight, '
              'available width: ${size.width} '
              'available height: ${size.height}',
            );
            if (_isHtmlMessage && scrollWidth > size.width + 10.0) {
              var scale = size.width / scrollWidth;
              const minScale = 0.5;
              if (scale < minScale) {
                scale = minScale;
                scrollWidth = size.width / minScale;
              }
              await controller.zoomBy(zoomFactor: scale, animated: true);
              final callback = widget.config.onZoomed;
              if (callback != null) {
                callback(controller, scale);
              }
            }
            final scrollHeightWithBuffer = scrollHeight + 10.0;
            if (mounted && _webViewHeight != scrollHeightWithBuffer) {
              setState(() {
                _webViewHeight = scrollHeightWithBuffer;
                _isLoading = false;
                // print('webViewHeight set to $_webViewHeight');
                // print('webViewWidth set to $_webViewWidth');
              });
            }
          }
        }
        if (mounted && _isLoading) {
          setState(() {
            _isLoading = false;
          });
        }
      },
      shouldOverrideUrlLoading: _shouldOverrideUrlLoading,
      gestureRecognizers: widget.config.adjustHeight
          ? {
              const Factory<LongPressGestureRecognizer>(
                LongPressGestureRecognizer.new,
              ),
            }
          : null,
    );
  }

  Future<NavigationActionPolicy?> _shouldOverrideUrlLoading(
    InAppWebViewController controller,
    NavigationAction navigationAction,
  ) async {
    logger.d('onNavigation $navigationAction');
    final requestUri = navigationAction.request.url;
    if (requestUri == null) {
      return NavigationActionPolicy.ALLOW;
    }
    // for iOS / WKWebView necessary:
    if (navigationAction.isForMainFrame &&
        requestUri.toString() == 'about:blank') {
      return NavigationActionPolicy.ALLOW;
    }
    final mimeMessage = widget.config.mimeMessage;
    final mailtoHandler = widget.config.mailtoDelegate;
    if (mailtoHandler != null && requestUri.isScheme('mailto')) {
      await mailtoHandler(requestUri, mimeMessage);

      return NavigationActionPolicy.CANCEL;
    }
    if (requestUri.isScheme('cid') || requestUri.isScheme('fetch')) {
      // show inline part:
      final cid = Uri.decodeComponent(requestUri.host);
      final part = requestUri.isScheme('cid')
          ? mimeMessage.getPartWithContentId(cid)
          : mimeMessage.getPart(cid);
      if (part != null) {
        final mediaProvider =
            MimeMediaProviderFactory.fromMime(mimeMessage, part);
        final mediaWidget = InteractiveMediaWidget(
          mediaProvider: mediaProvider,
        );
        final showMediaCallback = widget.config.showMediaDelegate;
        if (showMediaCallback != null) {
          await showMediaCallback(mediaWidget);
        } else {
          setState(() {
            _mediaView = mediaWidget;
          });
        }
      }

      return NavigationActionPolicy.CANCEL;
    }
    final url = requestUri.toString();
    final urlDelegate = widget.config.urlLauncherDelegate;
    if (urlDelegate != null) {
      final handled = await urlDelegate(url);
      if (handled) {
        return NavigationActionPolicy.CANCEL;
      }
    }
    //if (await launcher.canLaunch(url)) {
    // not checking due to
    // https://github.com/flutter/flutter/issues/93765#issuecomment-1018994962
    await launcher.launchUrl(requestUri);

    return NavigationActionPolicy.CANCEL;
    // } else {
    //   return NavigationDecision.navigate;
    // }
  }
}

class _ImageMimeMessageViewer extends StatefulWidget {
  const _ImageMimeMessageViewer({required this.config});

  final MimeMessageViewer config;

  @override
  State<StatefulWidget> createState() => _ImageViewerState();
}

/// State for a message with  `Content-Type: image/XXX`
class _ImageViewerState extends State<_ImageMimeMessageViewer> {
  bool _showFullScreen = false;
  Uint8List? _imageData;

  @override
  void initState() {
    _imageData = widget.config.mimeMessage.decodeContentBinary();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (_showFullScreen) {
      final screenHeight = MediaQuery.of(context).size.height;

      return WillPopScope(
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (!constraints.hasBoundedHeight) {
              constraints = constraints.copyWith(maxHeight: screenHeight);
            }

            return ConstrainedBox(
              constraints: constraints,
              child: ImageInteractiveMedia(
                mediaProvider: MimeMediaProviderFactory.fromMime(
                  widget.config.mimeMessage,
                  widget.config.mimeMessage,
                ),
              ),
            );
          },
        ),
        onWillPop: () {
          setState(() => _showFullScreen = false);

          return Future.value(false);
        },
      );
    } else {
      final imageData = _imageData;

      return TextButton(
        onPressed: () {
          final callback = widget.config.showMediaDelegate;
          if (callback != null) {
            final mediaProvider = MimeMediaProviderFactory.fromMime(
              widget.config.mimeMessage,
              widget.config.mimeMessage,
            );
            final mediaWidget =
                InteractiveMediaWidget(mediaProvider: mediaProvider);
            callback(mediaWidget);
          } else {
            setState(() => _showFullScreen = true);
          }
        },
        child: imageData != null
            ? Image.memory(imageData)
            : const Text('no image data'),
      );
    }
  }
}
