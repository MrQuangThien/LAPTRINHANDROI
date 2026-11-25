using System.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;
using RestaurantManagement.API.Data;
using RestaurantManagement.API.DTOs;
using RestaurantManagement.API.Models;

namespace RestaurantManagement.API.Repositories;

public interface IPaymentRepository
{
    Task<PageResponse<object>> GetPendingAsync(int pageNumber, int pageSize);
    Task<IDbContextTransaction> BeginSerializableTransactionAsync();
    Task<Order?> FindOrderForCheckoutAsync(int orderId);
    Task<Payment?> FindPendingConfirmationAsync(int orderId);
    Task<bool> HasOtherOpenOrdersOnTableAsync(int orderId, int tableId);
    Task<List<CustomerReservation>> FindActiveSeatedReservationsAsync(int tableId);
    void AddPayment(Payment payment);
    void AddInvoice(Invoice invoice);
    Task SaveChangesAsync();
    Task<List<object>> GetHistoryAsync(int orderId);
}

public sealed class PaymentRepository(RestaurantDbContext db) : IPaymentRepository
{
    public async Task<PageResponse<object>> GetPendingAsync(int pageNumber, int pageSize)
    {
        var q = db.Orders.AsNoTracking().Include(o => o.Table).Where(o => o.Status == "Served" || o.Status == "Ready");
        var count = await q.CountAsync();
        var rows = await q.OrderBy(o => o.OrderDate).Skip((pageNumber - 1) * pageSize).Take(pageSize)
            .Select(o => new
            {
                o.Id, o.OrderCode, o.Status, TableName = o.Table.TableName, o.OrderDate, o.SubTotal, o.TotalAmount,
                CustomerName = o.CustomerName, CustomerPhone = o.CustomerPhone,
                PaymentRequest = o.Payments.OrderByDescending(p => p.PaymentDate)
                    .Select(p => new { p.PaymentMethod, p.TransactionCode, p.Status }).FirstOrDefault()
            }).ToListAsync();
        return new PageResponse<object>(rows.Cast<object>().ToList(), pageNumber, pageSize, count);
    }

    public Task<IDbContextTransaction> BeginSerializableTransactionAsync() =>
        db.Database.BeginTransactionAsync(IsolationLevel.Serializable);

    public Task<Order?> FindOrderForCheckoutAsync(int orderId) =>
        db.Orders.Include(o => o.Table).Include(o => o.Details).Include(o => o.Invoice).SingleOrDefaultAsync(o => o.Id == orderId);

    public Task<Payment?> FindPendingConfirmationAsync(int orderId) =>
        db.Payments.SingleOrDefaultAsync(p => p.OrderId == orderId && p.Status == "PendingConfirmation");

    public Task<bool> HasOtherOpenOrdersOnTableAsync(int orderId, int tableId) =>
        db.Orders.AnyAsync(o => o.Id != orderId && o.TableId == tableId && o.Status != "Completed" && o.Status != "Cancelled");

    public Task<List<CustomerReservation>> FindActiveSeatedReservationsAsync(int tableId) =>
        db.CustomerReservations.Where(r => r.TableId == tableId && r.Status == "Seated" && r.EndsAtUtc > DateTime.UtcNow).ToListAsync();

    public void AddPayment(Payment payment) => db.Payments.Add(payment);
    public void AddInvoice(Invoice invoice) => db.Invoices.Add(invoice);
    public Task SaveChangesAsync() => db.SaveChangesAsync();

    public async Task<List<object>> GetHistoryAsync(int orderId)
    {
        var rows = await db.Payments.AsNoTracking()
            .Where(p => p.OrderId == orderId).OrderByDescending(p => p.PaymentDate)
            .Select(p => new { p.Id, p.PaymentMethod, p.Amount, p.PaymentDate, p.Status, p.TransactionCode })
            .ToListAsync();
        return rows.Cast<object>().ToList();
    }
}
