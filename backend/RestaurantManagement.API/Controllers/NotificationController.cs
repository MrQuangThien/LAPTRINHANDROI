using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using RestaurantManagement.API.Data;

namespace RestaurantManagement.API.Controllers;

[ApiController, Route("api/notifications"), Authorize]
public sealed class NotificationController(RestaurantDbContext db) : ControllerBase
{
    private sealed record NotificationDto(
        string EventKey,
        string Type,
        string Title,
        string Message,
        string Status,
        DateTime CreatedAtUtc,
        string Route,
        int? OrderId = null,
        Guid? TrackingCode = null
    );

    [HttpGet]
    public async Task<IActionResult> List()
    {
        if (!int.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var memberId))
            return Unauthorized();

        var member = await db.Members.AsNoTracking().Include(m => m.Role)
            .SingleOrDefaultAsync(m => m.Id == memberId && m.IsActive);
        if (member is null) return Unauthorized();

        var items = new List<NotificationDto>();

        if (member.Role.Name == "Customer")
        {
            var myReservations = await db.CustomerReservations.AsNoTracking()
                .Include(r => r.Table)
                .Where(r => r.CustomerPhone == member.Phone || r.CustomerName == member.FullName)
                .OrderByDescending(r => r.CreatedAtUtc)
                .Take(12)
                .Select(r => new
                {
                    r.Id,
                    r.ReservationCode,
                    Table = r.Table.TableName,
                    r.PartySize,
                    r.StartsAtUtc,
                    r.Status,
                    r.CreatedAtUtc
                })
                .ToListAsync();

            foreach (var r in myReservations)
            {
                var (title, msg) = r.Status switch
                {
                    "Seated" => ($"Đã nhận bàn {r.Table}", $"Bạn đã nhận bàn {r.Table} ({r.PartySize} khách). Chúc quý khách ngon miệng!"),
                    "Cancelled" => ($"Lịch đặt bàn {r.Table} đã hủy", $"Lịch hẹn bàn {r.Table} của bạn đã được hủy."),
                    _ => ($"Đặt bàn {r.Table} thành công", $"Giữ chỗ bàn {r.Table} ({r.PartySize} khách) lúc {r.StartsAtUtc.ToLocalTime():HH:mm dd/MM/yyyy}.")
                };
                items.Add(new NotificationDto(
                    $"cust-res-{r.Id}-{r.Status}",
                    "Reservation",
                    title,
                    msg,
                    r.Status,
                    r.CreatedAtUtc,
                    "/customer"
                ));
            }

            var myOrders = await db.Orders.AsNoTracking()
                .Include(o => o.Table)
                .Where(o => o.CustomerPhone == member.Phone || o.CustomerName == member.FullName)
                .OrderByDescending(o => o.OrderDate)
                .Take(15)
                .Select(o => new
                {
                    o.Id,
                    o.OrderCode,
                    o.ClientRequestId,
                    o.Status,
                    o.TotalAmount,
                    o.OrderDate,
                    Table = o.Table.TableName,
                    ItemCount = o.Details.Sum(d => d.Quantity)
                })
                .ToListAsync();

            foreach (var o in myOrders)
            {
                var (title, msg) = o.Status switch
                {
                    "Pending" => ($"Đã gửi order • Bàn {o.Table}", $"Đơn {o.OrderCode} ({o.ItemCount} món • {o.TotalAmount:N0}₫) đang chờ nhân viên xác nhận."),
                    "Confirmed" => ($"Quán đã xác nhận đơn • Bàn {o.Table}", $"Đơn {o.OrderCode} đã chuyển xuống Bếp để chuẩn bị."),
                    "Preparing" => ($"Bếp đang chế biến • Bàn {o.Table}", $"Các món trong đơn {o.OrderCode} đang được Bếp chế biến."),
                    "Ready" => ($"Món của bạn đã sẵn sàng! • Bàn {o.Table}", $"Đơn {o.OrderCode} đã chế biến xong và đang được phục vụ ra bàn."),
                    "Served" => ($"Đã phục vụ đủ món • Bàn {o.Table}", $"Đơn {o.OrderCode} đã lên món. Bạn có thể bấm Yêu cầu thanh toán hoặc quét mã QR."),
                    "Completed" => ($"Đã thanh toán • Bàn {o.Table}", $"Cảm ơn quý khách! Đơn {o.OrderCode} ({o.TotalAmount:N0}₫) đã hoàn tất thanh toán."),
                    _ => ($"Cập nhật đơn {o.OrderCode}", $"Trạng thái đơn hàng: {o.Status}.")
                };
                items.Add(new NotificationDto(
                    $"cust-ord-{o.Id}-{o.Status}",
                    "Order",
                    title,
                    msg,
                    o.Status,
                    o.OrderDate,
                    "/customer",
                    o.Id,
                    o.ClientRequestId
                ));
            }

            var orderedCust = items
                .OrderByDescending(x => x.CreatedAtUtc)
                .Take(25)
                .ToList();

            var activeCustCount = myOrders.Count(o => o.Status is "Pending" or "Confirmed" or "Preparing" or "Ready" or "Served");
            return Ok(new
            {
                summary = new
                {
                    pendingOrders = myOrders.Count(o => o.Status == "Pending"),
                    pendingReservations = myReservations.Count(r => r.Status == "Confirmed"),
                    readyOrders = myOrders.Count(o => o.Status == "Ready" || o.Status == "Served"),
                    pendingPayments = 0,
                    totalAttention = activeCustCount
                },
                items = orderedCust
            });
        }

        // Staff / Admin / Kitchen / Cashier notifications
        var pendingOrdersCount = await db.Orders.CountAsync(o => o.Status == "Pending");
        var pendingReservationsCount = await db.CustomerReservations.CountAsync(r =>
            r.Status == "Confirmed" && r.EndsAtUtc > DateTime.UtcNow);
        var readyOrdersCount = await db.Orders.CountAsync(o => o.Status == "Ready");
        var pendingPaymentsCount = await db.Payments.CountAsync(p => p.Status == "PendingConfirmation");

        var reservations = await db.CustomerReservations.AsNoTracking()
            .Include(r => r.Table)
            .OrderByDescending(r => r.CreatedAtUtc)
            .Take(12)
            .Select(r => new
            {
                r.Id,
                r.CustomerName,
                r.CustomerPhone,
                r.PartySize,
                r.StartsAtUtc,
                r.Status,
                r.CreatedAtUtc,
                Table = r.Table.TableName
            })
            .ToListAsync();

        foreach (var r in reservations)
        {
            var title = r.Status switch
            {
                "Confirmed" => $"Khách đặt bàn mới • {r.Table}",
                "Seated" => $"Khách đã nhận bàn • {r.Table}",
                "Cancelled" => $"Đã hủy lịch đặt bàn • {r.Table}",
                _ => $"Lịch đặt bàn • {r.Table}"
            };
            items.Add(new NotificationDto(
                $"res-{r.Id}-{r.Status}",
                "Reservation",
                title,
                $"Khách {r.CustomerName} ({r.CustomerPhone}) • {r.PartySize} khách • Giờ hẹn {r.StartsAtUtc.ToLocalTime():HH:mm dd/MM}.",
                r.Status,
                r.CreatedAtUtc,
                "/reservations"
            ));
        }

        var orders = await db.Orders.AsNoTracking()
            .Include(o => o.Table)
            .OrderByDescending(o => o.OrderDate)
            .Take(20)
            .Select(o => new
            {
                o.Id,
                o.OrderCode,
                o.ClientRequestId,
                o.CustomerName,
                o.CustomerPhone,
                o.Status,
                o.SubTotal,
                o.TotalAmount,
                o.OrderDate,
                Table = o.Table.TableName,
                ItemCount = o.Details.Sum(d => d.Quantity)
            })
            .ToListAsync();

        foreach (var o in orders)
        {
            var who = string.IsNullOrWhiteSpace(o.CustomerName)
                ? $"Bàn {o.Table}"
                : $"Khách {o.CustomerName} (Bàn {o.Table})";
            var (title, msg, route) = o.Status switch
            {
                "Pending" => (
                    $"Order mới chờ xác nhận • Bàn {o.Table}",
                    $"{who} vừa gửi order {o.OrderCode} ({o.ItemCount} món • {o.SubTotal:N0}₫).",
                    "/orders"
                ),
                "Confirmed" => (
                    $"Đơn chờ Bếp chế biến • Bàn {o.Table}",
                    $"Đơn {o.OrderCode} ({o.ItemCount} món) đã xác nhận và chuyển xuống Bếp.",
                    "/kitchen"
                ),
                "Preparing" => (
                    $"Bếp đang chế biến • Bàn {o.Table}",
                    $"Đơn {o.OrderCode} ({o.ItemCount} món) đang được Bếp chế biến.",
                    "/kitchen"
                ),
                "Ready" => (
                    $"Món sẵn sàng phục vụ! • Bàn {o.Table}",
                    $"Bếp báo đơn {o.OrderCode} (Bàn {o.Table}) đã làm xong, chờ mang ra bàn.",
                    "/orders"
                ),
                "Served" => (
                    $"Đã phục vụ • Chờ thanh toán Bàn {o.Table}",
                    $"Đơn {o.OrderCode} ({o.TotalAmount:N0}₫) đã phục vụ xong.",
                    "/payments"
                ),
                "Completed" => (
                    $"Hoàn tất đơn hàng • Bàn {o.Table}",
                    $"Đơn {o.OrderCode} ({o.TotalAmount:N0}₫) đã thanh toán và đóng bàn.",
                    $"/invoices/order/{o.Id}"
                ),
                _ => (
                    $"Đơn hàng {o.OrderCode} • Bàn {o.Table}",
                    $"{who} • Trạng thái: {o.Status}.",
                    "/orders"
                )
            };

            items.Add(new NotificationDto(
                $"ord-{o.Id}-{o.Status}",
                "Order",
                title,
                msg,
                o.Status,
                o.OrderDate,
                route,
                o.Id,
                o.ClientRequestId
            ));
        }

        var paymentRequests = await db.Payments.AsNoTracking()
            .Include(p => p.Order)
            .ThenInclude(o => o.Table)
            .Where(p => p.Status == "PendingConfirmation")
            .OrderByDescending(p => p.PaymentDate)
            .Take(10)
            .Select(p => new
            {
                p.Id,
                p.OrderId,
                p.PaymentMethod,
                p.Amount,
                p.TransactionCode,
                p.PaymentDate,
                p.Status,
                p.Order.OrderCode,
                p.Order.CustomerName,
                Table = p.Order.Table.TableName
            })
            .ToListAsync();

        foreach (var p in paymentRequests)
        {
            items.Add(new NotificationDto(
                $"payreq-{p.Id}-{p.Status}-{p.TransactionCode}",
                "PaymentRequest",
                $"Yêu cầu thanh toán • Bàn {p.Table}",
                $"Đơn {p.OrderCode} yêu cầu thanh toán {p.PaymentMethod} ({p.Amount:N0}₫){(string.IsNullOrWhiteSpace(p.TransactionCode) ? "" : $" • Mã GD: {p.TransactionCode}")}.",
                p.Status,
                p.PaymentDate,
                "/payments",
                p.OrderId
            ));
        }

        var ordered = items
            .OrderByDescending(x => x.CreatedAtUtc)
            .Take(30)
            .ToList();

        return Ok(new
        {
            summary = new
            {
                pendingOrders = pendingOrdersCount,
                pendingReservations = pendingReservationsCount,
                readyOrders = readyOrdersCount,
                pendingPayments = pendingPaymentsCount,
                totalAttention = pendingOrdersCount + pendingReservationsCount + readyOrdersCount + pendingPaymentsCount
            },
            items = ordered
        });
    }
}
