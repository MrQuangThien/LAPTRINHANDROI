import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../core/config/app_config.dart';
import '../../core/utils/api_error.dart';
import '../../core/widgets/app_chrome.dart';
import '../../models/product.dart';
import '../../providers/session_state.dart';
import '../../services/app_services.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});
  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  int _tab = 0;
  bool _loadingMenu = true;
  bool _loadingInfo = true;
  bool _busy = false;
  String? _error;
  List<Product> _products = [];
  List<Map<String, dynamic>> _categories = [];
  int? _categoryId;
  int _menuPage = 1;
  static const int _menuPageSize = 8;
  int _menuTotalCount = 0;
  List<Product> _homeProducts = [];
  int _homePage = 1;
  static const int _homePageSize = 4;
  int _homeTotalCount = 0;
  bool _loadingHomeProducts = false;
  final Map<int, Product> _cart = {};
  final Map<int, int> _quantities = {};
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _note = TextEditingController();
  final _tracking = TextEditingController();
  final _reservationCode = TextEditingController();
  final _menuSearch = TextEditingController();
  String? _pendingOrderCode;
  int? _reservationTableId;
  int _partySize = 2;
  DateTime _bookingTime = DateTime.now().add(const Duration(hours: 2));
  int? _bookingTableId;
  List<Map<String, dynamic>> _bookingTables = [];
  Map<String, dynamic>? _trackedOrder;
  Map<String, dynamic>? _invoice;
  Map<String, dynamic>? _restaurantInfo;
  List<Map<String, dynamic>> _blogs = [];
  String? _blogCategory;
  List<Map<String, dynamic>> _myOrders = [];
  List<Map<String, dynamic>> _myReservations = [];

  final _money = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: '₫',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _loadMenu();
    _loadHomeProducts();
    _loadSavedTrackingCode();
    _loadBookingTables();
    _loadInfoAndBlogs();
    _loadAccountActivity();
  }

  Future<void> _loadInfoAndBlogs() async {
    setState(() => _loadingInfo = true);
    try {
      final results = await Future.wait([
        apiClient.dio.get('/api/customer/info'),
        apiClient.dio.get(
          '/api/customer/blogs',
          queryParameters: {if (_blogCategory != null) 'category': _blogCategory},
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _restaurantInfo = Map<String, dynamic>.from(results[0].data as Map);
        _blogs = (results[1].data as List)
            .map((x) => Map<String, dynamic>.from(x as Map))
            .toList();
        _loadingInfo = false;
      });
    } on DioException {
      if (mounted) setState(() => _loadingInfo = false);
    }
  }

  Future<void> _loadAccountActivity() async {
    if (sessionState.user == null) {
      if (mounted) {
        setState(() {
          _myOrders = [];
          _myReservations = [];
        });
      }
      return;
    }
    try {
      final r = await apiClient.dio.get('/api/customer/my-activity');
      final data = Map<String, dynamic>.from(r.data as Map);
      if (!mounted) return;
      setState(() {
        if (_name.text.trim().isEmpty && data['fullName'] != null) {
          _name.text = '${data['fullName']}';
        }
        if (_phone.text.trim().isEmpty && data['phone'] != null) {
          _phone.text = '${data['phone']}';
        }
        _myOrders = (data['orders'] as List? ?? [])
            .map((x) => Map<String, dynamic>.from(x as Map))
            .toList();
        _myReservations = (data['reservations'] as List? ?? [])
            .map((x) => Map<String, dynamic>.from(x as Map))
            .toList();
      });
      if (_trackedOrder == null && _myOrders.isNotEmpty) {
        final firstCode =
            _myOrders.first['orderCode'] ?? _myOrders.first['clientRequestId'];
        if (firstCode != null && '$firstCode'.trim().isNotEmpty) {
          _tracking.text = '$firstCode';
          await _trackOrder();
        }
      }
    } on DioException {
      // Ignore if session expired or guest mode.
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _note.dispose();
    _tracking.dispose();
    _reservationCode.dispose();
    _menuSearch.dispose();
    super.dispose();
  }

  Future<void> _loadMenu() async {
    setState(() {
      _loadingMenu = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        apiClient.dio.get(
          '/api/categories',
          queryParameters: {'pageNumber': 1, 'pageSize': 100},
        ),
        apiClient.dio.get(
          '/api/products',
          queryParameters: {
            'pageNumber': _menuPage,
            'pageSize': _menuPageSize,
            if (_categoryId != null) 'categoryId': _categoryId,
            if (_menuSearch.text.trim().isNotEmpty)
              'search': _menuSearch.text.trim(),
          },
        ),
      ]);
      if (!mounted) return;
      final total = (results[1].data['totalCount'] as num?)?.toInt() ?? 0;
      setState(() {
        _categories = (results[0].data['items'] as List)
            .map((x) => Map<String, dynamic>.from(x as Map))
            .where((x) => x['isActive'] == true)
            .toList();
        _products = (results[1].data['items'] as List)
            .map((x) => Product.fromJson(Map<String, dynamic>.from(x as Map)))
            .where((p) => p.available)
            .toList();
        _menuTotalCount = total;
        _loadingMenu = false;
      });
    } on DioException catch (e) {
      if (mounted) {
        setState(() {
          _error = apiError(e);
          _loadingMenu = false;
        });
      }
    }
  }

  Future<void> _loadHomeProducts() async {
    setState(() => _loadingHomeProducts = true);
    try {
      final res = await apiClient.dio.get(
        '/api/products',
        queryParameters: {
          'pageNumber': _homePage,
          'pageSize': _homePageSize,
          'sortBy': 'newest',
        },
      );
      if (!mounted) return;
      setState(() {
        _homeProducts = (res.data['items'] as List)
            .map((x) => Product.fromJson(Map<String, dynamic>.from(x as Map)))
            .where((p) => p.available)
            .toList();
        _homeTotalCount = (res.data['totalCount'] as num?)?.toInt() ?? 0;
        _loadingHomeProducts = false;
      });
    } on DioException {
      if (mounted) setState(() => _loadingHomeProducts = false);
    }
  }

  Future<void> _loadBookingTables() async {
    try {
      final response = await apiClient.dio.get(
        '/api/customer/tables',
        queryParameters: {
          'startsAt': _bookingTime.toUtc().toIso8601String(),
          'partySize': _partySize,
        },
      );
      if (!mounted) return;
      final rows = (response.data as List)
          .map((x) => Map<String, dynamic>.from(x as Map))
          .where((t) => ((t['capacity'] as num?)?.toInt() ?? 0) >= _partySize)
          .toList();
      setState(() {
        _bookingTables = rows;
        if (!rows.any((t) => t['id'] == _bookingTableId)) {
          _bookingTableId = rows.isEmpty ? null : rows.first['id'] as int;
        }
      });
    } on DioException catch (e) {
      if (mounted) _message(apiError(e));
    }
  }

  Future<void> _loadSavedTrackingCode() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString('customer_last_tracking_code');
    final reservationCode = prefs.getString('customer_reservation_code');
    final reservationTableId = prefs.getInt('customer_reservation_table_id');
    final reservationPartySize = prefs.getInt(
      'customer_reservation_party_size',
    );
    if (mounted && code != null) _tracking.text = code;
    if (mounted && reservationCode != null) {
      setState(() {
        _reservationCode.text = reservationCode;
        _reservationTableId = reservationTableId;
        if (reservationPartySize != null) _partySize = reservationPartySize;
      });
    }
  }

  void _message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  bool _requireAuth(String actionLabel) {
    if (sessionState.user != null) return true;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.lock_person_outlined,
          size: 40,
          color: AppColors.primary,
        ),
        title: const Text('Yêu cầu đăng nhập'),
        content: Text(
          'Bạn cần đăng nhập tài khoản trước khi $actionLabel.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Để sau'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.go('/login');
            },
            icon: const Icon(Icons.login_rounded, size: 18),
            label: const Text('Đăng nhập ngay'),
          ),
        ],
      ),
    );
    return false;
  }

  Future<void> _add(Product product) async {
    if (!_requireAuth('order món')) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận thêm món'),
        content: Text(
          'Bạn có chắc muốn thêm "${product.name}" (${_money.format(product.price)}) vào giỏ hàng không?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Thêm vào giỏ'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    _pendingOrderCode = null;
    setState(() {
      _cart[product.id] = product;
      _quantities.update(product.id, (value) => value + 1, ifAbsent: () => 1);
    });
    _message('Đã thêm ${product.name} vào giỏ hàng.');
  }

  void _changeQuantity(int id, int value) {
    _pendingOrderCode = null;
    setState(() {
      if (value <= 0) {
        _quantities.remove(id);
        _cart.remove(id);
      } else {
        _quantities[id] = value;
      }
    });
  }

  double get _cartTotal => _quantities.entries.fold(
    0,
    (sum, entry) => sum + (_cart[entry.key]?.price ?? 0) * entry.value,
  );

  Future<void> _bookTable() async {
    if (!_requireAuth('đặt bàn')) return;
    if (_name.text.trim().length < 2 ||
        _phone.text.trim().length < 7 ||
        _bookingTableId == null) {
      _message('Nhập tên, số điện thoại hợp lệ và chọn bàn trước khi đặt.');
      return;
    }
    final selectedTable = _bookingTables
        .where((t) => t['id'] == _bookingTableId)
        .firstOrNull;
    if (selectedTable != null &&
        ((selectedTable['capacity'] as num?)?.toInt() ?? 0) < _partySize) {
      _message('Bàn đã chọn không đủ chỗ cho số lượng khách này.');
      return;
    }
    setState(() => _busy = true);
    try {
      final response = await apiClient.dio.post(
        '/api/customer/reservations',
        data: {
          'tableId': _bookingTableId,
          'customerName': _name.text.trim(),
          'customerPhone': _phone.text.trim(),
          'partySize': _partySize,
          'startsAt': _bookingTime.toUtc().toIso8601String(),
          'note': _note.text.trim(),
        },
      );
      final data = Map<String, dynamic>.from(response.data as Map);
      final reservationCode = data['reservationCode'].toString();
      _reservationCode.text = reservationCode;
      _reservationTableId = _bookingTableId;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('customer_reservation_code', reservationCode);
      if (_bookingTableId != null) {
        await prefs.setInt('customer_reservation_table_id', _bookingTableId!);
      }
      await prefs.setInt('customer_reservation_party_size', _partySize);
      await Clipboard.setData(ClipboardData(text: reservationCode));
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            icon: const Icon(Icons.event_available, size: 42),
            title: const Text('Đặt bàn thành công'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${data['table']} • ${data['partySize']} khách'),
                Text(
                  DateFormat('dd/MM/yyyy • HH:mm').format(
                    DateTime.parse(data['startsAtUtc'].toString()).toLocal(),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Mã đặt bàn (đã sao chép):'),
                SelectableText(
                  reservationCode,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Đóng'),
              ),
            ],
          ),
        );
      }
      _note.clear();
      await _loadAccountActivity();
    } on DioException catch (e) {
      _message(apiError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _placeOrder() async {
    if (!_requireAuth('order món')) return;
    if (_cart.isEmpty) {
      _message('Giỏ hàng chưa có món.');
      return;
    }
    if (_name.text.trim().length < 2 || _phone.text.trim().length < 7) {
      _message('Nhập tên và số điện thoại hợp lệ.');
      return;
    }
    setState(() => _busy = true);
    try {
      int selectedTableId;
      final reservationCode = _reservationCode.text.trim();
      if (reservationCode.isNotEmpty) {
        selectedTableId = _reservationTableId ?? 0;
      } else {
        final tables = await apiClient.dio.get(
          '/api/customer/tables',
          queryParameters: {
            'startsAt': DateTime.now().toUtc().toIso8601String(),
            'partySize': _partySize,
          },
        );
        final candidates = (tables.data as List)
            .map((x) => Map<String, dynamic>.from(x as Map))
            .toList();
        if (candidates.isEmpty) {
          _message('Không có bàn phù hợp hiện tại. Hãy thử đặt bàn trước.');
          return;
        }
        if (!mounted) return;
        final selected = await showDialog<int>(
          context: context,
          builder: (dialogContext) {
            var selectedId = candidates.first['id'] as int;
            return StatefulBuilder(
              builder: (context, setDialog) => AlertDialog(
                title: const Text('Chọn bàn phục vụ'),
                content: DropdownButtonFormField<int>(
                  initialValue: selectedId,
                  items: candidates
                      .map(
                        (t) => DropdownMenuItem<int>(
                          value: t['id'] as int,
                          child: Text(
                            '${t['tableName']} • ${t['area']} • ${t['capacity']} chỗ',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setDialog(() => selectedId = value);
                  },
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Hủy'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, selectedId),
                    child: const Text('Xác nhận'),
                  ),
                ],
              ),
            );
          },
        );
        if (selected == null || !mounted) return;
        selectedTableId = selected;
      }
      final code = _pendingOrderCode ?? const Uuid().v4();
      _pendingOrderCode = code;
      final orderRes = await apiClient.dio.post(
        '/api/customer/orders',
        data: {
          'tableId': selectedTableId,
          'clientRequestId': code,
          'customerName': _name.text.trim(),
          'customerPhone': _phone.text.trim(),
          'partySize': _partySize,
          'note': _note.text.trim(),
          'items': _quantities.entries
              .map((e) => {'productId': e.key, 'quantity': e.value})
              .toList(),
          if (reservationCode.isNotEmpty) 'reservationCode': reservationCode,
        },
      );
      final trackingCode =
          (orderRes.data is Map && orderRes.data['orderCode'] != null)
              ? '${orderRes.data['orderCode']}'
              : code;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('customer_last_tracking_code', trackingCode);
      await prefs.remove('customer_reservation_code');
      await prefs.remove('customer_reservation_table_id');
      await prefs.remove('customer_reservation_party_size');
      final tracked = await apiClient.dio.get(
        '/api/customer/orders/$trackingCode',
      );
      if (!mounted) return;
      _tracking.text = trackingCode;
      setState(() {
        _pendingOrderCode = null;
        _reservationCode.clear();
        _reservationTableId = null;
        _cart.clear();
        _quantities.clear();
        _tab = 4;
        _trackedOrder = Map<String, dynamic>.from(tracked.data as Map);
        _invoice = null;
      });
      _message(
        'Đã gửi order đến quán. Mã theo dõi được lưu trên thiết bị này.',
      );
      await _loadAccountActivity();
    } on DioException catch (e) {
      _message(apiError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _trackOrder() async {
    final code = _tracking.text.trim();
    if (code.isEmpty) {
      _message('Nhập mã theo dõi order.');
      return;
    }
    setState(() => _busy = true);
    try {
      final response = await apiClient.dio.get('/api/customer/orders/$code');
      final order = Map<String, dynamic>.from(response.data as Map);
      Map<String, dynamic>? invoice;
      if (order['invoice'] != null) {
        final invoiceResponse = await apiClient.dio.get(
          '/api/invoices/guest/$code',
        );
        invoice = Map<String, dynamic>.from(invoiceResponse.data as Map);
      }
      if (mounted) {
        setState(() {
          _trackedOrder = order;
          _invoice = invoice;
        });
      }
    } on DioException catch (e) {
      _message(apiError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _requestPayment() async {
    final order = _trackedOrder;
    if (order == null) return;
    final defaultRef = defaultPaymentReference(order['orderCode']);
    String method = 'VietQR';
    final reference = TextEditingController(text: defaultRef);
    final totalAmount = ((order['totalAmount'] as num?) ?? 0).toDouble();
    final payableWithVat = totalAmount + (totalAmount * 0.08).roundToDouble();
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('Yêu cầu thanh toán & Mã QR'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Quét mã QR bên dưới hoặc chọn Tiền mặt tại quầy. Quán sẽ xuất hóa đơn sau khi thu ngân xác nhận.',
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: method,
                    decoration: const InputDecoration(labelText: 'Hình thức'),
                    items: const [
                      DropdownMenuItem(
                        value: 'VietQR',
                        child: Text('Mã QR (VietQR)'),
                      ),
                      DropdownMenuItem(
                        value: 'BankTransfer',
                        child: Text('Chuyển khoản ngân hàng'),
                      ),
                      DropdownMenuItem(
                        value: 'Cash',
                        child: Text('Tiền mặt tại quầy'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setDialog(() {
                          method = value;
                          if (method != 'Cash' &&
                              reference.text.trim().isEmpty) {
                            reference.text = defaultRef;
                          }
                        });
                      }
                    },
                  ),
                  if (method != 'Cash') ...[
                    const SizedBox(height: 12),
                    PaymentQrCard(
                      orderCode: '${order['orderCode']}',
                      amount: payableWithVat,
                      tableName: '${order['table'] ?? ''}',
                      compact: true,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: reference,
                      decoration: const InputDecoration(
                        labelText: 'Mã tham chiếu giao dịch / Nội dung CK',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, {
                'method': method,
                'reference': reference.text.trim(),
              }),
              child: const Text('Gửi yêu cầu'),
            ),
          ],
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 250));
    reference.dispose();
    if (result == null) {
      return;
    }
    if (result['method'] != 'Cash' && (result['reference'] ?? '').isEmpty) {
      _message('Nhập mã giao dịch để thu ngân đối chiếu.');
      return;
    }
    try {
      await apiClient.dio.post(
        '/api/customer/orders/${order['clientRequestId']}/payment-request',
        data: {
          'paymentMethod': result['method'],
          'transactionCode': result['reference'],
        },
      );
      _message('Đã gửi yêu cầu thanh toán. Thu ngân cần xác nhận giao dịch.');
      await _trackOrder();
    } on DioException catch (e) {
      _message(apiError(e));
    }
  }

  Future<void> _chooseBookingTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _bookingTime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_bookingTime),
    );
    if (time == null) return;
    setState(() {
      _bookingTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      _bookingTableId = null;
    });
    await _loadBookingTables();
  }

  Widget _menu() {
    if (_loadingMenu) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Không tải được thực đơn: $_error'),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: _loadMenu, child: const Text('Thử lại')),
          ],
        ),
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextField(
            controller: _menuSearch,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Tìm món',
              suffixIcon: _menuSearch.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Xóa tìm kiếm',
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () {
                        _menuSearch.clear();
                        setState(() => _menuPage = 1);
                        _loadMenu();
                      },
                    ),
            ),
            onChanged: (query) async {
              setState(() => _menuPage = 1);
              try {
                final r = await apiClient.dio.get(
                  '/api/products',
                  queryParameters: {
                    'pageNumber': 1,
                    'pageSize': _menuPageSize,
                    'search': query,
                    if (_categoryId != null) 'categoryId': _categoryId,
                  },
                );
                if (mounted) {
                  setState(() {
                    _products = (r.data['items'] as List)
                        .map(
                          (x) => Product.fromJson(
                            Map<String, dynamic>.from(x as Map),
                          ),
                        )
                        .where((p) => p.available)
                        .toList();
                    _menuTotalCount =
                        (r.data['totalCount'] as num?)?.toInt() ?? 0;
                  });
                }
              } on DioException {
                // Keep the last loaded catalog visible when a search request fails.
              }
            },
          ),
        ),
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              Padding(
                padding: const EdgeInsets.all(4),
                child: ChoiceChip(
                  label: const Text('Tất cả'),
                  selected: _categoryId == null,
                  onSelected: (_) {
                    setState(() {
                      _categoryId = null;
                      _menuPage = 1;
                    });
                    _loadMenu();
                  },
                ),
              ),
              for (final c in _categories)
                Padding(
                  padding: const EdgeInsets.all(4),
                  child: ChoiceChip(
                    label: Text(c['name'] as String),
                    selected: _categoryId == c['id'],
                    onSelected: (_) {
                      setState(() {
                        _categoryId = c['id'] as int;
                        _menuPage = 1;
                      });
                      _loadMenu();
                    },
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: _products.isEmpty
              ? const EmptyStateView(
                  icon: Icons.restaurant_menu_outlined,
                  title: 'Không có món phù hợp',
                  subtitle: 'Thử từ khóa khác hoặc chọn danh mục "Tất cả".',
                )
              : LayoutBuilder(
                  builder: (context, box) => GridView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _products.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: box.maxWidth > 900
                    ? 5
                    : box.maxWidth > 600
                    ? 3
                    : 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: .78,
              ),
              itemBuilder: (context, index) {
                final product = _products[index];
                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => _openProductDetail(product),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: product.imageUrl == null
                              ? Container(
                                  width: double.infinity,
                                  color: const Color(0xFFF3E7DC),
                                  child: const Icon(
                                    Icons.local_cafe_outlined,
                                    size: 48,
                                  ),
                                )
                              : Image.network(
                                  '${AppConfig.apiBaseUrl}${product.imageUrl}',
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) =>
                                      const Icon(Icons.broken_image_outlined),
                                ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _money.format(product.price),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  IconButton.filledTonal(
                                    onPressed: () => _add(product),
                                    icon: const Icon(
                                      Icons.add_shopping_cart,
                                      size: 18,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        if (_menuTotalCount > _menuPageSize)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _menuPage > 1
                      ? () {
                          setState(() => _menuPage--);
                          _loadMenu();
                        }
                      : null,
                  icon: const Icon(Icons.chevron_left, size: 18),
                  label: const Text('Trước'),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text(
                    'Trang $_menuPage / ${(_menuTotalCount / _menuPageSize).ceil()}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _menuPage * _menuPageSize < _menuTotalCount
                      ? () {
                          setState(() => _menuPage++);
                          _loadMenu();
                        }
                      : null,
                  icon: const Icon(Icons.chevron_right, size: 18),
                  label: const Text('Sau'),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _booking() {
    if (sessionState.user == null) {
      return EmptyStateView(
        icon: Icons.lock_person_outlined,
        title: 'Vui lòng đăng nhập để đặt bàn',
        subtitle:
            'Bạn cần đăng nhập tài khoản Khách hàng trước khi đặt bàn giữ chỗ tại Bếp Nhà.',
        action: FilledButton.icon(
          onPressed: () => context.go('/login'),
          icon: const Icon(Icons.login_rounded),
          label: const Text('Đăng nhập ngay'),
        ),
      );
    }
    return ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Text(
        'Đặt bàn',
        style: Theme.of(context).textTheme.headlineSmall
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      const Text(
        'Chọn thời gian và số khách. Bàn được giữ trong khung 90 phút.',
      ),
      const SizedBox(height: 18),
      TextField(
        controller: _name,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          labelText: 'Họ tên',
          prefixIcon: Icon(Icons.person_outline),
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _phone,
        keyboardType: TextInputType.phone,
        decoration: const InputDecoration(
          labelText: 'Số điện thoại',
          prefixIcon: Icon(Icons.phone_outlined),
        ),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<int>(
        initialValue: _partySize,
        decoration: const InputDecoration(labelText: 'Số khách'),
        items: List.generate(20, (i) => i + 1)
            .map((n) => DropdownMenuItem(value: n, child: Text('$n khách')))
            .toList(),
        onChanged: (n) {
          if (n != null) {
            setState(() {
              _partySize = n;
              _bookingTableId = null;
            });
            _loadBookingTables();
          }
        },
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: _chooseBookingTime,
        icon: const Icon(Icons.calendar_month),
        label: Text(
          DateFormat('EEEE, dd/MM/yyyy • HH:mm', 'vi_VN').format(_bookingTime),
        ),
      ),
      const SizedBox(height: 12),
      if (_bookingTables.isEmpty)
        const Text('Không còn bàn phù hợp thời gian này. Hãy chọn giờ khác.')
      else
        DropdownButtonFormField<int>(
          initialValue: _bookingTableId,
          decoration: const InputDecoration(labelText: 'Chọn bàn'),
          items: _bookingTables
              .map(
                (t) => DropdownMenuItem<int>(
                  value: t['id'] as int,
                  child: Text(
                    '${t['tableName']} • ${t['area']} • ${t['capacity']} chỗ',
                  ),
                ),
              )
              .toList(),
          onChanged: (id) => setState(() => _bookingTableId = id),
        ),
      const SizedBox(height: 12),
      TextField(
        controller: _note,
        maxLines: 2,
        decoration: const InputDecoration(labelText: 'Ghi chú (tùy chọn)'),
      ),
      const SizedBox(height: 16),
      FilledButton.icon(
        onPressed: _busy ? null : _bookTable,
        icon: const Icon(Icons.event_available),
        label: Text(_busy ? 'Đang đặt bàn…' : 'Xác nhận đặt bàn'),
      ),
    ],
  );
  }

  Widget _cartView() {
    if (sessionState.user == null) {
      return EmptyStateView(
        icon: Icons.lock_person_outlined,
        title: 'Vui lòng đăng nhập để order món',
        subtitle:
            'Bạn cần đăng nhập tài khoản Khách hàng để chọn món vào giỏ hàng và gửi order đến bếp.',
        action: FilledButton.icon(
          onPressed: () => context.go('/login'),
          icon: const Icon(Icons.login_rounded),
          label: const Text('Đăng nhập ngay'),
        ),
      );
    }
    if (_cart.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shopping_bag_outlined, size: 52),
            const SizedBox(height: 12),
            const Text('Chưa có món trong giỏ.'),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => setState(() => _tab = 1),
              child: const Text('Xem thực đơn'),
            ),
          ],
        ),
      );
    }
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              for (final entry in _quantities.entries)
                Card(
                  child: ListTile(
                    title: Text(_cart[entry.key]!.name),
                    subtitle: Text(_money.format(_cart[entry.key]!.price)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () =>
                              _changeQuantity(entry.key, entry.value - 1),
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        Text('${entry.value}'),
                        IconButton(
                          onPressed: () =>
                              _changeQuantity(entry.key, entry.value + 1),
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: _reservationCode,
                decoration: InputDecoration(
                  labelText: 'Mã đặt bàn (nếu đã đặt)',
                  prefixIcon: const Icon(Icons.event_seat),
                  helperText:
                      'Nhập mã đã nhận để order vào đúng bàn đặt, hoặc xóa để chọn bàn trống.',
                  suffixIcon: _reservationCode.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Xóa mã đặt bàn',
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () async {
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.remove('customer_reservation_code');
                            await prefs.remove('customer_reservation_table_id');
                            if (!mounted) return;
                            setState(() {
                              _reservationCode.clear();
                              _reservationTableId = null;
                              _pendingOrderCode = null;
                            });
                          },
                        ),
                ),
                onChanged: (_) {
                  setState(() {
                    _pendingOrderCode = null;
                    _reservationTableId = null;
                  });
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Họ tên người đặt',
                ),
                onChanged: (_) => _pendingOrderCode = null,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Số điện thoại'),
                onChanged: (_) => _pendingOrderCode = null,
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(
                initialValue: _partySize,
                decoration: const InputDecoration(labelText: 'Số khách'),
                items: List.generate(20, (i) => i + 1)
                    .map(
                      (n) =>
                          DropdownMenuItem(value: n, child: Text('$n khách')),
                    )
                    .toList(),
                onChanged: (n) {
                  if (n != null) {
                    _pendingOrderCode = null;
                    setState(() => _partySize = n);
                  }
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _note,
                decoration: const InputDecoration(
                  labelText: 'Ghi chú cho quán (tùy chọn)',
                ),
                onChanged: (_) => _pendingOrderCode = null,
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Tạm tính\n${_money.format(_cartTotal)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _busy ? null : _placeOrder,
                  icon: const Icon(Icons.send),
                  label: Text(_busy ? 'Đang gửi…' : 'Gửi order'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _trackingView() {
    if (sessionState.user == null) {
      return EmptyStateView(
        icon: Icons.lock_person_outlined,
        title: 'Vui lòng đăng nhập để xem Order & Hóa đơn',
        subtitle:
            'Đăng nhập tài khoản Khách hàng để theo dõi trạng thái món ăn, lịch sử đặt bàn và thanh toán mã QR.',
        action: FilledButton.icon(
          onPressed: () => context.go('/login'),
          icon: const Icon(Icons.login_rounded),
          label: const Text('Đăng nhập ngay'),
        ),
      );
    }
    return ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Theo dõi order & Hóa đơn',
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          if (sessionState.user != null)
            IconButton(
              tooltip: 'Làm mới lịch sử',
              onPressed: _loadAccountActivity,
              icon: const Icon(Icons.refresh_rounded),
            ),
        ],
      ),
      if (sessionState.user == null) ...[
        const SizedBox(height: 8),
        Card(
          color: const Color(0xFFFFF8F2),
          child: ListTile(
            leading: const Icon(
              Icons.person_pin_rounded,
              color: AppColors.primary,
            ),
            title: const Text(
              'Đăng nhập để tự động lưu lịch sử đặt bàn & gọi món',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: const Text(
              'Không cần nhớ mã UUID, tra cứu mọi đơn hàng và hóa đơn theo tài khoản.',
            ),
            trailing: FilledButton.tonal(
              onPressed: () => context.push('/login'),
              child: const Text('Đăng nhập'),
            ),
          ),
        ),
      ],
      const SizedBox(height: 12),
      if (_myOrders.isNotEmpty) ...[
        Text(
          'Chọn nhanh đơn hàng của bạn (chạm để xem chi tiết)',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _myOrders.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, index) {
              final o = _myOrders[index];
              final code = '${o['orderCode'] ?? o['clientRequestId'] ?? ''}';
              final selected =
                  _trackedOrder != null &&
                  (_trackedOrder!['orderCode'] == o['orderCode'] ||
                      _trackedOrder!['clientRequestId'] ==
                          o['clientRequestId']);
              return ChoiceChip(
                label: Text('${o['orderCode']} • ${o['table']}'),
                selected: selected,
                onSelected: code.isEmpty
                    ? null
                    : (_) {
                        _tracking.text = code;
                        _trackOrder();
                      },
              );
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
      Card(
        margin: EdgeInsets.zero,
        child: ExpansionTile(
          leading: const Icon(Icons.qr_code_scanner_rounded),
          title: const Text(
            'Tra cứu bằng mã đơn khác',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            TextField(
              controller: _tracking,
              decoration: const InputDecoration(
                labelText: 'Mã theo dõi',
                hintText: 'Nhập mã đơn (VD: ORD-482910) hoặc UUID',
              ),
              onSubmitted: (_) => _trackOrder(),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _busy ? null : _trackOrder,
                icon: const Icon(Icons.search_rounded),
                label: const Text('Tra cứu đơn'),
              ),
            ),
          ],
        ),
      ),
      if (_trackedOrder != null) ...[
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '${_trackedOrder!['orderCode']} • Bàn ${_trackedOrder!['table'] ?? ''}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    StatusPill(
                      status: '${_trackedOrder!['status']}',
                      compact: true,
                    ),
                  ],
                ),
                for (final item in (_trackedOrder!['items'] as List? ?? []))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${item['quantity']} × ${item['product']}',
                          ),
                        ),
                        Text(_money.format(item['totalPrice'])),
                      ],
                    ),
                  ),
                const Divider(),
                Text(
                  'Tổng tiền: ${_money.format(_trackedOrder!['totalAmount'])}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (_trackedOrder!['paymentRequest'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: StatusPill(
                      status:
                          '${(_trackedOrder!['paymentRequest'] as Map)['status']}',
                      compact: true,
                    ),
                  ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        final sub =
                            ((_trackedOrder!['totalAmount'] as num?) ?? 0)
                                .toDouble();
                        final payable = sub + (sub * 0.08).roundToDouble();
                        showPaymentQrDialog(
                          context,
                          orderCode: '${_trackedOrder!['orderCode']}',
                          amount: payable,
                          tableName: '${_trackedOrder!['table'] ?? ''}',
                        );
                      },
                      icon: const Icon(Icons.qr_code_2_rounded),
                      label: const Text('Mã QR thanh toán'),
                    ),
                    if (_trackedOrder!['status'] == 'Served' ||
                        _trackedOrder!['status'] == 'Ready')
                      FilledButton.icon(
                        onPressed: _busy ? null : _requestPayment,
                        icon: const Icon(Icons.payments_outlined),
                        label: Text(
                          _trackedOrder!['paymentRequest'] != null &&
                                  (_trackedOrder!['paymentRequest']
                                          as Map)['status'] ==
                                      'PendingConfirmation'
                              ? 'Đổi hình thức / mã giao dịch'
                              : 'Yêu cầu thanh toán',
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (_invoice != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hóa đơn ${_invoice!['invoiceCode']}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text('Ngày tạo: ${formatDateTime(_invoice!['createdAt'])}'),
                  for (final item in (_invoice!['items'] as List? ?? []))
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('${item['quantity']} × ${item['product']}'),
                      subtitle: Text(_money.format(item['unitPrice'])),
                      trailing: Text(_money.format(item['totalPrice'])),
                    ),
                  const Divider(),
                  if (_invoice!['subTotal'] != null)
                    Text('Tạm tính: ${_money.format(_invoice!['subTotal'])}'),
                  if (((_invoice!['discount'] as num?) ?? 0) > 0)
                    Text('Giảm giá: -${_money.format(_invoice!['discount'])}'),
                  if (((_invoice!['tax'] as num?) ?? 0) > 0)
                    Text('Thuế VAT: ${_money.format(_invoice!['tax'])}'),
                  Text(
                    'Đã thanh toán: ${_money.format(_invoice!['totalAmount'])}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
      ],
      if (sessionState.user != null) ...[
        const SizedBox(height: 20),
        Text(
          'Đơn hàng gần đây của bạn',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        if (_myOrders.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Tài khoản của bạn chưa có đơn hàng nào.'),
            ),
          )
        else
          for (final o in _myOrders)
            Card(
              child: ListTile(
                leading: const Icon(
                  Icons.receipt_long_rounded,
                  color: AppColors.primary,
                ),
                title: Text(
                  '${o['orderCode']} • Bàn ${o['table']}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  '${formatDateTime(o['orderDate'])} • ${_money.format(o['totalAmount'])}',
                ),
                trailing: StatusPill(
                  status: '${o['status']}',
                  compact: true,
                ),
                onTap: (o['orderCode'] ?? o['clientRequestId']) == null
                    ? null
                    : () {
                        _tracking.text =
                            '${o['orderCode'] ?? o['clientRequestId']}';
                        _trackOrder();
                      },
              ),
            ),
        if (_myReservations.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Lịch đặt bàn của bạn',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          for (final r in _myReservations)
            Card(
              child: ListTile(
                leading: const Icon(
                  Icons.event_seat_rounded,
                  color: AppColors.primary,
                ),
                title: Text(
                  '${r['table']} (${r['area']}) • ${r['partySize']} khách',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  'Giờ hẹn: ${formatDateTime(r['startsAtUtc'])}\nMã: ${r['reservationCode']}',
                ),
                isThreeLine: true,
                trailing: StatusPill(
                  status: '${r['status']}',
                  compact: true,
                ),
                onTap: () {
                  _reservationCode.text = '${r['reservationCode']}';
                  _reservationTableId = (r['tableId'] as num?)?.toInt();
                  _message('Đã điền mã đặt bàn vào giỏ hàng.');
                },
              ),
            ),
        ],
      ],
    ],
  );
  }

  Future<void> _openBlogDetail(Map<String, dynamic> post) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.82,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollCtrl) => ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 32),
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDE4DA),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${post['category']}',
                    style: const TextStyle(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                Text(
                  '${post['readingMinutes'] ?? 3} phút đọc • ${formatDateTime(post['publishedAtUtc'])}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${post['title']}',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.verified_user_outlined,
                  size: 16,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  'Tác giả: ${post['authorName'] ?? 'Bếp Nhà'}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const Divider(height: 28),
            Text(
              '${post['summary']}',
              style: const TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              '${post['content']}',
              style: const TextStyle(
                fontSize: 15,
                height: 1.65,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createBlogDialog() async {
    final titleCtrl = TextEditingController();
    final categoryCtrl = TextEditingController(text: 'Ẩm thực Bếp Nhà');
    final summaryCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isFeatured = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('Đăng bài Blog nhà hàng'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(labelText: 'Tiêu đề bài viết'),
                    validator: (v) =>
                        v == null || v.trim().length < 4 ? 'Nhập tiêu đề' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: categoryCtrl,
                    decoration: const InputDecoration(labelText: 'Chuyên mục'),
                    validator: (v) =>
                        v == null || v.trim().length < 2 ? 'Nhập chuyên mục' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: summaryCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Tóm tắt ngắn'),
                    validator: (v) => v == null || v.trim().length < 10
                        ? 'Tóm tắt tối thiểu 10 ký tự'
                        : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: contentCtrl,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Nội dung chi tiết',
                    ),
                    validator: (v) => v == null || v.trim().length < 20
                        ? 'Nội dung tối thiểu 20 ký tự'
                        : null,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: isFeatured,
                    title: const Text('Bài viết nổi bật'),
                    onChanged: (v) => setDialog(() => isFeatured = v),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(dialogContext, true);
                }
              },
              child: const Text('Đăng bài'),
            ),
          ],
        ),
      ),
    );
    final payload = {
      'title': titleCtrl.text.trim(),
      'category': categoryCtrl.text.trim(),
      'summary': summaryCtrl.text.trim(),
      'content': contentCtrl.text.trim(),
      'authorName': sessionState.user?.fullName ?? 'Bếp Nhà',
      'readingMinutes': 3,
      'isFeatured': isFeatured,
    };
    await Future<void>.delayed(const Duration(milliseconds: 250));
    titleCtrl.dispose();
    categoryCtrl.dispose();
    summaryCtrl.dispose();
    contentCtrl.dispose();
    if (ok != true) return;
    try {
      await apiClient.dio.post('/api/customer/blogs', data: payload);
      _message('Đã đăng bài Blog mới.');
      await _loadInfoAndBlogs();
    } on DioException catch (e) {
      _message(apiError(e));
    }
  }

  Widget _homeQuickAction({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Card(
        margin: EdgeInsets.zero,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openProductDetail(Product product) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        var relPage = 1;
        const relPageSize = 3;
        var relTotal = 0;
        var relLoading = true;
        var relItems = <Product>[];
        var initialized = false;

        Future<void> loadRelated(
          void Function(void Function()) setSheetState,
        ) async {
          setSheetState(() => relLoading = true);
          try {
            final res = await apiClient.dio.get(
              '/api/products',
              queryParameters: {
                'categoryId': product.categoryId,
                'excludeId': product.id,
                'pageNumber': relPage,
                'pageSize': relPageSize,
              },
            );
            if (!ctx.mounted) return;
            setSheetState(() {
              relItems = (res.data['items'] as List)
                  .map(
                    (x) => Product.fromJson(
                      Map<String, dynamic>.from(x as Map),
                    ),
                  )
                  .where((p) => p.available)
                  .toList();
              relTotal = (res.data['totalCount'] as num?)?.toInt() ?? 0;
              relLoading = false;
            });
          } on DioException {
            if (ctx.mounted) setSheetState(() => relLoading = false);
          }
        }

        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            if (!initialized) {
              initialized = true;
              Future.microtask(() => loadRelated(setSheetState));
            }
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.82,
              maxChildSize: 0.95,
              minChildSize: 0.5,
              builder: (_, scrollCtrl) => ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.all(20),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          product.name,
                          style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: product.imageUrl == null
                        ? Container(
                            height: 200,
                            color: const Color(0xFFF3E7DC),
                            child: const Icon(
                              Icons.local_cafe_outlined,
                              size: 64,
                            ),
                          )
                        : Image.network(
                            '${AppConfig.apiBaseUrl}${product.imageUrl}',
                            height: 220,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              height: 200,
                              color: const Color(0xFFF3E7DC),
                              child: const Icon(
                                Icons.broken_image_outlined,
                                size: 48,
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _money.format(product.price),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Theme.of(ctx).colorScheme.primary,
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: () {
                          _add(product);
                          Navigator.of(ctx).pop();
                        },
                        icon: const Icon(Icons.add_shopping_cart),
                        label: const Text('Thêm vào giỏ'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    (product.description?.trim().isNotEmpty ?? false)
                        ? product.description!
                        : 'Món đặc trưng tại Bếp Nhà, chế biến tươi mỗi ngày.',
                    style: const TextStyle(height: 1.5),
                  ),
                  const Divider(height: 28),
                  Text(
                    'Sản phẩm liên quan',
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (relLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (relItems.isEmpty)
                    const Text('Chưa có sản phẩm liên quan trong danh mục này.')
                  else ...[
                    for (final rp in relItems)
                      Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: rp.imageUrl == null
                              ? const Icon(Icons.local_cafe_outlined)
                              : ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    '${AppConfig.apiBaseUrl}${rp.imageUrl}',
                                    width: 48,
                                    height: 48,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) =>
                                        const Icon(Icons.broken_image_outlined),
                                  ),
                                ),
                          title: Text(
                            rp.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(_money.format(rp.price)),
                          trailing: IconButton.filledTonal(
                            onPressed: () => _add(rp),
                            icon: const Icon(Icons.add_shopping_cart, size: 18),
                          ),
                          onTap: () {
                            Navigator.of(ctx).pop();
                            _openProductDetail(rp);
                          },
                        ),
                      ),
                    if (relTotal > relPageSize)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton.icon(
                            onPressed: relPage > 1
                                ? () {
                                    relPage--;
                                    loadRelated(setSheetState);
                                  }
                                : null,
                            icon: const Icon(Icons.chevron_left, size: 18),
                            label: const Text('Trước'),
                          ),
                          Text(
                            'Trang $relPage / ${(relTotal / relPageSize).ceil()}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          TextButton.icon(
                            onPressed: relPage * relPageSize < relTotal
                                ? () {
                                    relPage++;
                                    loadRelated(setSheetState);
                                  }
                                : null,
                            icon: const Icon(Icons.chevron_right, size: 18),
                            label: const Text('Sau'),
                          ),
                        ],
                      ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _blogAndInfoView() {
    if (_loadingInfo && _restaurantInfo == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final info = _restaurantInfo ?? const <String, dynamic>{};
    final stats = info['stats'] is Map
        ? Map<String, dynamic>.from(info['stats'] as Map)
        : const <String, dynamic>{};
    final highlights = (info['highlights'] as List? ?? const [])
        .map((e) => e.toString())
        .toList();
    final areas = (info['areas'] as List? ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final isAdmin = sessionState.user?.role == 'Admin';
    final homeProducts = _homeProducts.isNotEmpty
        ? _homeProducts
        : _products.take(_homePageSize).toList();

    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([
          _loadInfoAndBlogs(),
          _loadMenu(),
          _loadHomeProducts(),
          _loadAccountActivity(),
        ]);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primaryDark, Color(0xFF8B5637)],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'TRANG CHỦ • NHÀ HÀNG & QUÁN CÀ PHÊ',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.9,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '${info['name'] ?? 'Bếp Nhà Coffee & Kitchen'}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${info['tagline'] ?? 'Ẩm thực Việt ấm cúng & Cà phê rang mộc thủ công'}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '${info['story'] ?? ''}',
                  style: const TextStyle(
                    color: Colors.white,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: () => setState(() => _tab = 1),
                      icon: const Icon(Icons.restaurant_menu_rounded, size: 18),
                      label: const Text('Khám phá thực đơn'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () => setState(() => _tab = 2),
                      icon: const Icon(Icons.event_available_rounded, size: 18),
                      label: const Text('Đặt bàn ngay'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _homeQuickAction(
                icon: Icons.restaurant_menu_rounded,
                title: 'Thực đơn',
                subtitle: '${_products.length} món sẵn sàng',
                color: const Color(0xFF8B4C2F),
                onTap: () => setState(() => _tab = 1),
              ),
              const SizedBox(width: 10),
              _homeQuickAction(
                icon: Icons.event_seat_rounded,
                title: 'Đặt bàn',
                subtitle: 'Giữ chỗ trước',
                color: const Color(0xFF1E7E48),
                onTap: () => setState(() => _tab = 2),
              ),
              const SizedBox(width: 10),
              _homeQuickAction(
                icon: Icons.shopping_bag_outlined,
                title: 'Giỏ hàng',
                subtitle:
                    '${_quantities.values.fold<int>(0, (a, b) => a + b)} món đã chọn',
                color: const Color(0xFFC85A17),
                onTap: () => setState(() => _tab = 3),
              ),
              const SizedBox(width: 10),
              _homeQuickAction(
                icon: Icons.receipt_long_outlined,
                title: 'Order & HĐ',
                subtitle: 'Tra cứu & thanh toán',
                color: const Color(0xFF1D5B9E),
                onTap: () => setState(() => _tab = 4),
              ),
            ],
          ),
          if (_categories.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(
              'Danh mục sản phẩm',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  label: const Text('Tất cả'),
                  onPressed: () {
                    setState(() {
                      _categoryId = null;
                      _menuPage = 1;
                      _tab = 1;
                    });
                    _loadMenu();
                  },
                ),
                for (final c in _categories)
                  ActionChip(
                    label: Text('${c['name']}'),
                    onPressed: () {
                      setState(() {
                        _categoryId = c['id'] as int;
                        _menuPage = 1;
                        _tab = 1;
                      });
                      _loadMenu();
                    },
                  ),
              ],
            ),
          ],
          if (homeProducts.isNotEmpty || _loadingHomeProducts) ...[
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Sản phẩm mới nhất',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                TextButton.icon(
                  onPressed: () => setState(() => _tab = 1),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: const Text('Xem tất cả'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_loadingHomeProducts && homeProducts.isEmpty)
              const Center(child: CircularProgressIndicator())
            else
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final p in homeProducts)
                    SizedBox(
                      width: 240,
                      child: Card(
                        margin: EdgeInsets.zero,
                        child: ListTile(
                          onTap: () => _openProductDetail(p),
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3E7DC),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: p.imageUrl == null
                                ? const Icon(
                                    Icons.local_cafe_rounded,
                                    color: AppColors.primary,
                                  )
                                : ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(
                                      '${AppConfig.apiBaseUrl}${p.imageUrl}',
                                      width: 44,
                                      height: 44,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => const Icon(
                                        Icons.local_cafe_rounded,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                          ),
                          title: Text(
                            p.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            _money.format(p.price),
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          trailing: IconButton.filledTonal(
                            tooltip: 'Thêm vào giỏ',
                            onPressed: () => _add(p),
                            icon: const Icon(
                              Icons.add_shopping_cart_rounded,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            if (_homeTotalCount > _homePageSize)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _homePage > 1
                          ? () {
                              setState(() => _homePage--);
                              _loadHomeProducts();
                            }
                          : null,
                      icon: const Icon(Icons.chevron_left, size: 18),
                      label: const Text('Trước'),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'Trang $_homePage / ${(_homeTotalCount / _homePageSize).ceil()}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _homePage * _homePageSize < _homeTotalCount
                          ? () {
                              setState(() => _homePage++);
                              _loadHomeProducts();
                            }
                          : null,
                      icon: const Icon(Icons.chevron_right, size: 18),
                      label: const Text('Sau'),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 18),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Liên hệ & Tiện ích tại quán',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.location_on_outlined,
                      color: AppColors.primary,
                    ),
                    title: const Text(
                      'Địa chỉ',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${info['address'] ?? '128 Nguyễn Huệ, Quận 1, TP. Hồ Chí Minh'}',
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.access_time_rounded,
                      color: AppColors.primary,
                    ),
                    title: const Text(
                      'Giờ mở cửa',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${info['openingHours'] ?? '07:00 – 22:30 hàng ngày'}',
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.phone_in_talk_outlined,
                      color: AppColors.primary,
                    ),
                    title: const Text(
                      'Hotline & Email',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${info['phone'] ?? '0901 234 567'} • ${info['email'] ?? 'lienhe@bepnha.local'}',
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.wifi_rounded,
                      color: AppColors.primary,
                    ),
                    title: Text(
                      'Wi-Fi miễn phí: ${info['wifiName'] ?? 'BepNha_FreeWifi_5G'}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      'Mật khẩu: ${info['wifiPassword'] ?? 'bepnhachaoquykhach'}',
                    ),
                    trailing: IconButton(
                      tooltip: 'Sao chép mật khẩu Wi-Fi',
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      onPressed: () {
                        Clipboard.setData(
                          ClipboardData(
                            text:
                                '${info['wifiPassword'] ?? 'bepnhachaoquykhach'}',
                          ),
                        );
                        _message('Đã sao chép mật khẩu Wi-Fi.');
                      },
                    ),
                  ),
                  if (stats.isNotEmpty) ...[
                    const Divider(),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(
                          avatar: const Icon(Icons.meeting_room_outlined, size: 16),
                          label: Text('${stats['areaCount'] ?? 0} khu vực'),
                        ),
                        Chip(
                          avatar: const Icon(Icons.table_restaurant_outlined, size: 16),
                          label: Text(
                            '${stats['availableTables'] ?? 0}/${stats['tableCount'] ?? 0} bàn trống',
                          ),
                        ),
                        Chip(
                          avatar: const Icon(Icons.groups_outlined, size: 16),
                          label: Text('${stats['totalSeats'] ?? 0} chỗ ngồi'),
                        ),
                        Chip(
                          avatar: const Icon(Icons.local_cafe_outlined, size: 16),
                          label: Text('${stats['productCount'] ?? 0} món thực đơn'),
                        ),
                      ],
                    ),
                  ],
                  if (highlights.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Điểm nổi bật tại Bếp Nhà',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    for (final h in highlights)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle_rounded,
                              size: 16,
                              color: Color(0xFF1E7E48),
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(h)),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
          if (areas.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(
              'Không gian các khu vực phục vụ',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            for (final a in areas)
              Card(
                child: ListTile(
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEDE4DA),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.deck_outlined,
                      color: AppColors.primary,
                    ),
                  ),
                  title: Text(
                    '${a['name']}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${(a['description'] as String? ?? '').isEmpty ? 'Không gian phục vụ thoáng đãng' : a['description']} • ${a['tableCount']} bàn (${a['seatCount']} chỗ)',
                  ),
                ),
              ),
          ],
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Blog & Câu chuyện Bếp Nhà',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              if (isAdmin)
                FilledButton.tonalIcon(
                  onPressed: _createBlogDialog,
                  icon: const Icon(Icons.post_add_rounded, size: 18),
                  label: const Text('Đăng bài'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (_blogs.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('Chưa có bài viết blog nào.'),
              ),
            )
          else
            for (final post in _blogs)
              Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => _openBlogDetail(post),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEDE4DA),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '${post['category']}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                            ),
                            if (post['isFeatured'] == true) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF4DE),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  'Nổi bật',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFB26B00),
                                  ),
                                ),
                              ),
                            ],
                            const Spacer(),
                            Text(
                              '${post['readingMinutes'] ?? 3} phút đọc',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${post['title']}',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${post['summary']}',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${post['authorName']} • ${formatDateTime(post['publishedAtUtc'])}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const Text(
                              'Đọc bài viết →',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = sessionState.user;
    return Scaffold(
      appBar: buildAppBar(
        context,
        title: user == null ? 'Bếp Nhà' : user.fullName,
        subtitle: 'Thực đơn, Đặt bàn & Gọi món',
        fallbackRoute: '/login',
        showBack: user == null || user.role != 'Customer',
        showNotifications: false,
        actions: [
          if (user == null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                onPressed: () => context.go('/login'),
                icon: const Icon(Icons.login_rounded),
                label: const Text('Đăng nhập'),
              ),
            )
          else ...[
            if (user.role != 'Customer')
              TextButton.icon(
                onPressed: () => context.go('/dashboard'),
                icon: const Icon(Icons.dashboard_outlined, size: 18),
                label: const Text('Quản lý'),
              ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: OutlinedButton.icon(
                onPressed: () async {
                  await authRepository.logout();
                  sessionState.signOut();
                  if (context.mounted) {
                    context.go('/login');
                  }
                },
                icon: const Icon(Icons.logout_rounded, size: 17),
                label: const Text('Đăng xuất'),
              ),
            ),
          ],
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: [
          _blogAndInfoView(),
          _menu(),
          _booking(),
          _cartView(),
          _trackingView(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) => setState(() => _tab = index),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Trang chủ',
          ),
          const NavigationDestination(
            icon: Icon(Icons.restaurant_menu),
            label: 'Thực đơn',
          ),
          const NavigationDestination(
            icon: Icon(Icons.event_seat),
            label: 'Đặt bàn',
          ),
          NavigationDestination(
            icon: Badge(
              label: Text(
                '${_quantities.values.fold<int>(0, (a, b) => a + b)}',
              ),
              isLabelVisible: _quantities.isNotEmpty,
              child: const Icon(Icons.shopping_bag_outlined),
            ),
            label: 'Giỏ hàng',
          ),
          const NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            label: 'Order & HĐ',
          ),
        ],
      ),
    );
  }
}
