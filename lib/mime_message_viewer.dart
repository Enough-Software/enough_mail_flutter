import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:enough_mail/enough_mail.dart';
import 'package:enough_mail_flutter/enough_mail_flutter.dart';
import 'package:enough_mail_flutter/mime_media_provider.dart';
import 'package:enough_media/enough_media.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:enough_mail_html/enough_mail_html.dart';
import 'package:url_launcher/url_launcher.dart' as launcher;

/// Viewer for mime message contents
class MimeMessageViewer extends StatefulWidget {
  final MimeMessage mimeMessage;
  final int? maxImageWidth;
  final bool adjustHeight;
  final bool blockExternalImages;
  final String? emptyMessageText;
  final Future Function(Uri mailto, MimeMessage mimeMessage)? mailtoDelegate;
  final Future Function(InteractiveMediaWidget mediaViewer)? showMediaDelegate;

  /// Creates a new mime message viewer
  ///
  /// [mimeMessage] The message with loaded message contents.
  /// [adjustHeight] Should the webview measure itself and adapt its size? This defaults to `true`.
  /// [blockExternalImages]  Should external images be prevented from loaded? This defaults to `false`.
  /// [emptyMessageText] The default text that should be shown for empty messages.
  /// [mailtoDelegate] Handler for mailto: links. Typically you will want to open a new compose view prepulated with a `MessageBuilder.prepareMailtoBasedMessage(uri,from)` instance.
  /// [showMediaDelegate] Handler for showing the given media widget, typically in its own screen
  /// Optionally specify the [maxImageWidth] to set the maximum width for embedded images.
  MimeMessageViewer({
    Key? key,
    required this.mimeMessage,
    this.adjustHeight = true,
    this.blockExternalImages = false,
    this.emptyMessageText,
    this.mailtoDelegate,
    this.showMediaDelegate,
    this.maxImageWidth,
  }) : super(key: key);

  @override
  State<MimeMessageViewer> createState() {
    if (mimeMessage.mediaType.isImage == true) {
      return _ImageViewerState();
    } else {
      return _HtmlViewerState();
    }
  }
}

class _HtmlGenerationArguments {
  final MimeMessage mimeMessage;
  final bool blockExternalImages;
  final String? emptyMessageText;
  final int? maxImageWidth;
  _HtmlGenerationArguments(this.mimeMessage, this.blockExternalImages,
      this.emptyMessageText, this.maxImageWidth);
}

class _HtmlViewerState extends State<MimeMessageViewer> {
  String? _htmlData;
  bool? _wereExternalImagesBlocked;
  bool _isGenerating = false;
  Widget? _mediaView;

  double? _webViewHeight;

  @override
  void initState() {
    generateHtml(widget.blockExternalImages);
    super.initState();
  }

  void generateHtml(bool blockExternalImages) async {
    _wereExternalImagesBlocked = blockExternalImages;
    _isGenerating = true;
    final args = _HtmlGenerationArguments(widget.mimeMessage,
        blockExternalImages, widget.emptyMessageText, widget.maxImageWidth);
    _htmlData = await compute(_generateHtmlImpl, args);
    if (mounted) {
      setState(() {
        _isGenerating = false;
      });
    }
  }

  static String _generateHtmlImpl(_HtmlGenerationArguments args) {
    final html = args.mimeMessage.transformToHtml(
      blockExternalImages: args.blockExternalImages,
      emptyMessageText: args.emptyMessageText,
      maxImageWidth: args.maxImageWidth,
    );
    return html;
    // return 'data:text/html;base64,' +
    //     base64Encode(const Utf8Encoder().convert(html));
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
      return Container(child: CircularProgressIndicator());
    }
    if (widget.blockExternalImages != _wereExternalImagesBlocked) {
      generateHtml(widget.blockExternalImages);
    }

    if (widget.adjustHeight) {
      final size = MediaQuery.of(context).size;
      return SizedBox(
        height: _webViewHeight ?? size.height,
        width: size.width,
        child: buildWebView(),
      );
    } else {
      return buildWebView();
    }
  }

  Widget buildWebView() {
    final theme = Theme.of(context);
    final isDark = (theme.brightness == Brightness.dark);
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
      onLoadStop: !widget.adjustHeight
          ? null
          : (controller, url) async {
              int? scrollHeight = (await controller.evaluateJavascript(
                  source: 'document.body.scrollHeight')) as int?;
              if (scrollHeight != null) {
                if (Platform.isAndroid) {
                  int scrollWidth = (await controller.evaluateJavascript(
                      source: 'document.body.scrollWidth')) as int;
                  final size = MediaQuery.of(context).size;
                  if (scrollWidth > size.width) {
                    final scale = (size.width / scrollWidth);
                    if (scale > 0.1) {
                      await controller.zoomBy(
                          zoomFactor: scale, iosAnimated: true);
                      scrollHeight = (scrollHeight * scale).ceil();
                    }
                  }
                }
                setState(() {
                  _webViewHeight = (scrollHeight! + 10.0);
                });
              }
            },
      shouldOverrideUrlLoading: shouldOverrideUrlLoading,
      androidOnPermissionRequest: (controller, origin, resources) {
        print('androidOnPermissionRequest for $resources');
        return Future.value(PermissionRequestResponse(
            resources: resources,
            action: PermissionRequestResponseAction.GRANT));
      },
    );
  }

  Future<NavigationActionPolicy> shouldOverrideUrlLoading(
      InAppWebViewController controller, NavigationAction request) async {
    final requestUri = request.request.url!;
    if (widget.mailtoDelegate != null && requestUri.isScheme('mailto')) {
      await widget.mailtoDelegate!(requestUri, widget.mimeMessage);
      return NavigationActionPolicy.CANCEL;
    }
    if (requestUri.isScheme('cid')) {
      // show inline part:
      final cid = requestUri.path;
      final part = widget.mimeMessage.getPartWithContentId(cid);
      if (part != null) {
        final mediaProvider =
            MimeMediaProviderFactory.fromMime(widget.mimeMessage, part);
        final mediaWidget = InteractiveMediaWidget(
          mediaProvider: mediaProvider,
        );
        if (widget.showMediaDelegate != null) {
          widget.showMediaDelegate!(mediaWidget);
        } else {
          setState(() {
            _mediaView = mediaWidget;
          });
        }
      }
      return NavigationActionPolicy.CANCEL;
    }
    final url = requestUri.toString();
    if (await launcher.canLaunch(url)) {
      await launcher.launch(url);
      return NavigationActionPolicy.CANCEL;
    } else {
      return NavigationActionPolicy.ALLOW;
    }
  }
}

/// State for a message with  `Content-Type: image/XXX`
class _ImageViewerState extends State<MimeMessageViewer> {
  bool showFullScreen = false;
  Uint8List? imageData;

  @override
  void initState() {
    imageData = widget.mimeMessage.decodeContentBinary();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (showFullScreen) {
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
                      widget.mimeMessage, widget.mimeMessage)),
            );
          },
        ),
        onWillPop: () {
          setState(() => showFullScreen = false);
          return Future.value(false);
        },
      );
    } else {
      return TextButton(
        onPressed: () {
          if (widget.showMediaDelegate != null) {
            final mediaProvider = MimeMediaProviderFactory.fromMime(
                widget.mimeMessage, widget.mimeMessage);
            final mediaWidget =
                InteractiveMediaWidget(mediaProvider: mediaProvider);
            widget.showMediaDelegate!(mediaWidget);
          } else {
            setState(() => showFullScreen = true);
          }
        },
        child: imageData != null
            ? Image.memory(imageData!)
            : Text('no image data'),
      );
    }
  }
}
