import '../core/database/database_helper.dart';
import '../core/network/api_client.dart';
import '../repositories/auth_repository.dart';
import '../repositories/catalog_repository.dart';
import '../repositories/table_repository.dart';
import '../repositories/admin_repository.dart';
import 'sync_service.dart';

final apiClient = ApiClient();
final localDatabase = DatabaseHelper.instance;
final authRepository = AuthRepository(apiClient);
final catalogRepository = CatalogRepository(apiClient, localDatabase);
final tableRepository = TableRepository(apiClient, localDatabase);
final adminRepository = AdminRepository(apiClient);
final syncService = SyncService(apiClient, localDatabase);
