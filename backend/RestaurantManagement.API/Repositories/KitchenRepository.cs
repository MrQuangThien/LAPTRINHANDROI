using Microsoft.EntityFrameworkCore;
using RestaurantManagement.API.Data;
using RestaurantManagement.API.Models;

namespace RestaurantManagement.API.Repositories;

public interface IKitchenRepository
{
    Task<List<object>> GetQueueAsync(string? status);
    Task<Order?> FindOrderWithDetailsAsync(int id);
    Task SaveChangesAsync();
}

public sealed class KitchenRepository(RestaurantDbContext db) : IKitchenRepository
{
    public async Task<List<object>> GetQueueAsync(string? status)
    {
        var q = db.Orders.AsNoTracking()
            .Include(o => o.Table)
            .Include(o => o.Details).ThenInclude(d => d.Product)
            .Where(o => o.Status == "Pending" || o.Status == "Confirmed" || o.Status == "Preparing" || o.Status == "Ready");
        if (!string.IsNullOrWhiteSpace(status)) q = q.Where(o => o.Status == status);
        var rows = await q.OrderBy(o => o.OrderDate).Select(o => new
        {
            o.Id, o.OrderCode, TableName = o.Table.TableName, o.OrderDate, o.Status, o.Note,
            CustomerName = o.CustomerName,
            Items = o.Details.Select(d => new { d.Id, ProductName = d.Product.Name, d.Quantity, d.Note, d.Status })
        }).ToListAsync();
        return rows.Cast<object>().ToList();
    }

    public Task<Order?> FindOrderWithDetailsAsync(int id) =>
        db.Orders.Include(o => o.Details).SingleOrDefaultAsync(o => o.Id == id);

    public Task SaveChangesAsync() => db.SaveChangesAsync();
}
