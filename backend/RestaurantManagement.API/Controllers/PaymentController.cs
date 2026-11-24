using System.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using RestaurantManagement.API.Data;
using RestaurantManagement.API.DTOs;
using RestaurantManagement.API.Models;

namespace RestaurantManagement.API.Controllers;

[ApiController, Route("api/payments"), Authorize(Roles = "Admin,Cashier")]
public sealed class PaymentController(RestaurantDbContext db, IConfiguration configuration) : ControllerBase
{
    [HttpGet("pending")]
    public async Task<IActionResult> Pending([FromQuery] int pageNumber = 1, [FromQuery] int pageSize = 20)
    {
        pageNumber = Math.Max(1, pageNumber); pageSize = Math.Clamp(pageSize, 1, 100);
        var q = db.Orders.AsNoTracking().Include(o => o.Table).Where(o => o.Status == "Served" || o.Status == "Ready");
        var count = await q.CountAsync(); var rows = await q.OrderBy(o => o.OrderDate).Skip((pageNumber-1)*pageSize).Take(pageSize)
            .Select(o => new { o.Id, o.OrderCode, o.Status, TableName = o.Table.TableName, o.OrderDate, o.SubTotal, o.TotalAmount,
                CustomerName = o.CustomerName, CustomerPhone = o.CustomerPhone,
                PaymentRequest = o.Payments.OrderByDescending(p => p.PaymentDate).Select(p => new { p.PaymentMethod, p.TransactionCode, p.Status }).FirstOrDefault() }).ToListAsync();
        return Ok(new PageResponse<object>(rows.Cast<object>().ToList(), pageNumber, pageSize, count));
    }

    [HttpPost("orders/{orderId:int}/checkout")]
    public async Task<IActionResult> Checkout(int orderId, PaymentRequest request)
    {
        await using var tx = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable);
        var order = await db.Orders.Include(o => o.Table).Include(o => o.Details).Include(o => o.Invoice).SingleOrDefaultAsync(o => o.Id == orderId);
        if (order is null) return NotFound();
        if (order.Invoice is not null || order.Status == "Completed") return Conflict(new { message = "Order has already been paid." });
        if (order.Status is not "Served" and not "Ready") return Conflict(new { message = "Only ready or served orders can be paid." });
        foreach (var line in order.Details) line.Status = "Served";
        var pendingRequest = await db.Payments.SingleOrDefaultAsync(p => p.OrderId == order.Id && p.Status == "PendingConfirmation");
        var transactionCode = request.TransactionCode?.Trim();
        if (string.IsNullOrWhiteSpace(transactionCode)) transactionCode = pendingRequest?.TransactionCode;
        if (request.PaymentMethod != "Cash" && string.IsNullOrWhiteSpace(request.TransactionCode))
        {
            if (string.IsNullOrWhiteSpace(transactionCode))
                return BadRequest(new { message = "A transaction reference is required for non-cash payments." });
        }
        if (request.Discount > order.SubTotal) return BadRequest(new { message = "Discount cannot exceed the subtotal." });
        var rate = configuration.GetValue<decimal>("Payments:TaxRate");
        if (rate is < 0 or > 100) return Problem("Payments:TaxRate must be between 0 and 100.", statusCode: 500);
        var taxableAmount = order.SubTotal - request.Discount;
        var tax = decimal.Round(taxableAmount * rate / 100m, 2, MidpointRounding.AwayFromZero);
        var total = taxableAmount + tax;
        if (total < 0) return BadRequest(new { message = "Payment total cannot be negative." });
        order.Discount = request.Discount; order.Tax = tax; order.TotalAmount = total; order.Status = "Completed";
        var otherOpenOrders = await db.Orders.AnyAsync(o => o.Id != order.Id && o.TableId == order.TableId &&
            o.Status != "Completed" && o.Status != "Cancelled");
        if (!otherOpenOrders)
        {
            order.Table.Status = "Cleaning";
            var seated = await db.CustomerReservations.Where(r => r.TableId == order.TableId && r.Status == "Seated" && r.EndsAtUtc > DateTime.UtcNow).ToListAsync();
            foreach (var r in seated) r.EndsAtUtc = DateTime.UtcNow;
        }
        var code = $"INV-{DateTime.UtcNow:yyyyMMddHHmmss}-{Guid.NewGuid():N}"[..31];
        if (pendingRequest is not null)
        {
            pendingRequest.PaymentMethod = request.PaymentMethod; pendingRequest.Amount = total;
            pendingRequest.PaymentDate = DateTime.UtcNow; pendingRequest.Status = "Completed";
            pendingRequest.TransactionCode = transactionCode;
        }
        else db.Payments.Add(new Payment { OrderId = order.Id, PaymentMethod = request.PaymentMethod, Amount = total,
            PaymentDate = DateTime.UtcNow, Status = "Completed", TransactionCode = transactionCode });
        db.Invoices.Add(new Invoice { OrderId = order.Id, InvoiceCode = code, TotalAmount = total, CreatedAt = DateTime.UtcNow });
        await db.SaveChangesAsync(); await tx.CommitAsync();
        return Ok(new { order.Id, order.OrderCode, order.Status, order.TotalAmount, Tax = tax, InvoiceCode = code });
    }

    [HttpGet("orders/{orderId:int}/history")]
    public async Task<IActionResult> History(int orderId) => Ok(await db.Payments.AsNoTracking()
        .Where(p => p.OrderId == orderId).OrderByDescending(p => p.PaymentDate)
        .Select(p => new { p.Id, p.PaymentMethod, p.Amount, p.PaymentDate, p.Status, p.TransactionCode }).ToListAsync());
}

