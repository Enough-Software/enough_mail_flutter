## [2.1.1] - (2024-05-22)
- Remove direct MailClient usage from MimeMessageDownloader
- Update dependencies

## [2.1.0] - 2023-10-05
- Switch to inapp_webview 6 (beta)
- Feat: support to specify own fetching method, Setting your own fetching method can be useful for downloading the message contents e.g. from disk. 
- Feat: MimeMessageDownloader also support setting download timeouts now.


## [2.0.0] - 2022-05-18
- New `preferPlainText` option to display the mime message's plain text part when available.
- New `enableDarkMode` option to use dark mode rendering.
- New `urlLauncherDelegate` option to control opening of links.  
- Ensure compatibility with Flutter 3.0.


## [1.4.0] - 2021-07-31
- Register a `builder` function to overtake building for specific messages.

## [1.3.0] - 2021-07-21
- Updated dependencies, improved documentation

## [1.2.0] - 2021-06-13
- Adapt to API changes of dependent libraries and Flutter
- Restructure package
- Ensure compatibility with WebKit / iOS

## [1.1.0] - 2021-04-15
- To improve download speed, you can limit the included media types when downloading the message contents with the `MessageDownloader.includedInlineTypes` parameter, e.g. `return MessageDownloader(includedInlineTypes: [MediaToptype.image]);`.
- Use the `fetchId` to retrieve inline message parts in links starting with `fetch://`
- Do not scale plain text messages

## [1.0.0] - 2021-04-07
- `enough_mail_flutter` is now [null safe](https://dart.dev/null-safety/tour) #7
- support dark theme
- allow to specify `onWebViewCreated` and `onZoomed` callbacks
- fix handling of embdedded images linked via content-IDs #8

## [0.4.0] - 2021-03-10.
* Use `InAppWebview` in hybrid mode on Android so that long messages are not a problem anymore
* Zoom out of wide messages automatically
* Update dependencies for null-safety preparation

## [0.3.0] - 2021-02-02.
* Generate HTML asynchronously.
* Catch any problems during downloading and signal them to the widget owner with the `onDownloadError` handler.
* Use `enough_media` package to render media.
* Fix problem when `setState()` was called after the widget was not mounted anymore.

## [0.2.1] - 2021-01-11.
* Download messages only once.
* Show an image message directly and not in HTML browser.
* Adapt to `enough_mail` API changes.

## [0.2.0] - 2020-12-04.
* Added `MimeMessageDownloader` widget.
* Improve documentation.

## [0.1.0] - 2020-12-04.

* Initial release with the `MimeMessageViewer` widget.
