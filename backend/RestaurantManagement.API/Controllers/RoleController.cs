using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using RestaurantManagement.API.Data;

namespace RestaurantManagement.API.Controllers;

[ApiController, Route("api/roles"), Authorize(Roles = "Admin")]
public sealed class RoleController(RestaurantDbContext db) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> List() => Ok(await db.Roles.AsNoTracking().OrderBy(x => x.Id)
        .Select(x => new { x.Id, x.Name, x.Description }).ToListAsync());
}
