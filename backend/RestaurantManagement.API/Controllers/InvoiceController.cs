using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using RestaurantManagement.API.Data;

namespace RestaurantManagement.API.Controllers;

[ApiController, Route("api/invoices"), Authorize]
public sealed class InvoiceController(RestaurantDbContext db) : ControllerBase
{
    [HttpGet("guest/{trackingCode}")]
    public async Task<IActionResult> Guest(string trackingCode)
    {
        if (!int.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var memberId))
            return Unauthorized();
        var member = await db.Members.AsNoTracking().SingleOrDefaultAsync(m => m.Id == memberId && m.IsActive);
        if (member is null) return Unauthorized();

        var raw = trackingCode.Trim();
        var isGuid = Guid.TryParse(raw, out var guid);
        var invoice = await db.Invoices.AsNoTracking().AsSplitQuery()
            .Where(i => (i.Order.MemberId == member.Id || (!string.IsNullOrEmpty(member.Phone) && i.Order.CustomerPhone == member.Phone))
                && (isGuid ? i.Order.ClientRequestId == guid : i.Order.OrderCode == raw))
            .Select(i => new { i.InvoiceCode, i.CreatedAt, i.TotalAmount,
                i.Order.SubTotal, i.Order.Discount, i.Order.Tax, i.Order.OrderCode,
                Table = i.Order.Table.TableName, CustomerName = i.Order.CustomerName,
                Items = i.Order.Details.Select(d => new { Product = d.Product.Name, d.Quantity, d.UnitPrice, d.TotalPrice }),
                Payments = i.Order.Payments.Where(p => p.Status == "Completed")
                    .Select(p => new { p.PaymentMethod, p.Amount, p.PaymentDate, p.TransactionCode }) })
            .SingleOrDefaultAsync();
        return invoice is null ? NotFound(new { message = "Không tìm thấy hóa đơn thuộc tài khoản của bạn cho đơn hàng này." }) : Ok(invoice);
    }

    [HttpGet("{id:int}"), Authorize(Roles = "Admin,Staff,Cashier")]
    public async Task<IActionResult> Get(int id)
    {
        var invoice = await db.Invoices.AsNoTracking().Include(i => i.Order).ThenInclude(o => o.Table)
            .Include(i => i.Order).ThenInclude(o => o.Details).ThenInclude(d => d.Product)
            .Include(i => i.Order).ThenInclude(o => o.Member).SingleOrDefaultAsync(i => i.Id == id);
        if (invoice is null) return NotFound();
        var payments = await db.Payments.AsNoTracking()
            .Where(p => p.OrderId == invoice.OrderId && p.Status == "Completed")
            .Select(p => new { p.PaymentMethod, p.Amount, p.PaymentDate, p.TransactionCode })
            .ToListAsync();
        return Ok(new { invoice.Id, invoice.InvoiceCode, invoice.CreatedAt, invoice.TotalAmount,
            invoice.Order.SubTotal, invoice.Order.Discount, invoice.Order.Tax,
            invoice.Order.OrderCode, Table = invoice.Order.Table.TableName,
            Cashier = invoice.Order.Member.FullName, CustomerName = invoice.Order.CustomerName,
            Items = invoice.Order.Details.Select(d => new { Product = d.Product.Name, d.Quantity, d.UnitPrice, d.TotalPrice }),
            Payments = payments });
    }
    [HttpGet("by-order/{orderId:int}"), Authorize(Roles = "Admin,Staff,Cashier")]
    public async Task<IActionResult> ByOrder(int orderId)
    {
        var id = await db.Invoices.Where(x => x.OrderId == orderId).Select(x => (int?)x.Id).SingleOrDefaultAsync();
        return id is null ? NotFound() : await Get(id.Value);
    }
}

