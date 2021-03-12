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
