import 'package:bett_box/white_label/white_label_config.dart';
import 'package:flutter/widgets.dart';

class WhiteLabelStrings {
  final Locale locale;

  const WhiteLabelStrings(this.locale);

  String get website => 'Website';
  String get support => 'Support';
  String get onlineSupport => 'Online support';
  String get signedIn => 'Signed in';
  String get userData => 'User data';
  String get expires => 'Expires';
  String get noPlanData => 'No plan data';
  String get unlimited => 'Unlimited';
  String get never => 'Never';
  String get signOut => 'Sign out';
  String get signOutDesc => 'Clear this account and subscription';
  String get logoutFailed => 'Logout failed';
  String get aboutDesc =>
      '$whiteLabelDisplayName is based on the Mihomo proxy core and built for a better experience.';

  String get announcements => 'Announcements';
  String get announcementsDesc => 'Service notices';
  String get noAnnouncements => 'No announcements';
  String get tickets => 'Tickets';
  String get ticketsDesc => 'Questions and replies';
  String get noTickets => 'No tickets';
  String get newTicket => 'New ticket';
  String get subject => 'Subject';
  String get message => 'Message';
  String get priority => 'Priority';
  String get priorityLow => 'Low';
  String get priorityMedium => 'Medium';
  String get priorityHigh => 'High';
  String get submit => 'Submit';
  String get reply => 'Reply';
  String get send => 'Send';
  String get closed => 'Closed';
  String get pendingReply => 'Waiting for support';
  String get loadFailed => 'Failed to load';
  String get retry => 'Retry';
  String get requiredField => 'This field is required';
  String get ticketCreated => 'Ticket submitted';
  String get replySent => 'Reply sent';
  String get me => 'Me';
  String get supportAgent => 'Support';
  String get tutorials => 'Tutorials';
  String get tutorialsDesc => 'Usage and connection guides';
  String get noTutorials => 'No tutorials';
  String get purchase => 'Purchase';
  String get purchaseDesc => 'Plans and orders';
  String get plans => 'Plans';
  String get orders => 'Orders';
  String get noPlans => 'No plans available';
  String get noOrders => 'No orders';
  String get traffic => 'Traffic';
  String get buyNow => 'Buy now';
  String get selectPeriod => 'Select billing period';
  String get confirmOrder => 'Confirm order';
  String get orderDetails => 'Order details';
  String get orderNumber => 'Order number';
  String get plan => 'Plan';
  String get period => 'Period';
  String get status => 'Status';
  String get amount => 'Amount';
  String get createdAt => 'Created at';
  String get paymentMethod => 'Payment method';
  String get continuePayment => 'Continue payment';
  String get payment => 'Payment';
  String get paymentFailed => 'Payment could not start';
  String get noPaymentMethods => 'No payment methods are available';
  String get paymentDataInvalid =>
      'The payment response could not be recognized';
  String get checkPayment => 'Check payment';
  String get paymentPending => 'Payment is still pending';
  String get openExternal => 'Open in browser';
  String get scanOrOpenPayment => 'Complete payment with your payment app';
  String get paymentPageFailed =>
      'The payment page could not be opened securely';
  String get servicesAndAccount => 'Services and account';
  String get tapToExpand => 'Tap to expand';
  String get tapToCollapse => 'Tap to collapse';
  String get refreshSubscription => 'Refresh subscription';
  String get subscriptionUpdated => 'Subscription updated';
}

WhiteLabelStrings whiteLabelStringsOf(BuildContext context) {
  return WhiteLabelStrings(Localizations.localeOf(context));
}
