using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using RestaurantManagement.API.Repositories;

namespace RestaurantManagement.API.Controllers;

[ApiController, Route("api/kitchen"), Authorize(Roles = "Admin,Kitchen")]
public sealed class KitchenController(IKitchenRepository kitchen) : ControllerBase
{
    [HttpGet("orders")]
    public async Task<IActionResult> Queue([FromQuery] string? status = null) =>
        Ok(await kitchen.GetQueueAsync(status));

    [HttpPost("orders/{id:int}/start")]
    public async Task<IActionResult> Start(int id)
    {
        var order = await kitchen.FindOrderWithDetailsAsync(id);
        if (order is null) return NotFound();
        if (order.Status is not "Pending" and not "Confirmed" and not "Preparing" and not "Ready")
            return Conflict(new { message = "Only active orders can receive kitchen work." });
        order.Status = "Preparing";
        foreach (var line in order.Details.Where(x => x.Status == "Pending")) line.Status = "Preparing";
        await kitchen.SaveChangesAsync();
        return NoContent();
    }

    [HttpPost("orders/{id:int}/ready")]
    public async Task<IActionResult> Ready(int id)
    {
        var order = await kitchen.FindOrderWithDetailsAsync(id);
        if (order is null) return NotFound();
        if (order.Status == "Ready") return NoContent();
        if (order.Status != "Preparing") return Conflict(new { message = "Only preparing orders can be marked ready." });
        order.Status = "Ready";
        foreach (var line in order.Details.Where(x => x.Status != "Served")) line.Status = "Ready";
        await kitchen.SaveChangesAsync();
        return NoContent();
    }

    [HttpPost("orders/{id:int}/served"), Authorize(Roles = "Admin,Staff,Kitchen")]
    public async Task<IActionResult> Served(int id)
    {
        var order = await kitchen.FindOrderWithDetailsAsync(id);
        if (order is null) return NotFound();
        if (order.Status == "Served") return NoContent();
        if (order.Status != "Ready") return Conflict(new { message = "Only ready orders can be served." });
        order.Status = "Served";
        foreach (var line in order.Details) line.Status = "Served";
        await kitchen.SaveChangesAsync();
        return NoContent();
    }
}
