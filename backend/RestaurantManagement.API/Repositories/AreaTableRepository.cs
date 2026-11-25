using System.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;
using RestaurantManagement.API.Data;
using RestaurantManagement.API.DTOs;
using RestaurantManagement.API.Models;

namespace RestaurantManagement.API.Repositories;

public interface IAreaTableRepository
{
    Task<List<object>> ListAreasAsync();
    Task<bool> ExistsAreaByNameAsync(string name, int? excludeId = null);
    Task<Area?> FindAreaByIdAsync(int id);
    Task<Area?> FindAreaWithTablesAsync(int id);
    void AddArea(Area area);
    void RemoveArea(Area area);

    Task<PageResponse<object>> ListTablesAsync(int pageNumber, int pageSize, string? search, int? areaId, string? status, string[] activeStatuses);
    Task<bool> AreaExistsAsync(int areaId);
    Task<bool> TableNameExistsInAreaAsync(int areaId, string tableName, int? excludeId = null);
    Task<RestaurantTable?> FindTableByIdAsync(int id);
    Task<RestaurantTable?> FindTableWithOrdersAndReservationsAsync(int id);
    Task<bool> HasActiveOrderAsync(int tableId, string[] activeStatuses, bool checkOnlyNotClosed = false);
    Task<IDbContextTransaction> BeginSerializableTransactionAsync();
    Task<List<Order>> FindActiveOrdersOnTableAsync(int tableId, string[] activeStatuses);
    Task<List<CustomerReservation>> FindActiveSeatedReservationsAsync(int tableId);
    void AddTable(RestaurantTable table);
    void RemoveTable(RestaurantTable table);
    void RemoveReservations(IEnumerable<CustomerReservation> reservations);
    void AddActivityLog(ActivityLog log);
    Task SaveChangesAsync();
}

public sealed class AreaTableRepository(RestaurantDbContext db) : IAreaTableRepository
{
    public async Task<List<object>> ListAreasAsync()
    {
        var rows = await db.Areas.AsNoTracking().OrderBy(x => x.Name)
            .Select(x => new { x.Id, x.Name, x.Description }).ToListAsync();
        return rows.Cast<object>().ToList();
    }

    public Task<bool> ExistsAreaByNameAsync(string name, int? excludeId = null) =>
        excludeId is null
            ? db.Areas.AnyAsync(x => x.Name == name)
            : db.Areas.AnyAsync(x => x.Id != excludeId && x.Name == name);

    public Task<Area?> FindAreaByIdAsync(int id) => db.Areas.FindAsync(id).AsTask();
    public Task<Area?> FindAreaWithTablesAsync(int id) => db.Areas.Include(x => x.Tables).SingleOrDefaultAsync(x => x.Id == id);
    public void AddArea(Area area) => db.Areas.Add(area);
    public void RemoveArea(Area area) => db.Areas.Remove(area);

    public async Task<PageResponse<object>> ListTablesAsync(int pageNumber, int pageSize, string? search, int? areaId, string? status, string[] activeStatuses)
    {
        var now = DateTime.UtcNow;
        var windowEnd = now.AddMinutes(90);
        var toReserve = await db.Tables.Where(t => t.Status == "Available" &&
            !t.Orders.Any(o => activeStatuses.Contains(o.Status)) &&
            t.Reservations.Any(r => (r.Status == "Confirmed" || r.Status == "Seated") && r.StartsAtUtc <= windowEnd && r.EndsAtUtc > now))
            .ToListAsync();
        var toRelease = await db.Tables.Where(t => t.Status == "Reserved" &&
            !t.Orders.Any(o => activeStatuses.Contains(o.Status)) &&
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
        var count = await q.CountAsync();
        var rows = await q.OrderBy(t => t.Area.Name).ThenBy(t => t.TableName)
            .Skip((pageNumber - 1) * pageSize).Take(pageSize)
            .Select(t => new
            {
                t.Id, t.AreaId, Area = t.Area.Name, t.TableName, t.Capacity, t.Status,
                ActiveOrderId = t.Orders.Where(o => o.Status != "Completed" && o.Status != "Cancelled")
                    .OrderByDescending(o => o.OrderDate).Select(o => (int?)o.Id).FirstOrDefault(),
                ActiveOrderCount = t.Orders.Count(o => activeStatuses.Contains(o.Status)),
                ActiveOrders = t.Orders.Where(o => activeStatuses.Contains(o.Status))
                    .OrderByDescending(o => o.OrderDate)
                    .Select(o => new { o.Id, o.OrderCode, o.Status, o.TotalAmount, o.CustomerName }).ToList()
            }).ToListAsync();
        return new PageResponse<object>(rows.Cast<object>().ToList(), pageNumber, pageSize, count);
    }

    public Task<bool> AreaExistsAsync(int areaId) => db.Areas.AnyAsync(x => x.Id == areaId);

    public Task<bool> TableNameExistsInAreaAsync(int areaId, string tableName, int? excludeId = null) =>
        excludeId is null
            ? db.Tables.AnyAsync(x => x.AreaId == areaId && x.TableName == tableName)
            : db.Tables.AnyAsync(x => x.Id != excludeId && x.AreaId == areaId && x.TableName == tableName);

    public Task<RestaurantTable?> FindTableByIdAsync(int id) => db.Tables.FindAsync(id).AsTask();

    public Task<RestaurantTable?> FindTableWithOrdersAndReservationsAsync(int id) =>
        db.Tables.Include(x => x.Orders).Include(x => x.Reservations).SingleOrDefaultAsync(x => x.Id == id);

    public Task<bool> HasActiveOrderAsync(int tableId, string[] activeStatuses, bool checkOnlyNotClosed = false) =>
        checkOnlyNotClosed
            ? db.Orders.AnyAsync(o => o.TableId == tableId && o.Status != "Completed" && o.Status != "Cancelled")
            : db.Orders.AnyAsync(o => o.TableId == tableId && activeStatuses.Contains(o.Status));

    public Task<IDbContextTransaction> BeginSerializableTransactionAsync() =>
        db.Database.BeginTransactionAsync(IsolationLevel.Serializable);

    public Task<List<Order>> FindActiveOrdersOnTableAsync(int tableId, string[] activeStatuses) =>
        db.Orders.Where(o => o.TableId == tableId && activeStatuses.Contains(o.Status))
            .OrderByDescending(o => o.OrderDate).ToListAsync();

    public Task<List<CustomerReservation>> FindActiveSeatedReservationsAsync(int tableId) =>
        db.CustomerReservations.Where(r => r.TableId == tableId && r.Status == "Seated" && r.EndsAtUtc > DateTime.UtcNow).ToListAsync();

    public void AddTable(RestaurantTable table) => db.Tables.Add(table);
    public void RemoveTable(RestaurantTable table) => db.Tables.Remove(table);
    public void RemoveReservations(IEnumerable<CustomerReservation> reservations) => db.CustomerReservations.RemoveRange(reservations);
    public void AddActivityLog(ActivityLog log) => db.ActivityLogs.Add(log);
    public Task SaveChangesAsync() => db.SaveChangesAsync();
}
