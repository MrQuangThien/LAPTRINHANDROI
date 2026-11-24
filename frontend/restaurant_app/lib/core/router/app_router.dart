import 'package:go_router/go_router.dart';

import '../../providers/session_state.dart';
import '../../screens/auth/splash_screen.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/register_screen.dart';
import '../../screens/dashboard/dashboard_screen.dart';
import '../../screens/products/catalog_screen.dart';
import '../../screens/tables/table_screen.dart';
import '../../screens/orders/order_draft_screen.dart';
import '../../screens/kitchen/kitchen_screen.dart';
import '../../screens/payments/payment_screen.dart';
import '../../screens/invoices/invoice_screen.dart';
import '../../screens/reports/report_screen.dart';
import '../../screens/categories/category_management_screen.dart';
import '../../screens/products/product_management_screen.dart';
import '../../screens/orders/order_management_screen.dart';
import '../../screens/tables/area_management_screen.dart';
import '../../screens/members/member_management_screen.dart';
import '../../screens/members/role_management_screen.dart';
import '../../screens/customer/customer_home_screen.dart';
import '../../screens/customer/reservation_management_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/splash',
  refreshListenable: sessionState,
  redirect: (context, state) {
    final path = state.matchedLocation;
    final isEntry =
        path == '/login' ||
        path == '/register' ||
        path == '/splash' ||
        path == '/customer';
    final user = sessionState.user;
    if (user == null && !isEntry) return '/login';
    if (user != null) {
      if (user.role == 'Customer' && path != '/customer') {
        return '/customer';
      }
      if (user.role != 'Customer' &&
          (path == '/login' || path == '/register')) {
        return '/dashboard';
      }
    }
    return null;
  },
  routes: [
    GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(
      path: '/customer',
      builder: (context, state) => const CustomerHomeScreen(),
    ),
    GoRoute(
      path: '/reservations',
      builder: (context, state) => const ReservationManagementScreen(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/dashboard',
      builder: (context, state) => const DashboardScreen(),
    ),
    GoRoute(path: '/menu', builder: (context, state) => const CatalogScreen()),
    GoRoute(path: '/tables', builder: (context, state) => const TableScreen()),
    GoRoute(
      path: '/orders/new/:tableId',
      builder: (context, state) => OrderDraftScreen(
        tableId: int.parse(state.pathParameters['tableId']!),
        tableName: state.uri.queryParameters['name'] ?? 'Bàn',
        activeOrderId: int.tryParse(state.uri.queryParameters['orderId'] ?? ''),
      ),
    ),
    GoRoute(
      path: '/orders',
      builder: (context, state) => const OrderManagementScreen(),
    ),
    GoRoute(
      path: '/kitchen',
      builder: (context, state) => const KitchenScreen(),
    ),
    GoRoute(
      path: '/payments',
      builder: (context, state) => const PaymentScreen(),
    ),
    GoRoute(
      path: '/invoices/order/:orderId',
      builder: (context, state) =>
          InvoiceScreen(orderId: int.parse(state.pathParameters['orderId']!)),
    ),
    GoRoute(
      path: '/reports',
      builder: (context, state) => const ReportScreen(),
    ),
    GoRoute(
      path: '/admin/categories',
      builder: (context, state) => const CategoryManagementScreen(),
    ),
    GoRoute(
      path: '/admin/products',
      builder: (context, state) => const ProductManagementScreen(),
    ),
    GoRoute(
      path: '/admin/areas',
      builder: (context, state) => const AreaManagementScreen(),
    ),
    GoRoute(
      path: '/admin/members',
      builder: (context, state) => const MemberManagementScreen(),
    ),
    GoRoute(
      path: '/admin/roles',
      builder: (context, state) => const RoleManagementScreen(),
    ),
  ],
);
