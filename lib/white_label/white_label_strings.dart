import 'package:bett_box/white_label/white_label_config.dart';
import 'package:flutter/widgets.dart';

class WhiteLabelStrings {
  final Locale locale;

  const WhiteLabelStrings(this.locale);

  bool get _isZh => locale.languageCode == 'zh';
  bool get _isTraditional =>
      locale.scriptCode == 'Hant' ||
      locale.countryCode == 'TW' ||
      locale.countryCode == 'HK' ||
      locale.countryCode == 'MO';

  String _t(String simplified, String traditional, String english) {
    if (!_isZh) return english;
    return _isTraditional ? traditional : simplified;
  }

  String get website => _t('官网', '官網', 'Website');
  String get support => _t('客服', '客服', 'Support');
  String get onlineSupport => _t('在线客服', '線上客服', 'Online support');
  String get signedIn => _t('已登录', '已登入', 'Signed in');
  String get userData => _t('用户数据', '用戶資料', 'User data');
  String get expires => _t('到期时间', '到期時間', 'Expires');
  String get noPlanData => _t('暂无套餐数据', '暫無方案資料', 'No plan data');
  String get unlimited => _t('不限量', '不限量', 'Unlimited');
  String get never => _t('永久', '永久', 'Never');
  String get signOut => _t('退出登录', '登出', 'Sign out');
  String get signOutDesc =>
      _t('清除此账号和订阅', '清除此帳號和訂閱', 'Clear this account and subscription');
  String get logoutFailed => _t('退出失败', '登出失敗', 'Logout failed');
  String get aboutDesc => _t(
    '$whiteLabelDisplayName 基于 Mihomo 代理内核，致力于更好的体验。',
    '$whiteLabelDisplayName 基於 Mihomo 代理核心，致力於更好的體驗。',
    '$whiteLabelDisplayName is based on the Mihomo proxy core and built for a better experience.',
  );

  String get announcements => _t('公告', '公告', 'Announcements');
  String get announcementsDesc => _t('服务公告', '服務公告', 'Service notices');
  String get noAnnouncements => _t('暂无公告', '暫無公告', 'No announcements');
  String get tickets => _t('工单', '工單', 'Tickets');
  String get ticketsDesc => _t('问题与回复', '問題與回覆', 'Questions and replies');
  String get noTickets => _t('暂无工单', '暫無工單', 'No tickets');
  String get newTicket => _t('新建工单', '新增工單', 'New ticket');
  String get subject => _t('主题', '主題', 'Subject');
  String get message => _t('内容', '內容', 'Message');
  String get priority => _t('优先级', '優先級', 'Priority');
  String get priorityLow => _t('低', '低', 'Low');
  String get priorityMedium => _t('中', '中', 'Medium');
  String get priorityHigh => _t('高', '高', 'High');
  String get submit => _t('提交', '提交', 'Submit');
  String get reply => _t('回复', '回覆', 'Reply');
  String get send => _t('发送', '傳送', 'Send');
  String get closed => _t('已关闭', '已關閉', 'Closed');
  String get pendingReply => _t('等待客服回复', '等待客服回覆', 'Waiting for support');
  String get loadFailed => _t('加载失败', '載入失敗', 'Failed to load');
  String get retry => _t('重试', '重試', 'Retry');
  String get requiredField => _t('此项不能为空', '此欄位不可為空', 'This field is required');
  String get ticketCreated => _t('工单已提交', '工單已提交', 'Ticket submitted');
  String get replySent => _t('回复已发送', '回覆已傳送', 'Reply sent');
  String get me => _t('我', '我', 'Me');
  String get supportAgent => _t('客服', '客服', 'Support');
  String get tutorials => _t('教程', '教學', 'Tutorials');
  String get tutorialsDesc =>
      _t('使用与连接教程', '使用與連線教學', 'Usage and connection guides');
  String get noTutorials => _t('暂无教程', '暫無教學', 'No tutorials');
  String get purchase => _t('购买', '購買', 'Purchase');
  String get purchaseDesc => _t('套餐与订单', '方案與訂單', 'Plans and orders');
  String get plans => _t('套餐', '方案', 'Plans');
  String get orders => _t('订单', '訂單', 'Orders');
  String get noPlans => _t('暂无可购买套餐', '暫無可購買方案', 'No plans available');
  String get noOrders => _t('暂无订单', '暫無訂單', 'No orders');
  String get traffic => _t('流量', '流量', 'Traffic');
  String get buyNow => _t('立即购买', '立即購買', 'Buy now');
  String get selectPeriod => _t('选择订阅周期', '選擇訂閱週期', 'Select billing period');
  String get confirmOrder => _t('确认订单', '確認訂單', 'Confirm order');
  String get orderDetails => _t('订单详情', '訂單詳情', 'Order details');
  String get orderNumber => _t('订单号', '訂單號', 'Order number');
  String get plan => _t('套餐', '方案', 'Plan');
  String get period => _t('周期', '週期', 'Period');
  String get status => _t('状态', '狀態', 'Status');
  String get amount => _t('金额', '金額', 'Amount');
  String get createdAt => _t('创建时间', '建立時間', 'Created at');
  String get paymentMethod => _t('支付方式', '付款方式', 'Payment method');
  String get continuePayment => _t('继续支付', '繼續付款', 'Continue payment');
  String get payment => _t('支付', '付款', 'Payment');
  String get paymentFailed => _t('支付未能启动', '付款未能啟動', 'Payment could not start');
  String get noPaymentMethods =>
      _t('暂无可用支付方式', '暫無可用付款方式', 'No payment methods are available');
  String get paymentDataInvalid => _t(
    '无法识别支付响应',
    '無法識別付款回應',
    'The payment response could not be recognized',
  );
  String get checkPayment => _t('检查支付状态', '檢查付款狀態', 'Check payment');
  String get paymentPending =>
      _t('支付仍在处理中', '付款仍在處理中', 'Payment is still pending');
  String get openExternal => _t('用浏览器打开', '用瀏覽器開啟', 'Open in browser');
  String get scanOrOpenPayment => _t(
    '请使用支付应用完成支付',
    '請使用付款應用完成付款',
    'Complete payment with your payment app',
  );
  String get paymentPageFailed => _t(
    '支付页面无法安全打开',
    '付款頁面無法安全開啟',
    'The payment page could not be opened securely',
  );
  String get paymentAppMissing => _t(
    '无法打开支付应用，请确认已安装微信或支付宝。',
    '無法開啟付款應用，請確認已安裝微信或支付寶。',
    'Could not open the payment app. Please make sure it is installed.',
  );
  String get servicesAndAccount => _t('服务与账号', '服務與帳號', 'Services and account');
  String get tapToExpand => _t('点击展开', '點擊展開', 'Tap to expand');
  String get tapToCollapse => _t('点击收起', '點擊收起', 'Tap to collapse');
  String get refreshSubscription =>
      _t('刷新订阅', '重新整理訂閱', 'Refresh subscription');
  String get subscriptionUpdated =>
      _t('订阅已更新', '訂閱已更新', 'Subscription updated');
  String get allPlans => _t('全部套餐', '全部方案', 'All plans');
  String get byPeriod => _t('按周期', '按週期', 'By period');
  String get byTraffic => _t('按流量', '按流量', 'By traffic');
  String get monthly => _t('月付', '月付', 'Monthly');
  String get yearly => _t('年付', '年付', 'Yearly');
  String get quarterly => _t('季付', '季付', 'Quarterly');
  String get halfYear => _t('半年付', '半年付', 'Half-year');
  String get twoYears => _t('两年付', '兩年付', 'Two years');
  String get threeYears => _t('三年付', '三年付', 'Three years');
  String get oneTime => _t('一次性', '一次性', 'One-time');
  String get resetTraffic => _t('重置流量', '重置流量', 'Reset traffic');
  String get subscribe => _t('订阅', '訂閱', 'Subscribe');
  String get featured => _t('招牌', '招牌', 'Featured');
  String get popular => _t('实惠', '實惠', 'Popular');
  String get value => _t('超值', '超值', 'Value');
  String get recommended => _t('推荐', '推薦', 'Recommended');
  String get statusPending => _t('待支付', '待付款', 'Pending');
  String get statusCompleted => _t('已完成', '已完成', 'Completed');
  String get statusCancelled => _t('已取消', '已取消', 'Cancelled');
  String get statusClosed => _t('已关闭', '已關閉', 'Closed');
  String get statusProcessing => _t('处理中', '處理中', 'Processing');
  String get cancelOrder => _t('取消订单', '取消訂單', 'Cancel order');
  String get cancelOrderConfirm =>
      _t('确定取消这个待支付订单吗？', '確定取消這個待付款訂單嗎？', 'Cancel this pending order?');
  String get confirm => _t('确认', '確認', 'Confirm');
  String get orderCancelled => _t('订单已取消', '訂單已取消', 'Order cancelled');
  String get viewImage => _t('查看图片', '查看圖片', 'View image');
}

WhiteLabelStrings whiteLabelStringsOf(BuildContext context) {
  return WhiteLabelStrings(Localizations.localeOf(context));
}
