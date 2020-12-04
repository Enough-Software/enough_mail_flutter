# enough_mail_flutter

Flutter UI components for mail apps.


## Usage
The current `enough_mail_flutter` package provides the `MimeMessageViewer` component that displays email contents within an embedded `WebView`.

A simple usage example:

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

## Installation
Add this dependency your pubspec.yaml file:

```
dependencies:
  enough_mail_flutter: ^0.1.0
```
The latest version or `enough_mail_flutter` is [![enough_mail_flutter version](https://img.shields.io/pub/v/enough_mail_flutter.svg)](https://pub.dartlang.org/packages/enough_mail_flutter).


## Features and bugs

Please file feature requests and bugs at the [issue tracker][tracker].

[tracker]: https://github.com/enough-software/enough_mail_flutter/issues

## License

Licensed under the commercial friendly [Mozilla Public License 2.0](LICENSE).