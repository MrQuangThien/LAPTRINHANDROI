using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.Security.Claims;
using RestaurantManagement.API.Data;
using RestaurantManagement.API.DTOs;
using RestaurantManagement.API.Models;

namespace RestaurantManagement.API.Controllers;

[ApiController, Route("api/areas"), Authorize(Roles = "Admin")]
public sealed class AreaController(RestaurantDbContext db) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> List() => Ok(await db.Areas.AsNoTracking().OrderBy(x => x.Name)
        .Select(x => new { x.Id, x.Name, x.Description, TableCount = x.Tables.Count }).ToListAsync());
    [HttpPost]
    public async Task<IActionResult> Create(AreaRequest request)
    {
        var name = request.Name.Trim(); if (await db.Areas.AnyAsync(x => x.Name == name)) return Conflict(new { message = "Area name already exists." });
        var a = new Area { Name = name, Description = request.Description?.Trim() }; db.Areas.Add(a); await db.SaveChangesAsync();
        return CreatedAtAction(nameof(List), new { id = a.Id }, a);
    }
    [HttpPut("{id:int}")]
    public async Task<IActionResult> Update(int id, AreaRequest request)
    {
        var a = await db.Areas.FindAsync(id); if (a is null) return NotFound(); var name = request.Name.Trim();
        if (await db.Areas.AnyAsync(x => x.Id != id && x.Name == name)) return Conflict(new { message = "Area name already exists." });
        a.Name = name; a.Description = request.Description?.Trim(); await db.SaveChangesAsync(); return NoContent();
    }
    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(int id)
    {
        var a = await db.Areas.Include(x => x.Tables).SingleOrDefaultAsync(x => x.Id == id); if (a is null) return NotFound();
        if (a.Tables.Count > 0) return Conflict(new { message = "Move or remove tables before deleting this area." });
        db.Areas.Remove(a); await db.SaveChangesAsync(); return NoContent();
    }
}

[ApiController, Route("api/tables"), Authorize(Roles = "Admin,Staff,Cashier")]
public sealed class TableController(RestaurantDbContext db) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<PageResponse<object>>> List([FromQuery] int pageNumber = 1, [FromQuery] int pageSize = 50,
        [FromQuery] string? search = null, [FromQuery] int? areaId = null, [FromQuery] string? status = null)
    {
        pageNumber = Math.Max(1, pageNumber); pageSize = Math.Clamp(pageSize, 1, 100);
        var now = DateTime.UtcNow;
        var windowEnd = now.AddMinutes(90);
        var toReserve = await db.Tables.Where(t => t.Status == "Available" &&
            !t.Orders.Any(o => ActiveStatuses.Contains(o.Status)) &&
            t.Reservations.Any(r => (r.Status == "Confirmed" || r.Status == "Seated") && r.StartsAtUtc <= windowEnd && r.EndsAtUtc > now))
            .ToListAsync();
        var toRelease = await db.Tables.Where(t => t.Status == "Reserved" &&
            !t.Orders.Any(o => ActiveStatuses.Contains(o.Status)) &&
            t.Reservations.Any() &&
            !t.Reservations.Any(r => (r.Status == "Confirmed" || r.Status == "Seated") && r.EndsAtUtc > now))
            .ToListAsync();
        if (toReserve.Count > 0 || toRelease.Count > 0)
        {
            foreach (var t in toReserve) t.Status = "Reserved";
            foreach (var t in toRelease) t.Status = "Available";
            await db.SaveChangesAsync();
        }
        var q = db.Tables.AsNoTracking().Include(t => t.Area).AsQueryable();
        if (!string.IsNullOrWhiteSpace(search)) q = q.Where(t => t.TableName.Contains(search) || t.Area.Name.Contains(search));
        if (areaId.HasValue) q = q.Where(t => t.AreaId == areaId);
        if (!string.IsNullOrWhiteSpace(status)) q = q.Where(t => t.Status == status);
        var count = await q.CountAsync(); var rows = await q.OrderBy(t => t.Area.Name).ThenBy(t => t.TableName)
            .Skip((pageNumber - 1) * pageSize).Take(pageSize)
            .Select(t => new { t.Id, t.AreaId, Area = t.Area.Name, t.TableName, t.Capacity, t.Status,
                ActiveOrderId = t.Orders.Where(o => o.Status != "Completed" && o.Status != "Cancelled")
                    .OrderByDescending(o => o.OrderDate).Select(o => (int?)o.Id).FirstOrDefault(),
                ActiveOrderCount = t.Orders.Count(o => ActiveStatuses.Contains(o.Status)),
                ActiveOrders = t.Orders.Where(o => ActiveStatuses.Contains(o.Status))
                    .OrderByDescending(o => o.OrderDate)
                    .Select(o => new { o.Id, o.OrderCode, o.Status, o.TotalAmount, o.CustomerName }).ToList() }).ToListAsync();
        return Ok(new PageResponse<object>(rows.Cast<object>().ToList(), pageNumber, pageSize, count));
    }
    [HttpPost, Authorize(Roles = "Admin")]
    public async Task<IActionResult> Create(TableRequest request)
    {
        if (!await db.Areas.AnyAsync(x => x.Id == request.AreaId)) return BadRequest(new { message = "Area not found." });
        if (await db.Tables.AnyAsync(x => x.AreaId == request.AreaId && x.TableName == request.TableName.Trim())) return Conflict(new { message = "Table name already exists in this area." });
        if (request.Status == "Occupied") return BadRequest(new { message = "Create the order first to occupy a table." });
        var t = new RestaurantTable { AreaId = request.AreaId, TableName = request.TableName.Trim(), Capacity = request.Capacity, Status = request.Status };
        db.Tables.Add(t); await db.SaveChangesAsync(); return CreatedAtAction(nameof(List), new { id = t.Id }, t);
    }
    [HttpPut("{id:int}"), Authorize(Roles = "Admin")]
    public async Task<IActionResult> Update(int id, TableRequest request)
    {
        var t = await db.Tables.FindAsync(id); if (t is null) return NotFound();
        if (!await db.Areas.AnyAsync(x => x.Id == request.AreaId)) return BadRequest(new { message = "Area not found." });
        if (await db.Tables.AnyAsync(x => x.Id != id && x.AreaId == request.AreaId && x.TableName == request.TableName.Trim())) return Conflict(new { message = "Table name already exists in this area." });
        var hasActiveOrder = await db.Orders.AnyAsync(o => o.TableId == id && o.Status != "Completed" && o.Status != "Cancelled");
        if (hasActiveOrder && request.Status != "Occupied") return Conflict(new { message = "A table with an active order must remain occupied." });
        if (!hasActiveOrder && request.Status == "Occupied") return BadRequest(new { message = "A table without an active order cannot be marked occupied." });
        t.AreaId = request.AreaId; t.TableName = request.TableName.Trim(); t.Capacity = request.Capacity; t.Status = request.Status;
        await db.SaveChangesAsync(); return NoContent();
    }
    [HttpDelete("{id:int}"), Authorize(Roles = "Admin")]
    public async Task<IActionResult> Delete(int id)
    {
        var t = await db.Tables.Include(x => x.Orders).Include(x => x.Reservations).SingleOrDefaultAsync(x => x.Id == id);
        if (t is null) return NotFound();
        if (t.Orders.Any(x => x.Status is not "Completed" and not "Cancelled")) return Conflict(new { message = "Table has an active order." });
        if (t.Orders.Count != 0) return Conflict(new { message = "Table has order history and cannot be deleted." });
        if (t.Reservations.Any(r => r.Status is "Confirmed" or "Seated" && r.EndsAtUtc > DateTime.UtcNow))
            return Conflict(new { message = "Table has an active or upcoming reservation." });
        if (t.Reservations.Count != 0) db.CustomerReservations.RemoveRange(t.Reservations);
        db.Tables.Remove(t); await db.SaveChangesAsync(); return NoContent();
    }

    [HttpPost("{id:int}/cleaned"), Authorize(Roles = "Admin,Staff,Cashier")]
    public async Task<IActionResult> MarkCleaned(int id)
    {
        var table = await db.Tables.FindAsync(id);
        if (table is null) return NotFound();
        if (table.Status != "Cleaning") return Conflict(new { message = "Only a table marked for cleaning can be released." });
        if (await db.Orders.AnyAsync(o => o.TableId == id && ActiveStatuses.Contains(o.Status)))
            return Conflict(new { message = "The table still has an active order." });
        table.Status = "Available";
        await db.SaveChangesAsync();
        return NoContent();
    }

    [HttpPost("{id:int}/transfer"), Authorize(Roles = "Admin,Staff,Cashier")]
    public async Task<IActionResult> Transfer(int id, TransferTableRequest request)
    {
        if (id == request.TargetTableId) return BadRequest(new { message = "Choose a different target table." });
        await using var tx = await db.Database.BeginTransactionAsync(System.Data.IsolationLevel.Serializable);
        var source = await db.Tables.SingleOrDefaultAsync(t => t.Id == id);
        var target = await db.Tables.SingleOrDefaultAsync(t => t.Id == request.TargetTableId);
        if (source is null || target is null) return NotFound(new { message = "Source or target table was not found." });
        var activeOrders = await db.Orders.Where(o => o.TableId == id && ActiveStatuses.Contains(o.Status))
            .OrderByDescending(o => o.OrderDate).ToListAsync();
        if (activeOrders.Count == 0) return Conflict(new { message = "The source table has no active order to transfer." });
        if (source.Status != "Occupied") return Conflict(new { message = "The source table is not occupied." });
        if (target.Status != "Available" || await db.Orders.AnyAsync(o => o.TableId == target.Id && ActiveStatuses.Contains(o.Status)))
            return Conflict(new { message = "The target table must be available and have no active order." });
        if (!int.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var memberId)) return Unauthorized();

        foreach (var order in activeOrders)
        {
            order.TableId = target.Id;
            db.ActivityLogs.Add(new ActivityLog { MemberId = memberId, Action = "TableTransfer",
                Description = $"Transferred {order.OrderCode} from {source.TableName} to {target.TableName}." });
        }
        var seatedOnSource = await db.CustomerReservations
            .Where(r => r.TableId == source.Id && r.Status == "Seated" && r.EndsAtUtc > DateTime.UtcNow)
            .ToListAsync();
        foreach (var res in seatedOnSource) res.TableId = target.Id;
        source.Status = "Cleaning";
        target.Status = "Occupied";
        await db.SaveChangesAsync();
        await tx.CommitAsync();
        return NoContent();
    }

    [HttpPost("{id:int}/merge"), Authorize(Roles = "Admin,Staff,Cashier")]
    public async Task<IActionResult> Merge(int id, TransferTableRequest request)
    {
        if (id == request.TargetTableId) return BadRequest(new { message = "Choose a different target table." });
        await using var tx = await db.Database.BeginTransactionAsync(System.Data.IsolationLevel.Serializable);
        var source = await db.Tables.SingleOrDefaultAsync(t => t.Id == id);
        var target = await db.Tables.SingleOrDefaultAsync(t => t.Id == request.TargetTableId);
        if (source is null || target is null) return NotFound(new { message = "Source or target table was not found." });
        var sourceOrders = await db.Orders.Where(o => o.TableId == source.Id && ActiveStatuses.Contains(o.Status)).ToListAsync();
        var targetHasOrders = await db.Orders.AnyAsync(o => o.TableId == target.Id && ActiveStatuses.Contains(o.Status));
        if (source.Status != "Occupied" || sourceOrders.Count == 0)
            return Conflict(new { message = "The source table must have at least one active order." });
        if (target.Status != "Occupied" || !targetHasOrders)
            return Conflict(new { message = "The target table must be occupied and have an active order." });
        if (!int.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var memberId)) return Unauthorized();

        foreach (var order in sourceOrders)
        {
            order.TableId = target.Id;
            db.ActivityLogs.Add(new ActivityLog { MemberId = memberId, Action = "TableMerge",
                Description = $"Merged {order.OrderCode} from {source.TableName} into {target.TableName}." });
        }
        var seatedOnSource = await db.CustomerReservations
            .Where(r => r.TableId == source.Id && r.Status == "Seated" && r.EndsAtUtc > DateTime.UtcNow)
            .ToListAsync();
        foreach (var res in seatedOnSource) res.TableId = target.Id;
        source.Status = "Cleaning";
        target.Status = "Occupied";
        await db.SaveChangesAsync();
        await tx.CommitAsync();
        return NoContent();
    }

    private static readonly string[] ActiveStatuses = ["Pending", "Confirmed", "Preparing", "Ready", "Served"];
}
