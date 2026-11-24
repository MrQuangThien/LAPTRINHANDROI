using System.Security.Claims;
using System.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using RestaurantManagement.API.Data;
using RestaurantManagement.API.DTOs;
using RestaurantManagement.API.Models;

namespace RestaurantManagement.API.Controllers;

[ApiController, Route("api/orders"), Authorize(Roles = "Admin,Staff,Cashier")]
public sealed class OrderController(RestaurantDbContext db) : ControllerBase
{
    private static readonly string[] ActiveStatuses = ["Pending", "Confirmed", "Preparing", "Ready", "Served"];

    [HttpGet]
    public async Task<ActionResult<PageResponse<object>>> List([FromQuery] int pageNumber = 1, [FromQuery] int pageSize = 20,
        [FromQuery] string? search = null, [FromQuery] string? status = null, [FromQuery] DateTime? from = null, [FromQuery] DateTime? to = null)
    {
        pageNumber = Math.Max(1, pageNumber); pageSize = Math.Clamp(pageSize, 1, 100);
        var q = db.Orders.AsNoTracking().Include(o => o.Table).ThenInclude(t => t.Area).Include(o => o.Member).AsQueryable();
        if (!string.IsNullOrWhiteSpace(search)) q = q.Where(o => o.OrderCode.Contains(search) || o.Table.TableName.Contains(search) || o.Member.FullName.Contains(search) || (o.CustomerName != null && o.CustomerName.Contains(search)));
        if (!string.IsNullOrWhiteSpace(status)) q = q.Where(o => o.Status == status);
        if (from.HasValue) q = q.Where(o => o.OrderDate >= from.Value);
        if (to.HasValue) q = q.Where(o => o.OrderDate < to.Value.Date.AddDays(1));
        var count = await q.CountAsync();
        var rows = await q.OrderByDescending(o => o.OrderDate).Skip((pageNumber - 1) * pageSize).Take(pageSize)
            .Select(o => new { o.Id, o.OrderCode, TableName = o.Table.TableName, MemberName = o.CustomerName ?? o.Member.FullName,
                o.OrderDate, o.Status, o.SubTotal, o.Discount, o.Tax, o.TotalAmount }).ToListAsync();
        return Ok(new PageResponse<object>(rows.Cast<object>().ToList(), pageNumber, pageSize, count));
    }

    [HttpGet("{id:int}")]
    public async Task<ActionResult<OrderResponse>> Get(int id)
    {
        var order = await Load(id); return order is null ? NotFound() : Ok(ToResponse(order));
    }

    [HttpPost]
    public async Task<ActionResult<OrderResponse>> Create(CreateOrderRequest request)
    {
        if (request.ClientRequestId == Guid.Empty) return BadRequest(new { message = "ClientRequestId is required for idempotency." });
        if (!int.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var memberId)) return Unauthorized();
        await using var tx = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable);
        var duplicate = await db.Orders.Include(o => o.Table).Include(o => o.Member).Include(o => o.Details).ThenInclude(d => d.Product)
            .SingleOrDefaultAsync(o => o.ClientRequestId == request.ClientRequestId);
        if (duplicate is not null)
        {
            var sameRequest = duplicate.MemberId == memberId && duplicate.TableId == request.TableId &&
                duplicate.Note == request.Note?.Trim() && duplicate.Details.Count == request.Items.Count &&
                duplicate.Details.All(d => request.Items.Any(i => i.ProductId == d.ProductId &&
                    i.Quantity == d.Quantity && i.Note?.Trim() == d.Note));
            if (!sameRequest) return Conflict(new { message = "This ClientRequestId was already used for a different order." });
            await tx.CommitAsync(); return Ok(ToResponse(duplicate));
        }
        var table = await db.Tables.SingleOrDefaultAsync(t => t.Id == request.TableId);
        if (table is null) return NotFound(new { message = "Table not found." });
        if (table.Status is not "Available" and not "Reserved" || await db.Orders.AnyAsync(o => o.TableId == table.Id && ActiveStatuses.Contains(o.Status)))
            return Conflict(new { message = "Table already has an active order." });
        var upcomingReservations = await db.CustomerReservations
            .Where(r => r.TableId == table.Id && r.Status == "Confirmed" &&
                r.StartsAtUtc < DateTime.UtcNow.AddMinutes(90) && r.EndsAtUtc > DateTime.UtcNow)
            .ToListAsync();
        foreach (var res in upcomingReservations) res.Status = "Seated";
        var lines = await BuildLines(request.Items);
        if (lines.Error is not null) return BadRequest(new { message = lines.Error });
        var orderItems = lines.Items!;
        var shortCode = $"ORD-{Random.Shared.Next(100000, 999999)}";
        while (await db.Orders.AnyAsync(o => o.OrderCode == shortCode))
            shortCode = $"ORD-{Random.Shared.Next(100000, 999999)}";
        var order = new Order { OrderCode = shortCode,
            ClientRequestId = request.ClientRequestId, TableId = table.Id, MemberId = memberId,
            Status = "Pending", Note = request.Note?.Trim(), OrderDate = DateTime.UtcNow,
            Details = orderItems, SubTotal = orderItems.Sum(x => x.TotalPrice), TotalAmount = orderItems.Sum(x => x.TotalPrice) };
        table.Status = "Occupied"; db.Orders.Add(order);
        await db.SaveChangesAsync(); await tx.CommitAsync();
        var loaded = await Load(order.Id); return CreatedAtAction(nameof(Get), new { id = order.Id }, ToResponse(loaded!));
    }

    [HttpPost("{id:int}/items")]
    public async Task<IActionResult> AddItems(int id, AddOrderItemsRequest request)
    {
        var order = await db.Orders.Include(o => o.Details).Include(o => o.Payments).SingleOrDefaultAsync(o => o.Id == id);
        if (order is null) return NotFound();
        if (!ActiveStatuses.Contains(order.Status)) return Conflict(new { message = "Items can only be added to an active order." });
        var lines = await BuildLines(request.Items); if (lines.Error is not null) return BadRequest(new { message = lines.Error });
        var extraNote = string.IsNullOrWhiteSpace(request.Note) ? null : request.Note.Trim();
        foreach (var line in lines.Items!)
        {
            if (string.IsNullOrWhiteSpace(line.Note) && extraNote is not null) line.Note = extraNote;
            order.Details.Add(line);
        }
        if (order.Status is "Ready" or "Served") order.Status = "Confirmed";
        Recalculate(order);
        foreach (var p in order.Payments.Where(p => p.Status == "PendingConfirmation")) p.Amount = order.TotalAmount;
        await db.SaveChangesAsync(); return Ok(ToResponse((await Load(id))!));
    }

    [HttpPost("{id:int}/confirm")]
    public async Task<IActionResult> Confirm(int id)
    {
        var order = await db.Orders.FindAsync(id); if (order is null) return NotFound();
        if (order.Status == "Pending") order.Status = "Confirmed";
        else if (order.Status != "Confirmed") return Conflict(new { message = "Only pending orders can be confirmed." });
        await db.SaveChangesAsync(); return NoContent();
    }

    [HttpPost("{id:int}/cancel")]
    public async Task<IActionResult> Cancel(int id)
    {
        var order = await db.Orders.Include(o => o.Table).SingleOrDefaultAsync(o => o.Id == id); if (order is null) return NotFound();
        if (order.Status is "Completed" or "Cancelled") return Conflict(new { message = "This order is already closed." });
        order.Status = "Cancelled";
        if (!await db.Orders.AnyAsync(o => o.Id != id && o.TableId == order.TableId && ActiveStatuses.Contains(o.Status)))
        {
            order.Table.Status = "Cleaning";
            var seated = await db.CustomerReservations.Where(r => r.TableId == order.TableId && r.Status == "Seated" && r.EndsAtUtc > DateTime.UtcNow).ToListAsync();
            foreach (var r in seated) r.EndsAtUtc = DateTime.UtcNow;
        }
        await db.SaveChangesAsync(); return NoContent();
    }

    [HttpPost("{id:int}/served")]
    public async Task<IActionResult> MarkServed(int id)
    {
        var order = await db.Orders.Include(o => o.Details).SingleOrDefaultAsync(o => o.Id == id);
        if (order is null) return NotFound();
        if (order.Status == "Served") return NoContent();
        if (order.Status != "Ready") return Conflict(new { message = "Only ready orders can be marked served." });
        order.Status = "Served";
        foreach (var line in order.Details) line.Status = "Served";
        await db.SaveChangesAsync();
        return NoContent();
    }
    private async Task<(List<OrderDetail>? Items, string? Error)> BuildLines(IEnumerable<OrderLineRequest> requests)
    {
        var list = new List<OrderDetail>();
        foreach (var item in requests)
        {
            if (item.Quantity is < 1 or > 99) return (null, "Quantity must be from 1 to 99.");
            var product = await db.Products.SingleOrDefaultAsync(p => p.Id == item.ProductId && p.IsAvailable && p.Category.IsActive);
            if (product is null) return (null, $"Product {item.ProductId} is missing or unavailable.");
            list.Add(new OrderDetail { ProductId = product.Id, Quantity = item.Quantity, UnitPrice = product.Price,
                TotalPrice = product.Price * item.Quantity, Note = item.Note?.Trim(), Status = "Pending" });
        }
        return (list, null);
    }
    private static void Recalculate(Order order)
    {
        order.SubTotal = order.Details.Sum(x => x.TotalPrice);
        order.TotalAmount = order.SubTotal - order.Discount + order.Tax;
    }
    private Task<Order?> Load(int id) => db.Orders.AsNoTracking().Include(o => o.Table).Include(o => o.Member)
        .Include(o => o.Details).ThenInclude(d => d.Product).SingleOrDefaultAsync(o => o.Id == id);
    private static OrderResponse ToResponse(Order o) => new(o.Id, o.OrderCode, o.TableId, o.Table.TableName,
        o.CustomerName ?? o.Member.FullName, o.OrderDate, o.Status, o.SubTotal, o.Discount, o.Tax, o.TotalAmount, o.Note,
        o.Details.Select(d => new OrderDetailResponse(d.Id, d.ProductId, d.Product.Name, d.Quantity,
            d.UnitPrice, d.TotalPrice, d.Note, d.Status)).ToList());
}




