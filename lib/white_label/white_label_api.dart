import 'dart:convert';
import 'dart:io';

import 'package:bett_box/white_label/white_label_backend_proxy.dart';
import 'package:bett_box/white_label/white_label_config.dart';
import 'package:bett_box/common/common.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';

class WhiteLabelSession {
  final String token;
  final String authData;
  final String email;

  const WhiteLabelSession({
    required this.token,
    required this.authData,
    required this.email,
  });

  bool get isValid => token.isNotEmpty || authData.isNotEmpty;
}

class WhiteLabelSubscription {
  final String subscribeUrl;
  final int upload;
  final int download;
  final int transferEnable;
  final int expiredAt;
  final String email;

  const WhiteLabelSubscription({
    required this.subscribeUrl,
    required this.upload,
    required this.download,
    required this.transferEnable,
    required this.expiredAt,
    required this.email,
  });
}

class WhiteLabelDownloadedConfig {
  final Uint8List bytes;
  final String? contentDisposition;
  final String? subscriptionUserInfo;

  const WhiteLabelDownloadedConfig({
    required this.bytes,
    this.contentDisposition,
    this.subscriptionUserInfo,
  });
}

class WhiteLabelNotice {
  final int id;
  final String title;
  final String content;
  final int createdAt;
  final int updatedAt;

  const WhiteLabelNotice({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
  });
}

class WhiteLabelTicketMessage {
  final int id;
  final String message;
  final bool isMe;
  final int createdAt;

  const WhiteLabelTicketMessage({
    required this.id,
    required this.message,
    required this.isMe,
    required this.createdAt,
  });
}

class WhiteLabelTicket {
  final int id;
  final String subject;
  final int level;
  final int status;
  final int createdAt;
  final int updatedAt;
  final List<WhiteLabelTicketMessage> messages;

  const WhiteLabelTicket({
    required this.id,
    required this.subject,
    required this.level,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.messages = const [],
  });

  bool get isClosed => status != 0;
}

class WhiteLabelKnowledge {
  final int id;
  final String title;
  final String body;
  final String category;
  final int updatedAt;

  const WhiteLabelKnowledge({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.updatedAt,
  });
}

class WhiteLabelPlan {
  final int id;
  final String name;
  final String content;
  final int transferEnable;
  final int speedLimit;
  final Map<String, int> prices;

  const WhiteLabelPlan({
    required this.id,
    required this.name,
    required this.content,
    required this.transferEnable,
    required this.speedLimit,
    required this.prices,
  });
}

class WhiteLabelOrder {
  final String tradeNo;
  final String period;
  final int status;
  final int totalAmount;
  final int balanceAmount;
  final int handlingAmount;
  final int createdAt;
  final int updatedAt;
  final WhiteLabelPlan? plan;

  const WhiteLabelOrder({
    required this.tradeNo,
    required this.period,
    required this.status,
    required this.totalAmount,
    required this.balanceAmount,
    required this.handlingAmount,
    required this.createdAt,
    required this.updatedAt,
    this.plan,
  });
}

class WhiteLabelPaymentMethod {
  final int id;
  final String name;
  final String payment;
  final String icon;

  const WhiteLabelPaymentMethod({
    required this.id,
    required this.name,
    required this.payment,
    required this.icon,
  });
}

class WhiteLabelCheckoutResult {
  final int type;
  final Object? data;

  const WhiteLabelCheckoutResult({required this.type, required this.data});
}

class WhiteLabelApi {
  static const Duration _timeout = Duration(seconds: 20);
  static const String _subscriptionUserAgent =
      'Clash.Meta/ClashMetaForAndroid/5.0';

  static final ValueNotifier<int> authRevision = ValueNotifier<int>(0);
  static final Dio _dio = _createDio();
  static final Dio _proxyDio = _createDio(useBackendProxy: true);

  static void notifyAuthChanged() {
    authRevision.value++;
  }

  static Dio _createDio({bool useBackendProxy = false}) {
    final dio = Dio(
      BaseOptions(
        baseUrl: whiteLabelApiBaseUrl,
        connectTimeout: useBackendProxy ? const Duration(seconds: 8) : _timeout,
        receiveTimeout: useBackendProxy
            ? const Duration(seconds: 30)
            : _timeout,
        sendTimeout: _timeout,
        headers: {'User-Agent': browserUa, 'Accept': 'application/json'},
      ),
    );
    if (useBackendProxy) {
      dio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          final client = HttpClient();
          client.findProxy = (_) =>
              'PROXY ${WhiteLabelBackendProxy.localProxy}';
          return client;
        },
      );
    }
    return dio;
  }

  static Future<WhiteLabelSession?> loadSession() async {
    final prefs = await preferences.sharedPreferencesCompleter.future;
    final token = prefs?.getString(whiteLabelAuthTokenKey) ?? '';
    final authData = prefs?.getString(whiteLabelAuthDataKey) ?? '';
    final email = prefs?.getString(whiteLabelAuthEmailKey) ?? '';
    if (token.isEmpty && authData.isEmpty) return null;
    return WhiteLabelSession(token: token, authData: authData, email: email);
  }

  static Future<void> saveSession(WhiteLabelSession session) async {
    final prefs = await preferences.sharedPreferencesCompleter.future;
    await prefs?.setString(whiteLabelAuthTokenKey, session.token);
    await prefs?.setString(whiteLabelAuthDataKey, session.authData);
    await prefs?.setString(whiteLabelAuthEmailKey, session.email);
  }

  static Future<void> clearSession({bool notify = true}) async {
    final prefs = await preferences.sharedPreferencesCompleter.future;
    await prefs?.remove(whiteLabelAuthTokenKey);
    await prefs?.remove(whiteLabelAuthDataKey);
    await prefs?.remove(whiteLabelAuthEmailKey);
    if (notify) {
      notifyAuthChanged();
    }
  }

  static Future<WhiteLabelSession> login({
    required String email,
    required String password,
  }) async {
    final response = await _post(
      '/passport/auth/login',
      data: {'email': email, 'password': password},
    );
    final data = _payloadData(response.data);
    final token = data['token']?.toString() ?? '';
    final authData = data['auth_data']?.toString() ?? '';
    if (token.isEmpty && authData.isEmpty) {
      throw 'Login succeeded but no token was returned.';
    }
    final session = WhiteLabelSession(
      token: token,
      authData: authData,
      email: email,
    );
    await saveSession(session);
    return session;
  }

  static Future<WhiteLabelSubscription> fetchSubscription(
    WhiteLabelSession session,
  ) async {
    final response = await _authenticatedRequest(
      session,
      'GET',
      '/user/getSubscribe',
    );
    return _parseSubscription(response.data);
  }

  static Future<List<WhiteLabelNotice>> fetchNotices(
    WhiteLabelSession session,
  ) async {
    final response = await _authenticatedRequest(
      session,
      'GET',
      '/user/notice/fetch',
    );
    final data = _payloadValue(response.data);
    final list = _listValue(data);
    return list
        .whereType<Map>()
        .map((item) => _parseNotice(Map<String, dynamic>.from(item)))
        .toList();
  }

  static Future<List<WhiteLabelKnowledge>> fetchKnowledge(
    WhiteLabelSession session,
    String language,
  ) async {
    final response = await _authenticatedRequest(
      session,
      'GET',
      '/user/knowledge/fetch',
      queryParameters: {'language': language},
    );
    final data = _payloadValue(response.data);
    final list = _flattenKnowledge(data);
    return list
        .whereType<Map>()
        .map((item) => _parseKnowledge(Map<String, dynamic>.from(item)))
        .toList();
  }

  static Future<WhiteLabelKnowledge> fetchKnowledgeDetail(
    WhiteLabelSession session,
    int id,
  ) async {
    final response = await _authenticatedRequest(
      session,
      'GET',
      '/user/knowledge/fetch',
      queryParameters: {'id': id},
    );
    final data = _payloadValue(response.data);
    if (data is! Map) throw 'Unexpected knowledge response.';
    return _parseKnowledge(Map<String, dynamic>.from(data));
  }

  static Future<List<WhiteLabelPlan>> fetchPlans(
    WhiteLabelSession session,
  ) async {
    final response = await _authenticatedRequest(
      session,
      'GET',
      '/user/plan/fetch',
    );
    final data = _payloadValue(response.data);
    final list = _listValue(data);
    return list
        .whereType<Map>()
        .map((item) => _parsePlan(Map<String, dynamic>.from(item)))
        .toList();
  }

  static Future<List<WhiteLabelOrder>> fetchOrders(
    WhiteLabelSession session,
  ) async {
    final response = await _authenticatedRequest(
      session,
      'GET',
      '/user/order/fetch',
    );
    final data = _payloadValue(response.data);
    final list = _listValue(data);
    return list
        .whereType<Map>()
        .map((item) => _parseOrder(Map<String, dynamic>.from(item)))
        .toList();
  }

  static Future<WhiteLabelOrder> fetchOrder(
    WhiteLabelSession session,
    String tradeNo,
  ) async {
    final response = await _authenticatedRequest(
      session,
      'GET',
      '/user/order/detail',
      queryParameters: {'trade_no': tradeNo},
    );
    final data = _payloadValue(response.data);
    if (data is! Map) throw 'Unexpected order response.';
    return _parseOrder(Map<String, dynamic>.from(data));
  }

  static Future<String> createOrder(
    WhiteLabelSession session, {
    required int planId,
    required String period,
  }) async {
    debugPrint('WhiteLabelOrder: save plan=$planId period=$period');
    final response = await _authenticatedRequest(
      session,
      'POST',
      '/user/order/save',
      data: {'plan_id': planId, 'period': period},
    );
    final data = _payloadValue(response.data);
    final tradeNo = data is Map
        ? (data['trade_no'] ?? data['tradeNo'])?.toString() ?? ''
        : data?.toString() ?? '';
    debugPrint(
      'WhiteLabelOrder: save response=${_debugShape(data)} tradeNo=${_maskTradeNo(tradeNo)}',
    );
    if (tradeNo.isEmpty) throw 'No order number was returned.';
    return tradeNo;
  }

  static Future<List<WhiteLabelPaymentMethod>> fetchPaymentMethods(
    WhiteLabelSession session,
  ) async {
    final response = await _authenticatedRequest(
      session,
      'GET',
      '/user/order/getPaymentMethod',
    );
    final data = _payloadValue(response.data);
    final list = _listValue(data);
    return list.whereType<Map>().map((item) {
      final map = Map<String, dynamic>.from(item);
      return WhiteLabelPaymentMethod(
        id: _toInt(map['id']),
        name: map['name']?.toString() ?? '',
        payment: map['payment']?.toString() ?? '',
        icon: map['icon']?.toString() ?? '',
      );
    }).toList();
  }

  static Future<WhiteLabelCheckoutResult> checkoutOrder(
    WhiteLabelSession session, {
    required String tradeNo,
    required int method,
  }) async {
    debugPrint(
      'WhiteLabelOrder: checkout tradeNo=${_maskTradeNo(tradeNo)} method=$method',
    );
    final response = await _authenticatedRequest(
      session,
      'POST',
      '/user/order/checkout',
      data: {'trade_no': tradeNo, 'method': method},
    );
    final raw = _payloadValue(response.data);
    final body = raw is Map
        ? Map<String, dynamic>.from(raw)
        : _toMap(response.data);
    debugPrint(
      'WhiteLabelOrder: checkout response type=${body['type']} data=${_debugShape(body['data'])}',
    );
    return WhiteLabelCheckoutResult(
      type: _toInt(body['type']),
      data: body['data'],
    );
  }

  static Future<int> checkOrder(
    WhiteLabelSession session,
    String tradeNo,
  ) async {
    final response = await _authenticatedRequest(
      session,
      'GET',
      '/user/order/check',
      queryParameters: {'trade_no': tradeNo},
    );
    return _toInt(_payloadValue(response.data));
  }

  static Future<void> cancelOrder(
    WhiteLabelSession session,
    String tradeNo,
  ) async {
    await _authenticatedRequest(
      session,
      'POST',
      '/user/order/cancel',
      data: {'trade_no': tradeNo},
    );
  }

  static Future<List<WhiteLabelTicket>> fetchTickets(
    WhiteLabelSession session,
  ) async {
    final response = await _authenticatedRequest(
      session,
      'GET',
      '/user/ticket/fetch',
    );
    final data = _payloadValue(response.data);
    final list = data is List ? data : const [];
    return list
        .whereType<Map>()
        .map((item) => _parseTicket(Map<String, dynamic>.from(item)))
        .toList();
  }

  static Future<WhiteLabelTicket> fetchTicket(
    WhiteLabelSession session,
    int id,
  ) async {
    final response = await _authenticatedRequest(
      session,
      'GET',
      '/user/ticket/fetch',
      queryParameters: {'id': id},
    );
    final data = _payloadValue(response.data);
    if (data is! Map) throw 'Unexpected ticket response.';
    return _parseTicket(Map<String, dynamic>.from(data));
  }

  static Future<void> createTicket(
    WhiteLabelSession session, {
    required String subject,
    required int level,
    required String message,
  }) async {
    await _authenticatedRequest(
      session,
      'POST',
      '/user/ticket/save',
      data: {'subject': subject, 'level': level, 'message': message},
    );
  }

  static Future<void> replyTicket(
    WhiteLabelSession session, {
    required int id,
    required String message,
  }) async {
    await _authenticatedRequest(
      session,
      'POST',
      '/user/ticket/reply',
      data: {'id': id, 'message': message},
    );
  }

  static Future<void> closeTicket(WhiteLabelSession session, int id) async {
    await _authenticatedRequest(
      session,
      'POST',
      '/user/ticket/close',
      data: {'id': id},
    );
  }

  static Future<WhiteLabelDownloadedConfig> downloadConfig(String url) async {
    final response = await _withBackendProxyFirst(
      () => _getBytes(_proxyDio, url),
      () => _getBytes(_dio, url),
    );
    final data = response.data;
    if (data == null) {
      throw 'Empty subscription response.';
    }
    return WhiteLabelDownloadedConfig(
      bytes: Uint8List.fromList(data),
      contentDisposition: response.headers.value('content-disposition'),
      subscriptionUserInfo: response.headers.value('subscription-userinfo'),
    );
  }

  static Future<Response<T>> _get<T>(
    String path, {
    Options? options,
    Map<String, dynamic>? queryParameters,
  }) async {
    _ensureApiConfigured();
    return _withBackendProxyFirst(
      () => _proxyDio.get<T>(
        path,
        options: options,
        queryParameters: queryParameters,
      ),
      () =>
          _dio.get<T>(path, options: options, queryParameters: queryParameters),
    );
  }

  static Future<Response<T>> _post<T>(
    String path, {
    Object? data,
    Options? options,
  }) async {
    _ensureApiConfigured();
    return _withBackendProxyFirst(
      () => _proxyDio.post<T>(path, data: data, options: options),
      () => _dio.post<T>(path, data: data, options: options),
    );
  }

  static void _ensureApiConfigured() {
    if (whiteLabelApiBaseUrl.trim().isEmpty) {
      throw 'V2BOARD_PANEL_URL or V2BOARD_API_BASE_URL is not configured.';
    }
  }

  static List<Map<String, String>> _authCandidates(WhiteLabelSession session) {
    return [
      if (session.token.isNotEmpty) {'Authorization': session.token},
      if (session.token.isNotEmpty)
        {'Authorization': 'Bearer ${session.token}'},
      if (session.authData.isNotEmpty) {'Authorization': session.authData},
      if (session.authData.isNotEmpty)
        {'Authorization': 'Bearer ${session.authData}'},
    ];
  }

  static Future<Response<dynamic>> _authenticatedRequest(
    WhiteLabelSession session,
    String method,
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) async {
    Object? lastError;
    for (final headers in _authCandidates(session)) {
      try {
        final options = Options(headers: headers);
        if (method == 'POST') {
          return await _post(path, data: data, options: options);
        }
        return await _get(
          path,
          options: options,
          queryParameters: queryParameters,
        );
      } catch (error) {
        lastError = error;
        if (error is DioException) {
          final statusCode = error.response?.statusCode;
          if (statusCode != 401 && statusCode != 403) {
            throw _readableError(error);
          }
        }
      }
    }
    if (lastError is DioException) throw _readableError(lastError);
    throw lastError ?? 'Authentication failed.';
  }

  static String _readableError(DioException error) {
    final raw = error.response?.data;
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      final message =
          map['message'] ?? map['error'] ?? map['data'] ?? map['errors'];
      if (message != null && message.toString().isNotEmpty) {
        return message.toString();
      }
    }
    if (raw is String && raw.trim().isNotEmpty) return raw.trim();
    return error.message ?? 'Request failed.';
  }

  static Future<Response<List<int>>> _getBytes(Dio dio, String url) {
    String? userInfo;
    String requestUrl = url;

    if (url.startsWith('http://') || url.startsWith('https://')) {
      final schemeEnd = url.indexOf('://') + 3;
      final atIndex = url.indexOf('@', schemeEnd);
      if (atIndex != -1) {
        final slashIndex = url.indexOf('/', schemeEnd);
        if (slashIndex == -1 || atIndex < slashIndex) {
          userInfo = url.substring(schemeEnd, atIndex);
          requestUrl = url.substring(0, schemeEnd) + url.substring(atIndex + 1);
        }
      }
    }

    final headers = <String, String>{
      'User-Agent': _subscriptionUserAgent,
      'Accept': 'text/yaml, application/yaml, text/plain, */*',
    };
    if (userInfo != null && userInfo.isNotEmpty) {
      final auth = base64Encode(utf8.encode(userInfo));
      headers['Authorization'] = 'Basic $auth';
    }

    final options = Options(responseType: ResponseType.bytes, headers: headers);
    return dio.get<List<int>>(requestUrl, options: options);
  }

  static Future<Response<T>> _withBackendProxyFirst<T>(
    Future<Response<T>> Function() proxied,
    Future<Response<T>> Function() direct,
  ) async {
    try {
      final started = await WhiteLabelBackendProxy.ensureStarted();
      if (started) {
        return await proxied();
      }
    } catch (e) {
      if (!_shouldTryDirect(e)) {
        rethrow;
      }
    }
    return direct();
  }

  static bool _shouldTryDirect(Object error) {
    if (error is! DioException) {
      return false;
    }
    if (error.response == null) {
      return true;
    }
    final statusCode = error.response?.statusCode ?? 0;
    return statusCode == 502 || statusCode == 503 || statusCode == 504;
  }

  static Map<String, dynamic> _payloadData(Object? raw) {
    final body = _toMap(raw);
    final data = body['data'];
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return body;
  }

  static Object? _payloadValue(Object? raw) {
    final body = _toMap(raw);
    return body.containsKey('data') ? body['data'] : body;
  }

  static String _debugShape(Object? value) {
    if (value == null) return 'null';
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
        return 'url(${_debugUrl(trimmed)})';
      }
      if (trimmed.startsWith('<')) return 'html(length=${trimmed.length})';
      return 'string(length=${trimmed.length})';
    }
    if (value is Map) return 'map(keys=${value.keys.join(',')})';
    if (value is List) return 'list(length=${value.length})';
    return value.runtimeType.toString();
  }

  static String _debugUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return 'invalid';
    final keys = uri.queryParametersAll.keys.join(',');
    return '${uri.scheme}://${uri.host}${uri.path}${keys.isEmpty ? '' : '?keys=$keys'}';
  }

  static String _maskTradeNo(String value) {
    if (value.length <= 8) return value;
    return '${value.substring(0, 4)}...${value.substring(value.length - 4)}';
  }

  static List<dynamic> _listValue(Object? value) {
    if (value is List) return value;
    if (value is Map) {
      for (final key in ['data', 'items', 'list']) {
        final nested = value[key];
        if (nested is List) return nested;
      }
    }
    return const [];
  }

  static List<dynamic> _flattenKnowledge(Object? value) {
    if (value is Map &&
        !value.containsKey('data') &&
        !value.containsKey('items') &&
        !value.containsKey('list')) {
      final result = <dynamic>[];
      for (final entry in value.entries) {
        final children = entry.value;
        if (children is! List) continue;
        for (final child in children.whereType<Map>()) {
          result.add({
            ...Map<String, dynamic>.from(child),
            'category': child['category'] ?? entry.key.toString(),
          });
        }
      }
      return result;
    }
    final direct = _listValue(value);
    final result = <dynamic>[];
    for (final item in direct) {
      if (item is! Map) continue;
      final children =
          item['knowledge'] ?? item['children'] ?? item['articles'];
      if (children is List) {
        for (final child in children.whereType<Map>()) {
          result.add({
            ...Map<String, dynamic>.from(child),
            'category': child['category'] ?? item['name'] ?? item['title'],
          });
        }
      } else {
        result.add(item);
      }
    }
    return result;
  }

  static WhiteLabelNotice _parseNotice(Map<String, dynamic> data) {
    return WhiteLabelNotice(
      id: _toInt(data['id']),
      title: data['title']?.toString() ?? '',
      content: data['content']?.toString() ?? '',
      createdAt: _toInt(data['created_at']),
      updatedAt: _toInt(data['updated_at']),
    );
  }

  static WhiteLabelKnowledge _parseKnowledge(Map<String, dynamic> data) {
    final category = data['category'];
    return WhiteLabelKnowledge(
      id: _toInt(data['id']),
      title: data['title']?.toString() ?? '',
      body:
          (data['body'] ?? data['content'] ?? data['description'])
              ?.toString() ??
          '',
      category: category is Map
          ? (category['name']?.toString() ?? '')
          : category?.toString() ?? '',
      updatedAt: _toInt(data['updated_at'] ?? data['created_at']),
    );
  }

  static WhiteLabelPlan _parsePlan(Map<String, dynamic> data) {
    const periodKeys = [
      'month_price',
      'monthly_price',
      'quarter_price',
      'quarterly_price',
      'half_year_price',
      'year_price',
      'two_year_price',
      'three_year_price',
      'onetime_price',
      'reset_price',
    ];
    final prices = <String, int>{};
    for (final key in periodKeys) {
      if (data[key] != null) prices[key] = _toInt(data[key]);
    }
    if (!prices.containsKey('month_price') &&
        prices.containsKey('monthly_price')) {
      prices['month_price'] = prices['monthly_price']!;
    }
    prices.remove('monthly_price');
    return WhiteLabelPlan(
      id: _toInt(data['id']),
      name: data['name']?.toString() ?? '',
      content: data['content']?.toString() ?? '',
      transferEnable: _toInt(data['transfer_enable']),
      speedLimit: _toInt(data['speed_limit']),
      prices: prices,
    );
  }

  static WhiteLabelOrder _parseOrder(Map<String, dynamic> data) {
    final planData = data['plan'];
    return WhiteLabelOrder(
      tradeNo: data['trade_no']?.toString() ?? '',
      period: data['period']?.toString() ?? '',
      status: _toInt(data['status']),
      totalAmount: _toInt(data['total_amount']),
      balanceAmount: _toInt(data['balance_amount']),
      handlingAmount: _toInt(data['handling_amount']),
      createdAt: _toInt(data['created_at']),
      updatedAt: _toInt(data['updated_at']),
      plan: planData is Map
          ? _parsePlan(Map<String, dynamic>.from(planData))
          : null,
    );
  }

  static WhiteLabelTicket _parseTicket(Map<String, dynamic> data) {
    final rawMessages = data['message'] ?? data['messages'];
    final messages = rawMessages is List
        ? rawMessages
              .whereType<Map>()
              .map(
                (item) => _parseTicketMessage(
                  Map<String, dynamic>.from(item),
                  ticketUserId: _toInt(data['user_id']),
                ),
              )
              .toList()
        : const <WhiteLabelTicketMessage>[];
    return WhiteLabelTicket(
      id: _toInt(data['id']),
      subject: data['subject']?.toString() ?? '',
      level: _toInt(data['level']),
      status: _toInt(data['status']),
      createdAt: _toInt(data['created_at']),
      updatedAt: _toInt(data['updated_at']),
      messages: messages,
    );
  }

  static WhiteLabelTicketMessage _parseTicketMessage(
    Map<String, dynamic> data, {
    required int ticketUserId,
  }) {
    final rawIsMe = data['is_me'];
    final isMe = rawIsMe is bool
        ? rawIsMe
        : rawIsMe != null
        ? _toInt(rawIsMe) == 1
        : _toInt(data['user_id']) == ticketUserId;
    return WhiteLabelTicketMessage(
      id: _toInt(data['id']),
      message: data['message']?.toString() ?? '',
      isMe: isMe,
      createdAt: _toInt(data['created_at']),
    );
  }

  static WhiteLabelSubscription _parseSubscription(Object? raw) {
    final data = _payloadData(raw);
    final subscribeUrl = data['subscribe_url']?.toString() ?? '';
    if (subscribeUrl.isEmpty) {
      throw 'No subscription is available for this account.';
    }
    return WhiteLabelSubscription(
      subscribeUrl: subscribeUrl,
      upload: _toInt(data['u']),
      download: _toInt(data['d']),
      transferEnable: _toInt(data['transfer_enable']),
      expiredAt: _toInt(data['expired_at']),
      email: data['email']?.toString() ?? '',
    );
  }

  static Map<String, dynamic> _toMap(Object? raw) {
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is String && raw.isNotEmpty) {
      final decoded = json.decode(raw);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    }
    throw 'Unexpected API response.';
  }

  static int _toInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
