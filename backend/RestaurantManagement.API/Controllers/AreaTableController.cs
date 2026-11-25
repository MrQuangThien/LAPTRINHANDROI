using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using RestaurantManagement.API.DTOs;
using RestaurantManagement.API.Models;
using RestaurantManagement.API.Repositories;

namespace RestaurantManagement.API.Controllers;

[ApiController, Route("api/areas"), Authorize(Roles = "Admin,Staff,Cashier")]
public sealed class AreaController(IAreaTableRepository repo) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> List() => Ok(await repo.ListAreasAsync());

    [HttpPost]
    public async Task<IActionResult> Create(AreaRequest request)
    {
        var name = request.Name.Trim();
        if (await repo.ExistsAreaByNameAsync(name)) return Conflict(new { message = "Area name already exists." });
        var area = new Area { Name = name, Description = request.Description?.Trim() };
        repo.AddArea(area);
        await repo.SaveChangesAsync();
        return CreatedAtAction(nameof(List), new { id = area.Id }, area);
    }

    [HttpPut("{id:int}")]
    public async Task<IActionResult> Update(int id, AreaRequest request)
    {
        var area = await repo.FindAreaByIdAsync(id);
        if (area is null) return NotFound();
        var name = request.Name.Trim();
        if (await repo.ExistsAreaByNameAsync(name, id)) return Conflict(new { message = "Area name already exists." });
        area.Name = name;
        area.Description = request.Description?.Trim();
        await repo.SaveChangesAsync();
        return NoContent();
    }

    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(int id)
    {
        var area = await repo.FindAreaWithTablesAsync(id);
        if (area is null) return NotFound();
        if (area.Tables.Count != 0) return Conflict(new { message = "This area still has tables." });
        repo.RemoveArea(area);
        await repo.SaveChangesAsync();
        return NoContent();
    }
}

[ApiController, Route("api/tables"), Authorize(Roles = "Admin,Staff,Cashier")]
public sealed class TableController(IAreaTableRepository repo) : ControllerBase
{
    private static readonly string[] ActiveStatuses = ["Pending", "Confirmed", "Preparing", "Ready", "Served"];

    [HttpGet]
    public async Task<ActionResult<PageResponse<object>>> List([FromQuery] int pageNumber = 1, [FromQuery] int pageSize = 50,
        [FromQuery] string? search = null, [FromQuery] int? areaId = null, [FromQuery] string? status = null)
    {
        pageNumber = Math.Max(1, pageNumber);
        pageSize = Math.Clamp(pageSize, 1, 100);
        return Ok(await repo.ListTablesAsync(pageNumber, pageSize, search, areaId, status, ActiveStatuses));
    }

    [HttpPost, Authorize(Roles = "Admin")]
    public async Task<IActionResult> Create(TableRequest request)
    {
        if (!await repo.AreaExistsAsync(request.AreaId)) return BadRequest(new { message = "Area not found." });
        if (await repo.TableNameExistsInAreaAsync(request.AreaId, request.TableName.Trim()))
            return Conflict(new { message = "Table name already exists in this area." });
        if (request.Status == "Occupied") return BadRequest(new { message = "Create the order first to occupy a table." });
        var t = new RestaurantTable { AreaId = request.AreaId, TableName = request.TableName.Trim(), Capacity = request.Capacity, Status = request.Status };
        repo.AddTable(t);
        await repo.SaveChangesAsync();
        return CreatedAtAction(nameof(List), new { id = t.Id }, t);
    }

    [HttpPut("{id:int}"), Authorize(Roles = "Admin")]
    public async Task<IActionResult> Update(int id, TableRequest request)
    {
        var t = await repo.FindTableByIdAsync(id);
        if (t is null) return NotFound();
        if (!await repo.AreaExistsAsync(request.AreaId)) return BadRequest(new { message = "Area not found." });
        if (await repo.TableNameExistsInAreaAsync(request.AreaId, request.TableName.Trim(), id))
            return Conflict(new { message = "Table name already exists in this area." });
        var hasActiveOrder = await repo.HasActiveOrderAsync(id, ActiveStatuses, checkOnlyNotClosed: true);
        if (hasActiveOrder && request.Status != "Occupied") return Conflict(new { message = "A table with an active order must remain occupied." });
        if (!hasActiveOrder && request.Status == "Occupied") return BadRequest(new { message = "A table without an active order cannot be marked occupied." });
        t.AreaId = request.AreaId;
        t.TableName = request.TableName.Trim();
        t.Capacity = request.Capacity;
        t.Status = request.Status;
        await repo.SaveChangesAsync();
        return NoContent();
    }

    [HttpDelete("{id:int}"), Authorize(Roles = "Admin")]
    public async Task<IActionResult> Delete(int id)
    {
        var t = await repo.FindTableWithOrdersAndReservationsAsync(id);
        if (t is null) return NotFound();
        if (t.Orders.Any(x => x.Status is not "Completed" and not "Cancelled")) return Conflict(new { message = "Table has an active order." });
        if (t.Orders.Count != 0) return Conflict(new { message = "Table has order history and cannot be deleted." });
        if (t.Reservations.Any(r => r.Status is "Confirmed" or "Seated" && r.EndsAtUtc > DateTime.UtcNow))
            return Conflict(new { message = "Table has an active or upcoming reservation." });
        if (t.Reservations.Count != 0) repo.RemoveReservations(t.Reservations);
        repo.RemoveTable(t);
        await repo.SaveChangesAsync();
        return NoContent();
    }

    [HttpPost("{id:int}/cleaned"), Authorize(Roles = "Admin,Staff,Cashier")]
    public async Task<IActionResult> MarkCleaned(int id)
    {
        var table = await repo.FindTableByIdAsync(id);
        if (table is null) return NotFound();
        if (table.Status != "Cleaning") return Conflict(new { message = "Only a table marked for cleaning can be released." });
        if (await repo.HasActiveOrderAsync(id, ActiveStatuses))
            return Conflict(new { message = "The table still has an active order." });
        table.Status = "Available";
        await repo.SaveChangesAsync();
        return NoContent();
    }

    [HttpPost("{id:int}/transfer"), Authorize(Roles = "Admin,Staff,Cashier")]
    public async Task<IActionResult> Transfer(int id, TransferTableRequest request)
    {
        if (id == request.TargetTableId) return BadRequest(new { message = "Choose a different target table." });
        await using var tx = await repo.BeginSerializableTransactionAsync();
        var source = await repo.FindTableByIdAsync(id);
        var target = await repo.FindTableByIdAsync(request.TargetTableId);
        if (source is null || target is null) return NotFound(new { message = "Source or target table was not found." });
        var activeOrders = await repo.FindActiveOrdersOnTableAsync(id, ActiveStatuses);
        if (activeOrders.Count == 0) return Conflict(new { message = "The source table has no active order to transfer." });
        if (source.Status != "Occupied") return Conflict(new { message = "The source table is not occupied." });
        if (target.Status != "Available" || await repo.HasActiveOrderAsync(target.Id, ActiveStatuses))
            return Conflict(new { message = "The target table must be available and have no active order." });
        if (!int.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var memberId)) return Unauthorized();

        foreach (var order in activeOrders)
        {
            order.TableId = target.Id;
            repo.AddActivityLog(new ActivityLog
            {
                MemberId = memberId, Action = "TableTransfer",
                Description = $"Transferred {order.OrderCode} from {source.TableName} to {target.TableName}."
            });
        }
        var seatedOnSource = await repo.FindActiveSeatedReservationsAsync(source.Id);
        foreach (var res in seatedOnSource) res.TableId = target.Id;
        source.Status = "Cleaning";
        target.Status = "Occupied";
        await repo.SaveChangesAsync();
        await tx.CommitAsync();
        return NoContent();
    }

    [HttpPost("{id:int}/merge"), Authorize(Roles = "Admin,Staff,Cashier")]
    public async Task<IActionResult> Merge(int id, TransferTableRequest request)
    {
        if (id == request.TargetTableId) return BadRequest(new { message = "Choose a different target table." });
        await using var tx = await repo.BeginSerializableTransactionAsync();
        var source = await repo.FindTableByIdAsync(id);
        var target = await repo.FindTableByIdAsync(request.TargetTableId);
        if (source is null || target is null) return NotFound(new { message = "Source or target table was not found." });
        var sourceOrders = await repo.FindActiveOrdersOnTableAsync(source.Id, ActiveStatuses);
        var targetHasOrders = await repo.HasActiveOrderAsync(target.Id, ActiveStatuses);
        if (source.Status != "Occupied" || sourceOrders.Count == 0)
            return Conflict(new { message = "The source table must have at least one active order." });
        if (target.Status != "Occupied" || !targetHasOrders)
            return Conflict(new { message = "The target table must be occupied and have an active order." });
        if (!int.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var memberId)) return Unauthorized();

        foreach (var order in sourceOrders)
        {
            order.TableId = target.Id;
            repo.AddActivityLog(new ActivityLog
            {
                MemberId = memberId, Action = "TableMerge",
                Description = $"Merged {order.OrderCode} from {source.TableName} into {target.TableName}."
            });
        }
        var seatedOnSource = await repo.FindActiveSeatedReservationsAsync(source.Id);
        foreach (var res in seatedOnSource) res.TableId = target.Id;
        source.Status = "Cleaning";
        target.Status = "Occupied";
        await repo.SaveChangesAsync();
        await tx.CommitAsync();
        return NoContent();
    }
}
