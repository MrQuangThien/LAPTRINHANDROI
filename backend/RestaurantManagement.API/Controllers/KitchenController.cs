using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using RestaurantManagement.API.Data;

namespace RestaurantManagement.API.Controllers;

[ApiController, Route("api/kitchen"), Authorize(Roles = "Admin,Kitchen")]
public sealed class KitchenController(RestaurantDbContext db) : ControllerBase
{
    [HttpGet("orders")]
    public async Task<IActionResult> Queue([FromQuery] string? status = null)
    {
        var q = db.Orders.AsNoTracking().Include(o => o.Table).Include(o => o.Details).ThenInclude(d => d.Product)
            .Where(o => o.Status == "Pending" || o.Status == "Confirmed" || o.Status == "Preparing" || o.Status == "Ready");
        if (!string.IsNullOrWhiteSpace(status)) q = q.Where(o => o.Status == status);
        var rows = await q.OrderBy(o => o.OrderDate).Select(o => new {
            o.Id, o.OrderCode, TableName = o.Table.TableName, o.OrderDate, o.Status, o.Note,
            CustomerName = o.CustomerName,
            Items = o.Details.Select(d => new { d.Id, ProductName = d.Product.Name, d.Quantity, d.Note, d.Status })
        }).ToListAsync();
        return Ok(rows);
    }

    [HttpPost("orders/{id:int}/start")]
    public async Task<IActionResult> Start(int id)
    {
        var order = await db.Orders.Include(o => o.Details).SingleOrDefaultAsync(o => o.Id == id);
        if (order is null) return NotFound();
        if (order.Status is not "Pending" and not "Confirmed" and not "Preparing" and not "Ready")
            return Conflict(new { message = "Only active orders can receive kitchen work." });
        order.Status = "Preparing";
        foreach (var line in order.Details.Where(x => x.Status == "Pending")) line.Status = "Preparing";
        await db.SaveChangesAsync(); return NoContent();
    }

    [HttpPost("orders/{id:int}/ready")]
    public async Task<IActionResult> Ready(int id)
    {
        var order = await db.Orders.Include(o => o.Details).SingleOrDefaultAsync(o => o.Id == id);
        if (order is null) return NotFound();
        if (order.Status == "Ready") return NoContent();
        if (order.Status != "Preparing") return Conflict(new { message = "Only preparing orders can be marked ready." });
        order.Status = "Ready";
        foreach (var line in order.Details.Where(x => x.Status != "Served")) line.Status = "Ready";
        await db.SaveChangesAsync(); return NoContent();
    }

    [HttpPost("orders/{id:int}/served"), Authorize(Roles = "Admin,Staff,Kitchen")]
    public async Task<IActionResult> Served(int id)
    {
        var order = await db.Orders.Include(o => o.Details).SingleOrDefaultAsync(o => o.Id == id);
        if (order is null) return NotFound();
        if (order.Status == "Served") return NoContent();
        if (order.Status != "Ready") return Conflict(new { message = "Only ready orders can be served." });
        order.Status = "Served";
        foreach (var line in order.Details) line.Status = "Served";
        await db.SaveChangesAsync(); return NoContent();
    }
}
