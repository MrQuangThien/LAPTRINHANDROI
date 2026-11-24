using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using RestaurantManagement.API.Data;

namespace RestaurantManagement.API.Controllers;

[ApiController, Route("api/reports"), Authorize(Roles = "Admin,Cashier")]
public sealed class ReportController(RestaurantDbContext db) : ControllerBase
{
    [HttpGet("dashboard")]
    public async Task<IActionResult> Dashboard()
    {
        // Restaurant reporting dates use Vietnam local time; persisted timestamps remain UTC.
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
            .GroupBy(d => new { d.ProductId, d.Product.Name }).Select(g => new { g.Key.ProductId, ProductName = g.Key.Name,
                Quantity = g.Sum(d => d.Quantity), Revenue = g.Sum(d => d.TotalPrice) })
            .OrderByDescending(x => x.Quantity).Take(5).ToListAsync();
        return Ok(new {
            todayRevenue, monthRevenue, todayOrders, completedOrdersToday = servedToday, soldItemsToday = soldToday,
            totalTables = await db.Tables.CountAsync(), occupiedTables = await db.Tables.CountAsync(t => t.Status == "Occupied"),
            availableTables = await db.Tables.CountAsync(t => t.Status == "Available"),
            preparingOrders = await db.Orders.CountAsync(o => o.Status == "Preparing"), topProducts = top
        });
    }

    [HttpGet("revenue")]
    public async Task<IActionResult> Revenue([FromQuery] DateTime? from = null, [FromQuery] DateTime? to = null,
        [FromQuery] string groupBy = "day")
    {
        if (groupBy is not "day" and not "month") return BadRequest(new { message = "groupBy must be day or month." });
        var localToday = DateTimeOffset.UtcNow.ToOffset(TimeSpan.FromHours(7)).Date;
        var localStart = (from ?? localToday.AddDays(-29)).Date;
        var localEnd = (to ?? localToday).Date.AddDays(1);
        if (localEnd <= localStart || (localEnd - localStart).TotalDays > 366) return BadRequest(new { message = "Date range must be between 1 and 366 days." });
        var startUtc = new DateTimeOffset(localStart, TimeSpan.FromHours(7)).UtcDateTime;
        var endUtc = new DateTimeOffset(localEnd, TimeSpan.FromHours(7)).UtcDateTime;
        var rows = await db.Payments.AsNoTracking().Where(p => p.Status == "Completed" && p.PaymentDate >= startUtc && p.PaymentDate < endUtc)
            .GroupBy(p => groupBy == "month"
                ? new DateTime(p.PaymentDate.AddHours(7).Year, p.PaymentDate.AddHours(7).Month, 1)
                : p.PaymentDate.AddHours(7).Date)
            .Select(g => new { date = g.Key, revenue = g.Sum(p => p.Amount), orders = g.Select(p => p.OrderId).Distinct().Count() })
            .OrderBy(x => x.date).ToListAsync();
        return Ok(rows);
    }

    [HttpGet("order-statuses")]
    public async Task<IActionResult> OrderStatuses() => Ok(await db.Orders.AsNoTracking().GroupBy(o => o.Status)
        .Select(g => new { status = g.Key, count = g.Count() }).OrderBy(x => x.status).ToListAsync());
}

