using System.Data;
using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using RestaurantManagement.API.Data;
using RestaurantManagement.API.DTOs;
using RestaurantManagement.API.Models;

namespace RestaurantManagement.API.Controllers;

[ApiController, Route("api/customer")]
public sealed class CustomerController(RestaurantDbContext db) : ControllerBase
{
    private static readonly string[] ReservationStatuses = ["Confirmed", "Seated"];
    private static readonly string[] ActiveOrderStatuses = ["Pending", "Confirmed", "Preparing", "Ready", "Served"];

    [HttpGet("info")]
    [AllowAnonymous]
    public async Task<IActionResult> RestaurantInfo()
    {
        var areas = await db.Areas.AsNoTracking().OrderBy(a => a.Name)
            .Select(a => new { a.Id, a.Name, a.Description, TableCount = a.Tables.Count,
                SeatCount = a.Tables.Sum(t => (int?)t.Capacity) ?? 0 })
            .ToListAsync();
        var productCount = await db.Products.CountAsync(p => p.IsAvailable && p.Category.IsActive);
        var categoryCount = await db.Categories.CountAsync(c => c.IsActive);
        var tableCount = await db.Tables.CountAsync();
        var availableTables = await db.Tables.CountAsync(t => t.Status == "Available");
        return Ok(new
        {
            name = "Bếp Nhà Coffee & Kitchen",
            tagline = "Ẩm thực Việt ấm cúng & Cà phê rang mộc thủ công",
            story = "Bếp Nhà ra đời với mong muốn mang đến một không gian gần gũi như bữa cơm gia đình kết hợp cùng quầy cà phê Arabica Cầu Đất rang mộc nguyên chất. Mỗi món ăn và thức uống đều được chuẩn bị tươi mới ngay khi bạn gọi món.",
            address = "128 Nguyễn Huệ, Quận 1, TP. Hồ Chí Minh",
            phone = "0901 234 567",
            email = "lienhe@bepnha.local",
            openingHours = "07:00 – 22:30 (Tất cả các ngày trong tuần)",
            wifiName = "BepNha_FreeWifi_5G",
            wifiPassword = "bepnhachaoquykhach",
            highlights = new[]
            {
                "Hạt cà phê Arabica Cầu Đất rang mộc 100%",
                "Bếp mở chế biến tươi mới theo từng đơn",
                "Không gian Sân vườn xanh mát & Phòng máy lạnh",
                "Đặt bàn trực tuyến giữ chỗ miễn phí 90 phút",
                "Thanh toán linh hoạt: Tiền mặt, Chuyển khoản, VietQR",
                "Wi-Fi tốc độ cao & ổ cắm điện tại mọi bàn"
            },
            stats = new
            {
                areaCount = areas.Count,
                tableCount,
                availableTables,
                totalSeats = areas.Sum(a => a.SeatCount),
                productCount,
                categoryCount
            },
            areas
        });
    }

    [HttpGet("blogs")]
    [AllowAnonymous]
    public async Task<IActionResult> Blogs([FromQuery] string? category = null, [FromQuery] string? search = null)
    {
        var q = db.BlogPosts.AsNoTracking().Where(b => b.IsPublished);
        if (!string.IsNullOrWhiteSpace(category)) q = q.Where(b => b.Category == category);
        if (!string.IsNullOrWhiteSpace(search)) q = q.Where(b => b.Title.Contains(search) || b.Summary.Contains(search));
        var rows = await q.OrderByDescending(b => b.IsFeatured).ThenByDescending(b => b.PublishedAtUtc)
            .Select(b => new { b.Id, b.Title, b.Category, b.Summary, b.Content, b.ImageUrl,
                b.AuthorName, b.ReadingMinutes, b.IsFeatured, b.PublishedAtUtc })
            .ToListAsync();
        return Ok(rows);
    }

    [HttpPost("blogs"), Authorize(Roles = "Admin")]
    public async Task<IActionResult> CreateBlog(BlogPostRequest request)
    {
        var post = new BlogPost
        {
            Title = request.Title.Trim(),
            Category = request.Category.Trim(),
            Summary = request.Summary.Trim(),
            Content = request.Content.Trim(),
            ImageUrl = string.IsNullOrWhiteSpace(request.ImageUrl) ? null : request.ImageUrl.Trim(),
            AuthorName = string.IsNullOrWhiteSpace(request.AuthorName) ? "Bếp Nhà" : request.AuthorName.Trim(),
            ReadingMinutes = request.ReadingMinutes,
            IsFeatured = request.IsFeatured,
            IsPublished = true,
            PublishedAtUtc = DateTime.UtcNow
        };
        db.BlogPosts.Add(post);
        await db.SaveChangesAsync();
        return Ok(post);
    }

    [HttpDelete("blogs/{id:int}"), Authorize(Roles = "Admin")]
    public async Task<IActionResult> DeleteBlog(int id)
    {
        var post = await db.BlogPosts.FindAsync(id);
        if (post is null) return NotFound();
        db.BlogPosts.Remove(post);
        await db.SaveChangesAsync();
        return NoContent();
    }

    [HttpGet("my-activity"), Authorize]
    public async Task<IActionResult> MyActivity()
    {
        if (!int.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var memberId))
            return Unauthorized();
        var member = await db.Members.AsNoTracking().SingleOrDefaultAsync(m => m.Id == memberId && m.IsActive);
        if (member is null) return Unauthorized();
        var orders = await db.Orders.AsNoTracking().Include(o => o.Table).Include(o => o.Invoice)
            .Where(o => o.CustomerPhone == member.Phone || o.MemberId == member.Id)
            .OrderByDescending(o => o.OrderDate)
            .Take(20)
            .Select(o => new { o.Id, o.ClientRequestId, o.OrderCode, o.Status, o.OrderDate,
                o.SubTotal, o.Discount, o.Tax, o.TotalAmount, Table = o.Table.TableName,
                HasInvoice = o.Invoice != null })
            .ToListAsync();
        var reservations = await db.CustomerReservations.AsNoTracking().Include(r => r.Table).ThenInclude(t => t.Area)
            .Where(r => r.CustomerPhone == member.Phone)
            .OrderByDescending(r => r.StartsAtUtc)
            .Take(20)
            .Select(r => new { r.Id, r.ReservationCode, r.CustomerName, r.CustomerPhone,
                r.PartySize, r.StartsAtUtc, r.EndsAtUtc, r.Status, r.Note,
                TableId = r.TableId, Table = r.Table.TableName, Area = r.Table.Area.Name })
            .ToListAsync();
        return Ok(new { member.FullName, member.Email, member.Phone, orders, reservations });
    }

    [HttpGet("tables")]
    [AllowAnonymous]
    public async Task<IActionResult> Tables([FromQuery] DateTimeOffset? startsAt = null, [FromQuery] int partySize = 1)
    {
        if (partySize is < 1 or > 100) return BadRequest(new { message = "Party size must be from 1 to 100." });
        var start = (startsAt ?? DateTimeOffset.UtcNow.AddHours(2)).UtcDateTime;
        var end = start.AddMinutes(90);
        var rows = await db.Tables.AsNoTracking().Include(t => t.Area)
            .Where(t => t.Capacity >= partySize && t.Status == "Available" &&
                !db.Orders.Any(o => o.TableId == t.Id && ActiveOrderStatuses.Contains(o.Status)) &&
                !db.CustomerReservations.Any(r => r.TableId == t.Id && ReservationStatuses.Contains(r.Status) &&
                    r.StartsAtUtc < end && r.EndsAtUtc > start))
            .OrderBy(t => t.Capacity).ThenBy(t => t.Area.Name).ThenBy(t => t.TableName)
            .Select(t => new { t.Id, t.TableName, Area = t.Area.Name, t.Capacity })
            .ToListAsync();
        return Ok(rows);
    }

    [HttpPost("reservations")]
    [Authorize]
    public async Task<IActionResult> Reserve(CustomerReservationRequest request)
    {
        var start = request.StartsAt.UtcDateTime;
        if (start < DateTime.UtcNow.AddMinutes(-5) || start > DateTime.UtcNow.AddDays(30))
            return BadRequest(new { message = "Thời gian đặt bàn phải nằm trong vòng 30 ngày tới." });
        await using var tx = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable);
        var table = await db.Tables.SingleOrDefaultAsync(t => t.Id == request.TableId);
        if (table is null) return NotFound(new { message = "Không tìm thấy bàn đã chọn." });
        if (request.PartySize > table.Capacity) return Conflict(new { message = "Bàn đã chọn không đủ chỗ cho số lượng khách này." });
        if (table.Status != "Available" || await db.Orders.AnyAsync(o => o.TableId == table.Id && ActiveOrderStatuses.Contains(o.Status)))
            return Conflict(new { message = "Bàn này hiện không còn trống để đặt trước." });
        var end = start.AddMinutes(90);
        var overlap = await db.CustomerReservations.AnyAsync(r => r.TableId == table.Id &&
            ReservationStatuses.Contains(r.Status) && r.StartsAtUtc < end && r.EndsAtUtc > start);
        if (overlap) return Conflict(new { message = "Bàn này đã có lịch đặt trong khung giờ bạn chọn." });

        var reservation = new CustomerReservation {
            ReservationCode = Guid.NewGuid(), TableId = table.Id,
            CustomerName = request.CustomerName.Trim(), CustomerPhone = request.CustomerPhone.Trim(),
            PartySize = request.PartySize, StartsAtUtc = start, EndsAtUtc = end,
            Status = "Confirmed", Note = request.Note?.Trim()
        };
        if (start <= DateTime.UtcNow.AddMinutes(90) && table.Status == "Available")
        {
            table.Status = "Reserved";
        }
        db.CustomerReservations.Add(reservation);
        await db.SaveChangesAsync(); await tx.CommitAsync();
        return Ok(new { reservation.ReservationCode, reservation.CustomerName, reservation.CustomerPhone,
            Table = table.TableName, Area = (await db.Areas.Where(a => a.Id == table.AreaId).Select(a => a.Name).SingleAsync()),
            reservation.PartySize, reservation.StartsAtUtc, reservation.Status });
    }

    [HttpGet("reservations/{code:guid}")]
    [AllowAnonymous]
    public async Task<IActionResult> Reservation(Guid code)
    {
        var row = await db.CustomerReservations.AsNoTracking().Include(r => r.Table).ThenInclude(t => t.Area)
            .Where(r => r.ReservationCode == code)
            .Select(r => new { r.ReservationCode, r.CustomerName, r.PartySize, r.StartsAtUtc, r.Status,
                Table = r.Table.TableName, Area = r.Table.Area.Name }).SingleOrDefaultAsync();
        return row is null ? NotFound() : Ok(row);
    }

    [HttpGet("reservations"), Authorize(Roles = "Admin,Staff")]
    public async Task<IActionResult> StaffReservations([FromQuery] DateTimeOffset? from = null, [FromQuery] DateTimeOffset? to = null)
    {
        var start = (from ?? DateTimeOffset.UtcNow.AddDays(-1)).UtcDateTime;
        var end = (to ?? DateTimeOffset.UtcNow.AddDays(31)).UtcDateTime;
        return Ok(await db.CustomerReservations.AsNoTracking().Include(r => r.Table)
            .Where(r => r.StartsAtUtc >= start && r.StartsAtUtc < end)
            .OrderBy(r => r.StartsAtUtc)
            .Select(r => new { r.Id, r.CustomerName, r.CustomerPhone, r.PartySize, r.StartsAtUtc, r.EndsAtUtc,
                r.Status, Table = r.Table.TableName, r.Note }).ToListAsync());
    }

    [HttpPatch("reservations/{id:int}/status"), Authorize(Roles = "Admin,Staff")]
    public async Task<IActionResult> ReservationStatus(int id, [FromBody] UpdateReservationStatusRequest request)
    {
        var status = request.Status.Trim();
        if (status is not "Confirmed" and not "Seated" and not "Cancelled" and not "NoShow")
            return BadRequest(new { message = "Trạng thái đặt bàn không hợp lệ." });
        var row = await db.CustomerReservations.Include(r => r.Table).SingleOrDefaultAsync(r => r.Id == id);
        if (row is null) return NotFound(new { message = "Không tìm thấy lịch đặt bàn." });
        if (row.Status is "Cancelled" or "NoShow") return Conflict(new { message = "Lịch đặt bàn đã đóng, không thể thay đổi." });
        row.Status = status;
        if (status == "Seated" && row.Table.Status == "Available")
        {
            row.Table.Status = "Reserved";
        }
        else if (status is "Cancelled" or "NoShow" && row.Table.Status == "Reserved")
        {
            var hasOtherActiveReservation = await db.CustomerReservations.AnyAsync(r =>
                r.Id != id && r.TableId == row.TableId && ReservationStatuses.Contains(r.Status) && r.EndsAtUtc > DateTime.UtcNow);
            if (!hasOtherActiveReservation) row.Table.Status = "Available";
        }
        await db.SaveChangesAsync();
        return NoContent();
    }

    [HttpPost("orders")]
    [Authorize]
    public async Task<IActionResult> CreateOrder(CustomerOrderRequest request)
    {
        if (request.ClientRequestId == Guid.Empty) return BadRequest(new { message = "Thiếu mã theo dõi đơn hàng." });
        await using var tx = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable);
        CustomerReservation? reservation = null;
        if (!string.IsNullOrWhiteSpace(request.ReservationCode))
        {
            var rawResCode = request.ReservationCode.Trim();
            var phone = request.CustomerPhone.Trim();
            if (Guid.TryParse(rawResCode, out var resGuid))
            {
                reservation = await db.CustomerReservations.SingleOrDefaultAsync(r =>
                    r.ReservationCode == resGuid && r.CustomerPhone == phone);
            }
            else if (int.TryParse(rawResCode, out var resId))
            {
                reservation = await db.CustomerReservations.SingleOrDefaultAsync(r =>
                    r.Id == resId && r.CustomerPhone == phone);
            }
            else
            {
                return BadRequest(new { message = "Mã đặt bàn không hợp lệ. Vui lòng nhập đúng mã đặt bàn đã nhận." });
            }
            if (reservation is null) return Conflict(new { message = "Mã đặt bàn hoặc số điện thoại không khớp. Vui lòng kiểm tra lại." });
        }
        var tableId = reservation?.TableId ?? request.TableId;
        var duplicate = await db.Orders.Include(o => o.Table).Include(o => o.Details)
            .SingleOrDefaultAsync(o => o.ClientRequestId == request.ClientRequestId && o.CustomerPhone != null);
        if (duplicate is not null)
        {
            var sameRequest = duplicate.CustomerPhone == request.CustomerPhone.Trim() && duplicate.CustomerName == request.CustomerName.Trim() &&
                duplicate.TableId == tableId && duplicate.Note == request.Note?.Trim() && duplicate.Details.Count == request.Items.Count &&
                duplicate.Details.All(d => request.Items.Any(i => i.ProductId == d.ProductId && i.Quantity == d.Quantity && i.Note?.Trim() == d.Note));
            if (!sameRequest) return Conflict(new { message = "This tracking code was already used for a different order." });
            await tx.CommitAsync();
            return Ok(new { duplicate.ClientRequestId, duplicate.OrderCode, duplicate.Status, duplicate.SubTotal, Table = duplicate.Table.TableName });
        }
        if (reservation is not null)
        {
            if (reservation.Status is not "Confirmed" and not "Seated")
                return Conflict(new { message = "Lịch đặt bàn này đã đóng hoặc đã hủy." });
            var now = DateTime.UtcNow;
            if (now > reservation.EndsAtUtc)
                return Conflict(new { message = "Lịch đặt bàn này đã quá giờ giữ chỗ." });
            if (request.PartySize > reservation.PartySize)
                return Conflict(new { message = "Số khách vượt quá số lượng đã đặt bàn." });
            if (request.TableId != 0 && request.TableId != reservation.TableId)
                return Conflict(new { message = "Bàn đặt món không khớp với bàn đã giữ chỗ." });
        }
        var table = await db.Tables.SingleOrDefaultAsync(t => t.Id == tableId);
        if (table is null) return NotFound(new { message = "Không tìm thấy bàn đã chọn." });
        if (request.PartySize > table.Capacity) return Conflict(new { message = "Bàn đã chọn không đủ chỗ cho số lượng khách này." });
        if (await db.Orders.AnyAsync(o => o.TableId == table.Id && ActiveOrderStatuses.Contains(o.Status)))
            return Conflict(new { message = "Bàn này đang có đơn phục vụ. Vui lòng tải lại danh sách bàn." });
        if (reservation is null && (table.Status != "Available" || await db.CustomerReservations.AnyAsync(r => r.TableId == table.Id && ReservationStatuses.Contains(r.Status) &&
            r.StartsAtUtc < DateTime.UtcNow.AddHours(2) && r.EndsAtUtc > DateTime.UtcNow))
            ) return Conflict(new { message = "Bàn này sắp có khách đặt trước, không thể nhận thêm order mới." });
        var adminId = await db.Members.Where(m => m.IsActive && m.Role.Name == "Admin")
            .OrderBy(m => m.Id).Select(m => (int?)m.Id).FirstOrDefaultAsync();
        if (adminId is null) return Problem("No active system account is available for customer orders.", statusCode: 503);

        var details = new List<OrderDetail>();
        foreach (var line in request.Items)
        {
            if (line.Quantity is < 1 or > 99) return BadRequest(new { message = "Each item quantity must be from 1 to 99." });
            var product = await db.Products.SingleOrDefaultAsync(p => p.Id == line.ProductId && p.IsAvailable && p.Category.IsActive);
            if (product is null) return BadRequest(new { message = $"A selected product is unavailable (id {line.ProductId})." });
            details.Add(new OrderDetail { ProductId = product.Id, Quantity = line.Quantity,
                UnitPrice = product.Price, TotalPrice = product.Price * line.Quantity,
                Note = line.Note?.Trim(), Status = "Pending" });
        }
        var subtotal = details.Sum(d => d.TotalPrice);
        var shortCode = $"ORD-{Random.Shared.Next(100000, 999999)}";
        while (await db.Orders.AnyAsync(o => o.OrderCode == shortCode))
            shortCode = $"ORD-{Random.Shared.Next(100000, 999999)}";
        var order = new Order { OrderCode = shortCode,
            ClientRequestId = request.ClientRequestId, TableId = table.Id, MemberId = adminId.Value,
            CustomerName = request.CustomerName.Trim(), CustomerPhone = request.CustomerPhone.Trim(),
            Note = request.Note?.Trim(), OrderDate = DateTime.UtcNow, Status = "Pending",
            SubTotal = subtotal, TotalAmount = subtotal, Details = details };
        table.Status = "Occupied";
        if (reservation is not null) reservation.Status = "Seated";
        db.Orders.Add(order);
        await db.SaveChangesAsync(); await tx.CommitAsync();
        return Ok(new { order.ClientRequestId, order.OrderCode, order.Status, order.SubTotal, Table = table.TableName });
    }

    [HttpGet("orders/{trackingCode}")]
    [Authorize]
    public async Task<IActionResult> TrackOrder(string trackingCode)
    {
        if (!int.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var memberId))
            return Unauthorized();
        var member = await db.Members.AsNoTracking().SingleOrDefaultAsync(m => m.Id == memberId && m.IsActive);
        if (member is null) return Unauthorized();

        var raw = trackingCode.Trim();
        var isGuid = Guid.TryParse(raw, out var guid);
        var order = await db.Orders.AsNoTracking().Include(o => o.Table).Include(o => o.Details).ThenInclude(d => d.Product)
            .Where(o => (o.MemberId == member.Id || (!string.IsNullOrEmpty(member.Phone) && o.CustomerPhone == member.Phone))
                && (isGuid ? o.ClientRequestId == guid : o.OrderCode == raw))
            .Select(o => new { o.ClientRequestId, o.OrderCode, o.CustomerName, o.Status, o.OrderDate,
                o.SubTotal, o.Discount, o.Tax, o.TotalAmount, Table = o.Table.TableName,
                Items = o.Details.Select(d => new { Product = d.Product.Name, d.Quantity, d.UnitPrice, d.TotalPrice, d.Note }),
                PaymentRequest = o.Payments.OrderByDescending(p => p.PaymentDate).Select(p => new {
                    p.Status, p.PaymentMethod, p.TransactionCode }).FirstOrDefault(),
                Invoice = o.Invoice == null ? null : new { o.Invoice.InvoiceCode, o.Invoice.TotalAmount, o.Invoice.CreatedAt } })
            .SingleOrDefaultAsync();
        return order is null ? NotFound(new { message = "Không tìm thấy đơn hàng thuộc tài khoản của bạn với mã theo dõi này." }) : Ok(order);
    }

    [HttpPost("orders/{trackingCode}/payment-request")]
    [Authorize]
    public async Task<IActionResult> RequestPayment(string trackingCode, CustomerPaymentRequest request)
    {
        if (!int.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var memberId))
            return Unauthorized();
        var member = await db.Members.AsNoTracking().SingleOrDefaultAsync(m => m.Id == memberId && m.IsActive);
        if (member is null) return Unauthorized();

        var raw = trackingCode.Trim();
        var isGuid = Guid.TryParse(raw, out var guid);
        await using var tx = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable);
        var order = await db.Orders.SingleOrDefaultAsync(o =>
            (o.MemberId == member.Id || (!string.IsNullOrEmpty(member.Phone) && o.CustomerPhone == member.Phone))
            && (isGuid ? o.ClientRequestId == guid : o.OrderCode == raw));
        if (order is null) return NotFound(new { message = "Không tìm thấy đơn hàng thuộc tài khoản của bạn." });
        if (order.Status == "Completed" || await db.Invoices.AnyAsync(i => i.OrderId == order.Id))
            return Conflict(new { message = "Đơn hàng này đã được thanh toán." });
        if (order.Status is not "Served" and not "Ready") return Conflict(new { message = "Bạn có thể yêu cầu thanh toán sau khi món đã sẵn sàng hoặc đã phục vụ." });
        if (request.PaymentMethod != "Cash" && string.IsNullOrWhiteSpace(request.TransactionCode))
            return BadRequest(new { message = "Enter the transaction reference after transferring money." });
        var existingPending = await db.Payments.SingleOrDefaultAsync(p => p.OrderId == order.Id && p.Status == "PendingConfirmation");
        if (existingPending is not null)
        {
            existingPending.PaymentMethod = request.PaymentMethod;
            existingPending.Amount = order.TotalAmount;
            existingPending.PaymentDate = DateTime.UtcNow;
            existingPending.TransactionCode = request.TransactionCode?.Trim();
        }
        else
        {
            db.Payments.Add(new Payment { OrderId = order.Id, PaymentMethod = request.PaymentMethod,
                Amount = order.TotalAmount, PaymentDate = DateTime.UtcNow, Status = "PendingConfirmation",
                TransactionCode = request.TransactionCode?.Trim() });
        }
        await db.SaveChangesAsync(); await tx.CommitAsync();
        return Accepted(new { message = "Payment request sent. The cashier must confirm receipt before an invoice is issued." });
    }
}
