import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:enough_mail/enough_mail.dart';
import 'package:enough_media/enough_media.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:enough_mail_html/enough_mail_html.dart';
import 'package:url_launcher/url_launcher.dart' as launcher;

import 'mime_media_provider.dart';

/// Viewer for mime message contents
class MimeMessageViewer extends StatelessWidget {
  /// The mime message that should be shown
  final MimeMessage mimeMessage;

  /// The optional maximum width for inline images
  final int? maxImageWidth;

  /// Sets if the height of this view should be set automatically, this is required to be `true` when using the MimeMessageViewer in a scrollable view.
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

  /// Handler for mailto: links. Typically you will want to open a new compose view prepulated with a `MessageBuilder.prepareMailtoBasedMessage(uri,from)` instance.
  final Future Function(Uri mailto, MimeMessage mimeMessage)? mailtoDelegate;

  /// Handler for showing the given media widget, typically in its own screen
  final Future Function(InteractiveMediaWidget mediaViewer)? showMediaDelegate;

  /// Handler for any non-media URLs that the user taps on the website, return `true` when the given `url` was handled.
  final Future<bool> Function(String url)? urlLauncherDelegate;

  /// Register this callback if you want a reference to the [InAppWebViewController].
  final void Function(InAppWebViewController controller)? onWebViewCreated;

  /// This callback will be called when the webview zooms out after loading, usually this is a sign that the user might want to zoom in again.
  final void Function(InAppWebViewController controller, double zoomFactor)?
      onZoomed;

  /// Is notified about any errors that might occur
  final void Function(Object? exception, StackTrace? stackTrace)? onError;

  /// With a builder you can take over the rendering for certain messages or mime types.
  final Widget? Function(BuildContext context, MimeMessage mimeMessage)?
      builder;

  /// Creates a new mime message viewer
  ///
  /// [mimeMessage] The message with loaded message contents.
  /// [adjustHeight] Should the webview measure itself and adapt its size? This defaults to `true`.
  /// [blockExternalImages]  Should external images be prevented from loaded? This defaults to `false`.
  /// Set [preferPlainText] to `true` to use plain text instead of the HTML text.
  /// Set [enableDarkMode] to `true` to enforce dark mode on devices with older browsers.
  /// [emptyMessageText] The default text that should be shown for empty messages.
  /// [mailtoDelegate] Handler for mailto: links. Typically you will want to open a new compose view prepulated with a `MessageBuilder.prepareMailtoBasedMessage(uri,from)` instance.
  /// [showMediaDelegate] Handler for showing the given media widget, typically in its own screen.
  /// Specify a [urlLauncherDelegate] when you want to handle URL invocations yourself.
  /// Optionally specify the [maxImageWidth] to set the maximum width for embedded images.
  /// Set the [onWebViewCreated] callback if you want a reference to the [InAppWebViewController].
  /// Set the [onZoomed] callback if you want to be notified when the webview is zoomed out after loading.
  /// Set the [onError] callback in case you want to be notfied about processing errors such as format exceptions.
  /// With a [builder] you can take over the rendering for certain messages or mime types.
  MimeMessageViewer({
    Key? key,
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
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final callback = builder;
    if (callback != null) {
      final builtWidget = callback(context, mimeMessage);
      if (builtWidget != null) {
        return builtWidget;
      }
    }
    if (mimeMessage.mediaType.isImage) {
      return _ImageMimeMessageViewer(config: this);
    } else {
      return _HtmlMimeMessageViewer(config: this);
    }
  }
}

class _HtmlGenerationArguments {
  final MimeMessage mimeMessage;
  final bool blockExternalImages;
  final bool preferPlainText;
  final bool enableDarkMode;
  final String? emptyMessageText;
  final int? maxImageWidth;

  const _HtmlGenerationArguments(
    this.mimeMessage,
    this.blockExternalImages,
    this.preferPlainText,
    this.enableDarkMode,
    this.emptyMessageText,
    this.maxImageWidth,
  );
}

class _HtmlGenerationResult {
  final String? html;
  final String? errorDetails;
  const _HtmlGenerationResult.success(this.html) : errorDetails = null;

  const _HtmlGenerationResult.error(this.errorDetails) : this.html = null;
}

class _HtmlMimeMessageViewer extends StatefulWidget {
  final MimeMessageViewer config;
  _HtmlMimeMessageViewer({Key? key, required this.config}) : super(key: key);

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

  @override
  void initState() {
    _generateHtml(widget.config.blockExternalImages,
        widget.config.preferPlainText, widget.config.enableDarkMode);
    super.initState();
  }

  void _generateHtml(bool blockExternalImages, bool preferPlainText,
      bool enableDarkMode) async {
    _wereExternalImagesBlocked = blockExternalImages;
    _isGenerating = true;
    final mimeMessage = widget.config.mimeMessage;
    _isHtmlMessage = mimeMessage.hasPart(MediaSubtype.textHtml);
    final args = _HtmlGenerationArguments(
      mimeMessage,
      blockExternalImages,
      preferPlainText,
      enableDarkMode,
      widget.config.emptyMessageText,
      widget.config.maxImageWidth,
    );
    final result = await compute(_generateHtmlImpl, args);
    _htmlData = result.html;
    if (_htmlData == null) {
      final onError = widget.config.onError;
      if (onError != null) {
        onError(result.errorDetails, null);
      }
    }
    if (mounted) {
      setState(() {
        _isGenerating = false;
      });
    }
  }

  static _HtmlGenerationResult _generateHtmlImpl(
      _HtmlGenerationArguments args) {
    try {
      final html = args.mimeMessage.transformToHtml(
        blockExternalImages: args.blockExternalImages,
        preferPlainText: args.preferPlainText,
        enableDarkMode: args.enableDarkMode,
        emptyMessageText: args.emptyMessageText,
        maxImageWidth: args.maxImageWidth,
      );
      return _HtmlGenerationResult.success(html);
    } catch (e, s) {
      print('ERROR: unable to transform mime message to HTML: $e $s');
      String errorDetails = e.toString() + '\n\n' + s.toString();
      return _HtmlGenerationResult.error(errorDetails);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_mediaView != null) {
      return WillPopScope(
        child: _mediaView!,
        onWillPop: () {
          setState(() {
            _mediaView = null;
          });
          return Future.value(false);
        },
      );
    }
    if (_isGenerating) {
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: Center(
          child: (Platform.isIOS || Platform.isMacOS)
              ? CupertinoActivityIndicator()
              : CircularProgressIndicator(),
        ),
      );
    }
    if (widget.config.blockExternalImages != _wereExternalImagesBlocked) {
      _generateHtml(widget.config.blockExternalImages,
          widget.config.preferPlainText, widget.config.enableDarkMode);
    }

    if (widget.config.adjustHeight) {
      final size = MediaQuery.of(context).size;
      return SizedBox(
        height: _webViewHeight ?? size.height,
        width: size.width,
        child: _buildWebView(),
      );
    } else {
      return _buildWebView();
    }
  }

  Widget _buildWebView() {
    if (_htmlData == null) {
      return Container();
    }
    final theme = Theme.of(context);
    final isDark =
        (theme.brightness == Brightness.dark) || widget.config.enableDarkMode;
    return InAppWebView(
      key: ValueKey(_htmlData),
      initialData: InAppWebViewInitialData(data: _htmlData!),
      initialOptions: InAppWebViewGroupOptions(
        crossPlatform: InAppWebViewOptions(
          useShouldOverrideUrlLoading: true,
          verticalScrollBarEnabled: false,
          transparentBackground: isDark,
        ),
        android: AndroidInAppWebViewOptions(
          useWideViewPort: false,
          loadWithOverviewMode: true,
          useHybridComposition: true,
          forceDark: isDark
              ? AndroidForceDark.FORCE_DARK_ON
              : AndroidForceDark.FORCE_DARK_OFF,
        ),
      ),
      onWebViewCreated: widget.config.onWebViewCreated,
      onLoadStop: (controller, url) async {
        if (widget.config.adjustHeight) {
          var scrollHeight = (await controller.evaluateJavascript(
              source: 'document.body.scrollHeight'));
          // print('scrollHeight: $scrollHeight');
          if (scrollHeight != null) {
            final scrollWidth = (await controller.evaluateJavascript(
                source: 'document.body.scrollWidth'));
            // print('scrollWidth: $scrollWidth');
            final size = MediaQuery.of(context).size;
            // print('size: ${size.height}x${size.width}');
            if (_isHtmlMessage && scrollWidth > size.width) {
              var scale = (size.width / scrollWidth);
              if (scale < 0.2) {
                scale = 0.2;
              }
              await controller.zoomBy(zoomFactor: scale, iosAnimated: true);
              scrollHeight = (scrollHeight * scale).ceil();
              final callback = widget.config.onZoomed;
              if (callback != null) {
                callback(controller, scale);
              }
            }
            setState(() {
              _webViewHeight = (scrollHeight + 10.0);
              // print('webViewHeight set to $_webViewHeight');
            });
          }
        }
      },
      shouldOverrideUrlLoading: _shouldOverrideUrlLoading,
      androidOnPermissionRequest: (controller, origin, resources) {
        // print('androidOnPermissionRequest for $resources');
        return Future.value(
          PermissionRequestResponse(
              resources: resources,
              action: PermissionRequestResponseAction.GRANT),
        );
      },
      gestureRecognizers: widget.config.adjustHeight
          ? {
              Factory<LongPressGestureRecognizer>(
                  () => LongPressGestureRecognizer()),
              // The scale gesture recognizer interferes with scrolling on Flutter 2.2
              // Factory<ScaleGestureRecognizer>(() => ScaleGestureRecognizer()),
            }
          : null,
    );
  }

  Future<NavigationActionPolicy> _shouldOverrideUrlLoading(
      InAppWebViewController controller, NavigationAction request) async {
    final requestUri = request.request.url!;
    final mimeMessage = widget.config.mimeMessage;
    final mailtoHandler = widget.config.mailtoDelegate;
    if (mailtoHandler != null && requestUri.isScheme('mailto')) {
      await mailtoHandler(requestUri, mimeMessage);
      return NavigationActionPolicy.CANCEL;
    }
    if (requestUri.isScheme('cid') || requestUri.isScheme('fetch')) {
      // show inline part:
      var cid = Uri.decodeComponent(requestUri.host);
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
          showMediaCallback(mediaWidget);
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
    if (await launcher.canLaunch(url)) {
      await launcher.launch(url);
      return NavigationActionPolicy.CANCEL;
    } else {
      return NavigationActionPolicy.ALLOW;
    }
  }
}

class _ImageMimeMessageViewer extends StatefulWidget {
  final MimeMessageViewer config;

  const _ImageMimeMessageViewer({Key? key, required this.config})
      : super(key: key);
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
                      widget.config.mimeMessage, widget.config.mimeMessage)),
            );
          },
        ),
        onWillPop: () {
          setState(() => _showFullScreen = false);
          return Future.value(false);
        },
      );
    } else {
      return TextButton(
        onPressed: () {
          final callback = widget.config.showMediaDelegate;
          if (callback != null) {
            final mediaProvider = MimeMediaProviderFactory.fromMime(
                widget.config.mimeMessage, widget.config.mimeMessage);
            final mediaWidget =
                InteractiveMediaWidget(mediaProvider: mediaProvider);
            callback(mediaWidget);
          } else {
            setState(() => _showFullScreen = true);
          }
        },
        child: _imageData != null
            ? Image.memory(_imageData!)
            : Text('no image data'),
      );
    }
  }
}
