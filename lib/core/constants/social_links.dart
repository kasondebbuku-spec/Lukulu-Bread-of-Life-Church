/// Community links shown around the app. Kept in one place so they're easy
/// to update without hunting through screens.
class SocialLinks {
  static const String whatsAppGroup =
      'https://chat.whatsapp.com/I4a7XrkCV6s0zZ1yjznKPV?s=cl&p=a&ilr=1';

  /// Church Facebook page (or its live video) -- the dashboard's "Watch Live"
  /// button opens this. Leave empty to hide the button.
  static const String facebookLive = 'https://www.facebook.com/share/1JTY4oKpvd/';

  static bool get hasFacebookLive => facebookLive.isNotEmpty;
}
