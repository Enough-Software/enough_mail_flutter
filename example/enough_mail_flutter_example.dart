import 'package:enough_mail/enough_mail.dart';
import 'package:enough_mail_flutter/enough_mail_flutter.dart';
import 'package:flutter/widgets.dart';

/// Example implementation for displaying the message contents.
/// When required, the message contents are downloaded first.
/// The implementation assumes that the `size` and `envelope` information have been previously downloaded,
/// e.g. using `MailClient.fetchMessages(fetchPreference: FetchPreference.envelope)`.
Widget buildViewerForMessage(MimeMessage mimeMessage, MailClient mailClient) {
  return MimeMessageDownloader(
    mimeMessage: mimeMessage,
    mailClient: mailClient,
    onDownloaded: onMessageDownloaded,
    blockExternalImages: false,
    mailtoDelegate: handleMailto,
  );
}

// Example implementation of an optional onDownloaded delegate
void onMessageDownloaded(MimeMessage mimeMessage) {
  // update other things to show eg attachment view, e.g.:
  //setState(() {});
}

/// Example implementation for displaying a message
/// for which the contents already have been downloaded:
Widget buildViewerForDownloadedMessage(MimeMessage mimeMessage) {
  return MimeMessageViewer(
    mimeMessage: mimeMessage,
    blockExternalImages: false,
    mailtoDelegate: handleMailto,
  );
}

/// Example implementation for a mailto delegate
Future handleMailto(Uri mailto, MimeMessage mimeMessage) {
  // in reality you would get this from your account data
  final fromAddress = MailAddress('My Name', 'email@domain.com');
  final messageBuilder =
      MessageBuilder.prepareMailtoBasedMessage(mailto, fromAddress);
  // in reality navigate to compose screen, e.g.
  // return locator<NavigationService>()
  //     .push(Routes.mailCompose, arguments: messageBuilder);
  print(
      'generated message: ${messageBuilder.buildMimeMessage().renderMessage()}');
  return Future.value();
}
