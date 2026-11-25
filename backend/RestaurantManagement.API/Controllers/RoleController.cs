using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using RestaurantManagement.API.Repositories;

namespace RestaurantManagement.API.Controllers;

[ApiController, Route("api/roles"), Authorize(Roles = "Admin")]
public sealed class RoleController(IRoleRepository roles) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> List() => Ok(await roles.ListAsync());
}
