using Microsoft.EntityFrameworkCore;
using RestaurantManagement.API.Data;

namespace RestaurantManagement.API.Repositories;

public interface IRoleRepository
{
    Task<List<object>> ListAsync();
}

public sealed class RoleRepository(RestaurantDbContext db) : IRoleRepository
{
    public async Task<List<object>> ListAsync()
    {
        var rows = await db.Roles.AsNoTracking().OrderBy(x => x.Id)
            .Select(x => new { x.Id, x.Name, x.Description })
            .ToListAsync();
        return rows.Cast<object>().ToList();
    }
}
