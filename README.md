# enough_mail_flutter

Flutter widgets for email apps based on [enough_mail](https://pub.dev/packages/enough_mail).


## Usage
The `enough_mail_flutter` package contains the following widgets:
* `MimeMessageViewer` to display emails for which the contents has been already downloaded.
* `MimeMessageDownloader` to download message contents first if required - then uses the `MimeMessageViewer` to display. 

### MimeMessageViewer Usage
Using the `MimeMessageViewer` is quite straight forward:

```dart
import 'package:enough_mail/enough_mail.dart';
import 'package:enough_mail_flutter/enough_mail_flutter.dart';

Widget build(MimeMessage mimeMessage) {
  return MimeMessageViewer(
      mimeMessage: mimeMessage,
      blockExternalImages: false,
      mailtoDelegate: handleMailto,
    );
}

Future handleMailto(Uri mailto, MimeMessage mimeMessage) {
    final messageBuilder = 
        MessageBuilder.prepareMailtoBasedMessage(mailto, MyAccount.instance.fromAddress);
    return locator<NavigationService>()
        .push(Routes.mailCompose, arguments: messageBuilder);
  }

```

### MimeMessageDownloader Usage
The `MimeMessageDownloader` downloads the message contents first if required and then uses the `MimeMessageViewer` to display the contents.
You can specify most of the `MimeMessageViewer` options also on the `MimeMessageDownloader`. Refer to the API documentation for other specific configuration options.

The implementation assumes that the `size` and `envelope` information have been previously downloaded,
e.g. using `MailClient.fetchMessages(fetchPreference: FetchPreference.envelope)`.

```dart
Widget buildViewerForMessage(MimeMessage mimeMessage, MailClient mailClient) {
  return MimeMessageDownloader(
    mimeMessage: mimeMessage,
    mailClient: mailClient,
    onDownloaded: onMessageDownloaded,
    blockExternalImages: false,
    markAsSeen: true,
    mailtoDelegate: handleMailto,
  );
}

void onMessageDownloaded(MimeMessage mimeMessage) {
  // update other things to show eg attachment view, e.g.:
  //setState(() {});
}
```

## Installation
Add this dependency your pubspec.yaml file:

```
dependencies:
  enough_mail_flutter: ^1.2.0
```
The latest version or `enough_mail_flutter` is [![enough_mail_flutter version](https://img.shields.io/pub/v/enough_mail_flutter.svg)](https://pub.dartlang.org/packages/enough_mail_flutter).


## Features and bugs

Please file feature requests and bugs at the [issue tracker][tracker].

[tracker]: https://github.com/enough-software/enough_mail_flutter/issues

## License

Licensed under the commercial friendly [Mozilla Public License 2.0](LICENSE).