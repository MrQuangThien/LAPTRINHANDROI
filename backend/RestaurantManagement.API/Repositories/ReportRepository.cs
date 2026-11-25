using Microsoft.EntityFrameworkCore;
using RestaurantManagement.API.Data;

namespace RestaurantManagement.API.Repositories;

public interface IReportRepository
{
    Task<object> GetDashboardAsync();
    Task<List<object>> GetRevenueAsync(DateTime startUtc, DateTime endUtc, string groupBy);
    Task<List<object>> GetOrderStatusesAsync();
}

public sealed class ReportRepository(RestaurantDbContext db) : IReportRepository
{
    public async Task<object> GetDashboardAsync()
    {
        var localNow = DateTimeOffset.UtcNow.ToOffset(TimeSpan.FromHours(7));
        var today = new DateTimeOffset(localNow.Year, localNow.Month, localNow.Day, 0, 0, 0, TimeSpan.FromHours(7)).UtcDateTime;
        var month = new DateTimeOffset(localNow.Year, localNow.Month, 1, 0, 0, 0, TimeSpan.FromHours(7)).UtcDateTime;
        var paid = db.Payments.AsNoTracking().Where(p => p.Status == "Completed");
        var todayRevenue = await paid.Where(p => p.PaymentDate >= today).SumAsync(p => (decimal?)p.Amount) ?? 0;
        var monthRevenue = await paid.Where(p => p.PaymentDate >= month).SumAsync(p => (decimal?)p.Amount) ?? 0;
        var todayOrders = await db.Orders.CountAsync(o => o.OrderDate >= today);
        var servedToday = await db.Orders.CountAsync(o => o.Status == "Completed" && o.OrderDate >= today);
        var soldToday = await db.OrderDetails.Where(d => d.Order.Status == "Completed" && d.Order.OrderDate >= today).SumAsync(d => (int?)d.Quantity) ?? 0;
        var top = await db.OrderDetails.AsNoTracking().Where(d => d.Order.Status == "Completed")
            .GroupBy(d => new { d.ProductId, d.Product.Name })
            .Select(g => new { g.Key.ProductId, ProductName = g.Key.Name, Quantity = g.Sum(d => d.Quantity), Revenue = g.Sum(d => d.TotalPrice) })
            .OrderByDescending(x => x.Quantity).Take(5).ToListAsync();
        return new
        {
            todayRevenue, monthRevenue, todayOrders, completedOrdersToday = servedToday, soldItemsToday = soldToday,
            totalTables = await db.Tables.CountAsync(), occupiedTables = await db.Tables.CountAsync(t => t.Status == "Occupied"),
            availableTables = await db.Tables.CountAsync(t => t.Status == "Available"),
            preparingOrders = await db.Orders.CountAsync(o => o.Status == "Preparing"), topProducts = top
        };
    }

    public async Task<List<object>> GetRevenueAsync(DateTime startUtc, DateTime endUtc, string groupBy)
    {
        var rows = await db.Payments.AsNoTracking()
            .Where(p => p.Status == "Completed" && p.PaymentDate >= startUtc && p.PaymentDate < endUtc)
            .GroupBy(p => groupBy == "month"
                ? new DateTime(p.PaymentDate.AddHours(7).Year, p.PaymentDate.AddHours(7).Month, 1)
                : p.PaymentDate.AddHours(7).Date)
            .Select(g => new { date = g.Key, revenue = g.Sum(p => p.Amount), orders = g.Select(p => p.OrderId).Distinct().Count() })
            .OrderBy(x => x.date).ToListAsync();
        return rows.Cast<object>().ToList();
    }

    public async Task<List<object>> GetOrderStatusesAsync()
    {
        var rows = await db.Orders.AsNoTracking().GroupBy(o => o.Status)
            .Select(g => new { status = g.Key, count = g.Count() }).OrderBy(x => x.status).ToListAsync();
        return rows.Cast<object>().ToList();
    }
}
