import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/api_error.dart';
import '../../core/widgets/app_chrome.dart';
import '../../models/restaurant_table.dart';
import '../../services/app_services.dart';

class TableScreen extends StatefulWidget {
  const TableScreen({super.key});
  @override
  State<TableScreen> createState() => _TableScreenState();
}

class _TableScreenState extends State<TableScreen> {
  late Future<List<RestaurantTable>> _future;
  Set<int> _queuedTableIds = {};
  String? _statusFilter;

  @override
  void initState() {
    super.initState();
    _future = tableRepository.tables();
    _loadQueuedTables();
  }

  Future<void> _loadQueuedTables() async {
    final ids = await localDatabase.queuedTableIds();
    if (mounted) setState(() => _queuedTableIds = ids);
  }

  Future<void> _reload() async {
    final future = tableRepository.tables();
    setState(() {
      _future = future;
    });
    await future;
    await _loadQueuedTables();
  }

  Future<void> _markCleaned(int id) async {
    try {
      await apiClient.dio.post('/api/tables/$id/cleaned');
      await _reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể xác nhận dọn bàn: ${apiError(e)}')),
        );
      }
    }
  }

  Future<void> _transfer(
    RestaurantTable source,
    List<RestaurantTable> tables,
  ) async {
    final candidates = tables
        .where((t) => t.status == 'Available' && !_queuedTableIds.contains(t.id))
        .toList();
    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hiện không có bàn trống để chuyển order.'),
        ),
      );
      return;
    }
    var targetId = candidates.first.id;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Chuyển order từ ${source.name}'),
          content: DropdownButtonFormField<int>(
            initialValue: targetId,
            decoration: const InputDecoration(labelText: 'Bàn nhận order'),
            items: candidates
                .map(
                  (t) => DropdownMenuItem(
                    value: t.id,
                    child: Text('${t.name} • ${t.area} • ${t.capacity} chỗ'),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) setDialogState(() => targetId = value);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Chuyển bàn'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await apiClient.dio.post(
        '/api/tables/${source.id}/transfer',
        data: {'targetTableId': targetId},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã chuyển order sang bàn mới.')),
      );
      await _reload();
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể chuyển bàn: ${apiError(e)}')),
        );
      }
    }
  }

  Future<void> _merge(
    RestaurantTable source,
    List<RestaurantTable> tables,
  ) async {
    final candidates = tables
        .where(
          (t) =>
              t.id != source.id &&
              t.status == 'Occupied' &&
              t.activeOrderCount > 0,
        )
        .toList();
    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cần một bàn khác đang có order để gộp.')),
      );
      return;
    }
    var targetId = candidates.first.id;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Gộp ${source.name} vào bàn khác'),
          content: DropdownButtonFormField<int>(
            initialValue: targetId,
            decoration: const InputDecoration(labelText: 'Bàn giữ khách'),
            items: candidates
                .map(
                  (t) => DropdownMenuItem(
                    value: t.id,
                    child: Text(
                      '${t.name} • ${t.area} • ${t.activeOrderCount} order mở',
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) setDialogState(() => targetId = value);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Gộp bàn'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await apiClient.dio.post(
        '/api/tables/${source.id}/merge',
        data: {'targetTableId': targetId},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Đã gộp chỗ ngồi; order và hóa đơn vẫn được theo dõi riêng.',
          ),
        ),
      );
      await _reload();
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể gộp bàn: ${apiError(e)}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: buildAppBar(
      context,
      title: 'Bàn phục vụ',
      subtitle: 'Chọn bàn để mở order hoặc chuyển/gộp bàn',
      actions: [
        IconButton(
          tooltip: 'Làm mới',
          onPressed: _reload,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    ),
    body: FutureBuilder<List<RestaurantTable>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return EmptyStateView(
            icon: Icons.error_outline_rounded,
            title: 'Không tải được danh sách bàn',
            subtitle: '${snapshot.error}',
            action: FilledButton.icon(
              onPressed: _reload,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Thử lại'),
            ),
          );
        }
        final allTables = snapshot.data ?? [];
        if (allTables.isEmpty) {
          return const EmptyStateView(
            icon: Icons.table_restaurant_outlined,
            title: 'Chưa có bàn trong hệ thống',
            subtitle: 'Admin có thể thêm khu vực và bàn trong phần Quản trị.',
          );
        }
        final tables = _statusFilter == null
            ? allTables
            : allTables.where((t) => t.status == _statusFilter).toList();
        final filters = <(String?, String)>[
          (null, 'Tất cả (${allTables.length})'),
          (
            'Available',
            'Bàn trống (${allTables.where((t) => t.status == 'Available').length})',
          ),
          (
            'Occupied',
            'Đang phục vụ (${allTables.where((t) => t.status == 'Occupied').length})',
          ),
          (
            'Reserved',
            'Đã đặt (${allTables.where((t) => t.status == 'Reserved').length})',
          ),
          (
            'Cleaning',
            'Đang dọn (${allTables.where((t) => t.status == 'Cleaning').length})',
          ),
        ];
        return Column(
          children: [
            SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                children: [
                  for (final f in filters)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 6,
                      ),
                      child: ChoiceChip(
                        label: Text(f.$2),
                        selected: _statusFilter == f.$1,
                        onSelected: (_) => setState(() => _statusFilter = f.$1),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: tables.isEmpty
                  ? EmptyStateView(
                      icon: Icons.filter_alt_off_outlined,
                      title: 'Không có bàn ở trạng thái này',
                      subtitle:
                          'Chọn "Tất cả" để xem toàn bộ bàn trong hệ thống.',
                      action: OutlinedButton(
                        onPressed: () => setState(() => _statusFilter = null),
                        child: const Text('Xem tất cả bàn'),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _reload,
                      child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: MediaQuery.sizeOf(context).width > 960
                        ? 4
                        : MediaQuery.sizeOf(context).width > 640
                        ? 3
                        : 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    mainAxisExtent: 192,
                  ),
                  itemCount: tables.length,
                  itemBuilder: (context, i) {
                    final t = tables[i];
                    final queued = _queuedTableIds.contains(t.id);
                    final (fg, bg, _, _) = statusStyle(t.status);
                    final canOpenOrder =
                        !queued &&
                        (t.status == 'Available' ||
                            t.status == 'Reserved' ||
                            t.activeOrderId != null);
                    return Card(
                      margin: EdgeInsets.zero,
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: canOpenOrder
                            ? () async {
                                int? orderId = t.activeOrderId;
                                if (t.activeOrders.length > 1) {
                                  final chosen = await showDialog<int>(
                                    context: context,
                                    builder: (dialogContext) => SimpleDialog(
                                      title: Text(
                                        'Chọn order trên ${t.name}',
                                      ),
                                      children: [
                                        for (final o in t.activeOrders)
                                          SimpleDialogOption(
                                            onPressed: () => Navigator.pop(
                                              dialogContext,
                                              (o['id'] as num).toInt(),
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    '${o['orderCode']}${o['customerName'] == null ? '' : ' • ${o['customerName']}'}',
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                ),
                                                StatusPill(
                                                  status:
                                                      o['status'] as String,
                                                  compact: true,
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  );
                                  if (chosen == null || !context.mounted) {
                                    return;
                                  }
                                  orderId = chosen;
                                }
                                await context.push(
                                  '/orders/new/${t.id}?name=${Uri.encodeComponent(t.name)}${orderId == null ? '' : '&orderId=$orderId'}',
                                );
                                await _reload();
                              }
                            : null,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: bg,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      Icons.table_restaurant_rounded,
                                      color: fg,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: queued
                                        ? const StatusPill(
                                            status: 'Pending',
                                            compact: true,
                                          )
                                        : StatusPill(
                                            status: t.status,
                                            compact: true,
                                          ),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    t.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${t.area} • ${t.capacity} chỗ',
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (t.activeOrderCount > 0) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      '${t.activeOrderCount} order đang mở',
                                      style: TextStyle(
                                        color: fg,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              if (!queued && t.status == 'Cleaning')
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.tonalIcon(
                                    onPressed: () => _markCleaned(t.id),
                                    icon: const Icon(
                                      Icons.check_circle_outline,
                                      size: 18,
                                    ),
                                    label: const Text('Dọn xong'),
                                  ),
                                )
                              else if (!queued &&
                                  t.status == 'Occupied' &&
                                  t.activeOrderId != null)
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        minimumSize: const Size(0, 34),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                        ),
                                      ),
                                      onPressed: () => _transfer(t, allTables),
                                      icon: const Icon(
                                        Icons.swap_horiz,
                                        size: 16,
                                      ),
                                      label: const Text(
                                        'Chuyển',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                    OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        minimumSize: const Size(0, 34),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                        ),
                                      ),
                                      onPressed: () => _merge(t, allTables),
                                      icon: const Icon(
                                        Icons.merge_type,
                                        size: 16,
                                      ),
                                      label: const Text(
                                        'Gộp',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ],
                                )
                              else
                                Text(
                                  queued
                                      ? 'Order chờ đồng bộ'
                                      : 'Chạm để mở order',
                                  style: TextStyle(
                                    color: fg,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}
