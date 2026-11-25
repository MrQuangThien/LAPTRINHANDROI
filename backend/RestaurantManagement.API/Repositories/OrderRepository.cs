using System.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;
using RestaurantManagement.API.Data;
using RestaurantManagement.API.DTOs;
using RestaurantManagement.API.Models;

namespace RestaurantManagement.API.Repositories;

public interface IOrderRepository
{
    Task<PageResponse<object>> ListAsync(int pageNumber, int pageSize, string? search, string? status, DateTime? from, DateTime? to);
    Task<Order?> LoadFullAsync(int id);
    Task<IDbContextTransaction> BeginSerializableTransactionAsync();
    Task<Order?> FindDuplicateByClientRequestIdAsync(Guid clientRequestId);
    Task<RestaurantTable?> FindTableByIdAsync(int tableId);
    Task<bool> HasActiveOrderOnTableAsync(int tableId, string[] activeStatuses, int? excludeOrderId = null);
    Task<List<CustomerReservation>> FindUpcomingConfirmedReservationsAsync(int tableId);
    Task<List<CustomerReservation>> FindActiveSeatedReservationsAsync(int tableId);
    Task<Product?> FindAvailableProductAsync(int productId);
    Task<bool> ExistsOrderCodeAsync(string orderCode);
    void AddOrder(Order order);
    Task<Order?> FindForAddItemsAsync(int id);
    Task<Order?> FindByIdAsync(int id);
    Task<Order?> FindWithTableAsync(int id);
    Task<Order?> FindWithDetailsAsync(int id);
    Task SaveChangesAsync();
}

public sealed class OrderRepository(RestaurantDbContext db) : IOrderRepository
{
    public async Task<PageResponse<object>> ListAsync(int pageNumber, int pageSize, string? search, string? status, DateTime? from, DateTime? to)
    {
        var q = db.Orders.AsNoTracking().Include(o => o.Table).ThenInclude(t => t.Area).Include(o => o.Member).AsQueryable();
        if (!string.IsNullOrWhiteSpace(search))
            q = q.Where(o => o.OrderCode.Contains(search) || o.Table.TableName.Contains(search) || o.Member.FullName.Contains(search) || (o.CustomerName != null && o.CustomerName.Contains(search)));
        if (!string.IsNullOrWhiteSpace(status)) q = q.Where(o => o.Status == status);
        if (from.HasValue) q = q.Where(o => o.OrderDate >= from.Value);
        if (to.HasValue) q = q.Where(o => o.OrderDate < to.Value.Date.AddDays(1));
        var count = await q.CountAsync();
        var rows = await q.OrderByDescending(o => o.OrderDate).Skip((pageNumber - 1) * pageSize).Take(pageSize)
            .Select(o => new
            {
                o.Id, o.OrderCode, TableName = o.Table.TableName, MemberName = o.CustomerName ?? o.Member.FullName,
                o.OrderDate, o.Status, o.SubTotal, o.Discount, o.Tax, o.TotalAmount
            }).ToListAsync();
        return new PageResponse<object>(rows.Cast<object>().ToList(), pageNumber, pageSize, count);
    }

    public Task<Order?> LoadFullAsync(int id) =>
        db.Orders.AsNoTracking().Include(o => o.Table).Include(o => o.Member)
            .Include(o => o.Details).ThenInclude(d => d.Product).SingleOrDefaultAsync(o => o.Id == id);

    public Task<IDbContextTransaction> BeginSerializableTransactionAsync() =>
        db.Database.BeginTransactionAsync(IsolationLevel.Serializable);

    public Task<Order?> FindDuplicateByClientRequestIdAsync(Guid clientRequestId) =>
        db.Orders.Include(o => o.Table).Include(o => o.Member).Include(o => o.Details).ThenInclude(d => d.Product)
            .SingleOrDefaultAsync(o => o.ClientRequestId == clientRequestId);

    public Task<RestaurantTable?> FindTableByIdAsync(int tableId) =>
        db.Tables.SingleOrDefaultAsync(t => t.Id == tableId);

    public Task<bool> HasActiveOrderOnTableAsync(int tableId, string[] activeStatuses, int? excludeOrderId = null) =>
        excludeOrderId is null
            ? db.Orders.AnyAsync(o => o.TableId == tableId && activeStatuses.Contains(o.Status))
            : db.Orders.AnyAsync(o => o.Id != excludeOrderId && o.TableId == tableId && activeStatuses.Contains(o.Status));

    public Task<List<CustomerReservation>> FindUpcomingConfirmedReservationsAsync(int tableId) =>
        db.CustomerReservations
            .Where(r => r.TableId == tableId && r.Status == "Confirmed" &&
                r.StartsAtUtc < DateTime.UtcNow.AddMinutes(90) && r.EndsAtUtc > DateTime.UtcNow)
            .ToListAsync();

    public Task<List<CustomerReservation>> FindActiveSeatedReservationsAsync(int tableId) =>
        db.CustomerReservations
            .Where(r => r.TableId == tableId && r.Status == "Seated" && r.EndsAtUtc > DateTime.UtcNow)
            .ToListAsync();

    public Task<Product?> FindAvailableProductAsync(int productId) =>
        db.Products.SingleOrDefaultAsync(p => p.Id == productId && p.IsAvailable && p.Category.IsActive);

    public Task<bool> ExistsOrderCodeAsync(string orderCode) =>
        db.Orders.AnyAsync(o => o.OrderCode == orderCode);

    public void AddOrder(Order order) => db.Orders.Add(order);

    public Task<Order?> FindForAddItemsAsync(int id) =>
        db.Orders.Include(o => o.Details).Include(o => o.Payments).SingleOrDefaultAsync(o => o.Id == id);

    public Task<Order?> FindByIdAsync(int id) => db.Orders.FindAsync(id).AsTask();
    public Task<Order?> FindWithTableAsync(int id) => db.Orders.Include(o => o.Table).SingleOrDefaultAsync(o => o.Id == id);
    public Task<Order?> FindWithDetailsAsync(int id) => db.Orders.Include(o => o.Details).SingleOrDefaultAsync(o => o.Id == id);
    public Task SaveChangesAsync() => db.SaveChangesAsync();
}
