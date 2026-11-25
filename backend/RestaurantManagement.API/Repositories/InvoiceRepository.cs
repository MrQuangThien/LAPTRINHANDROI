using Microsoft.EntityFrameworkCore;
using RestaurantManagement.API.Data;

namespace RestaurantManagement.API.Repositories;

public interface IInvoiceRepository
{
    Task<object?> GetGuestInvoiceAsync(int memberId, string trackingCode);
    Task<object?> GetInvoiceByIdAsync(int id);
    Task<int?> FindInvoiceIdByOrderIdAsync(int orderId);
}

public sealed class InvoiceRepository(RestaurantDbContext db) : IInvoiceRepository
{
    public async Task<object?> GetGuestInvoiceAsync(int memberId, string trackingCode)
    {
        var member = await db.Members.AsNoTracking().SingleOrDefaultAsync(m => m.Id == memberId && m.IsActive);
        if (member is null) return null;

        var raw = trackingCode.Trim();
        var isGuid = Guid.TryParse(raw, out var guid);
        return await db.Invoices.AsNoTracking().AsSplitQuery()
            .Where(i => (i.Order.MemberId == member.Id || (!string.IsNullOrEmpty(member.Phone) && i.Order.CustomerPhone == member.Phone))
                && (isGuid ? i.Order.ClientRequestId == guid : i.Order.OrderCode == raw))
            .Select(i => new
            {
                i.InvoiceCode, i.CreatedAt, i.TotalAmount,
                i.Order.SubTotal, i.Order.Discount, i.Order.Tax, i.Order.OrderCode,
                Table = i.Order.Table.TableName, CustomerName = i.Order.CustomerName,
                Items = i.Order.Details.Select(d => new { Product = d.Product.Name, d.Quantity, d.UnitPrice, d.TotalPrice }),
                Payments = i.Order.Payments.Where(p => p.Status == "Completed")
                    .Select(p => new { p.PaymentMethod, p.Amount, p.PaymentDate, p.TransactionCode })
            })
            .SingleOrDefaultAsync();
    }

    public async Task<object?> GetInvoiceByIdAsync(int id)
    {
        var invoice = await db.Invoices.AsNoTracking()
            .Include(i => i.Order).ThenInclude(o => o.Table)
            .Include(i => i.Order).ThenInclude(o => o.Details).ThenInclude(d => d.Product)
            .Include(i => i.Order).ThenInclude(o => o.Member)
            .SingleOrDefaultAsync(i => i.Id == id);
        if (invoice is null) return null;
        var payments = await db.Payments.AsNoTracking()
            .Where(p => p.OrderId == invoice.OrderId && p.Status == "Completed")
            .Select(p => new { p.PaymentMethod, p.Amount, p.PaymentDate, p.TransactionCode })
            .ToListAsync();
        return new
        {
            invoice.Id, invoice.InvoiceCode, invoice.CreatedAt, invoice.TotalAmount,
            invoice.Order.SubTotal, invoice.Order.Discount, invoice.Order.Tax,
            invoice.Order.OrderCode, Table = invoice.Order.Table.TableName,
            Cashier = invoice.Order.Member.FullName, CustomerName = invoice.Order.CustomerName,
            Items = invoice.Order.Details.Select(d => new { Product = d.Product.Name, d.Quantity, d.UnitPrice, d.TotalPrice }),
            Payments = payments
        };
    }

    public Task<int?> FindInvoiceIdByOrderIdAsync(int orderId) =>
        db.Invoices.Where(x => x.OrderId == orderId).Select(x => (int?)x.Id).SingleOrDefaultAsync();
}
