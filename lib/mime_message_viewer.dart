import 'dart:async';
import 'dart:convert';

import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:enough_mail_html/enough_mail_html.dart';
import 'package:url_launcher/url_launcher.dart' as launcher;

/// Viewer for mime message contents
class MimeMessageViewer extends StatefulWidget {
  final MimeMessage mimeMessage;
  final bool adjustHeight;
  final bool blockExternalImages;
  final String emptyMessageText;
  final FutureOr<NavigationDecision> Function(NavigationRequest)
      navigationDelegate;
  final Future Function(Uri mailto, MimeMessage mimeMessage) mailtoDelegate;

  /// Creates a new mime message viewer
  /// [mimeMessage] The message with loaded message contents.
  /// [adjustHeight] Should the webview measure itself and adapt its size? This defaults to `true`.
  /// [blockExternalImages]  Should external images be prevented from loaded? This defaults to `false`.
  /// [emptyMessageText] The default text that should be shown for empty messages.
  /// [navigationDelegate] Browser navigation delegate in case the implementation wants to take over full control about links.
  /// [mailtoDelegate] Handler for mailto: links. Typically you will want to open a new compose view prepulated with a `MessageBuilder.prepareMailtoBasedMessage(uri,from)` instance.
  MimeMessageViewer({
    Key key,
    @required this.mimeMessage,
    this.adjustHeight = true,
    this.blockExternalImages = false,
    this.emptyMessageText,
    this.navigationDelegate,
    this.mailtoDelegate,
  }) : super(key: key);

  @override
  _MimeMessageViewerState createState() => _MimeMessageViewerState();
}

class _MimeMessageViewerState extends State<MimeMessageViewer> {
  double _screenHeight;
  WebViewController _webViewController;
  double _webViewHeight;
  String _base64EncodedHtml;
  bool _wereExternalImagesBlocked;

  @override
  void initState() {
    generateHtml(widget.blockExternalImages);
    super.initState();
  }

  void generateHtml(bool blockExternalImages) {
    final html = widget.mimeMessage.transformToHtml(
        blockExternalImages: blockExternalImages,
        emptyMessageText: widget.emptyMessageText);
    _base64EncodedHtml = 'data:text/html;base64,' +
        base64Encode(const Utf8Encoder().convert(html));
  }

  @override
  Widget build(BuildContext context) {
    _screenHeight = MediaQuery.of(context).size.height;
    if (widget.blockExternalImages != _wereExternalImagesBlocked) {
      generateHtml(widget.blockExternalImages);
    }
    if (widget.adjustHeight) {
      return LayoutBuilder(
        builder: (context, constraints) {
          if (!constraints.hasBoundedHeight) {
            constraints = constraints.copyWith(
                maxHeight: _webViewHeight ?? _screenHeight);
          }
          return ConstrainedBox(
            constraints: constraints,
            child: buildWebVew(),
          );
        },
      );
    } else {
      return buildWebVew();
    }
  }

  WebView buildWebVew() {
    return WebView(
      key: ValueKey(_base64EncodedHtml),
      javascriptMode: JavascriptMode.unrestricted,
      initialUrl: _base64EncodedHtml,
      gestureRecognizers: null,
      onWebViewCreated: (controller) {
        _webViewController = controller;
      },
      navigationDelegate: widget.navigationDelegate ?? handleNavigationProcess,
      onPageFinished: widget.adjustHeight
          ? (url) async {
              var scrollHeightText = await _webViewController
                  .evaluateJavascript('document.body.scrollHeight');
              double height = double.tryParse(scrollHeightText);
              if ((height != null)) {
                // && (height < screenHeight)) {
                // allow to scroll webpages further than the screen height, this
                // can lead to crashes but we have to live with that for the moment,
                // until it is fixed by either Flutter or thewebview_flutter plugin
                setState(() => _webViewHeight = height + 5);
              }
            }
          : null,
    );
  }

  FutureOr<NavigationDecision> handleNavigationProcess(
      NavigationRequest request) async {
    if (widget.mailtoDelegate != null && request.url.startsWith('mailto:')) {
      final mailto = Uri.parse(request.url);
      await widget.mailtoDelegate(mailto, widget.mimeMessage);
      return NavigationDecision.prevent;
    }
    if (await launcher.canLaunch(request.url)) {
      await launcher.launch(request.url);
      return NavigationDecision.prevent;
    } else {
      return NavigationDecision.navigate;
    }
  }
}
