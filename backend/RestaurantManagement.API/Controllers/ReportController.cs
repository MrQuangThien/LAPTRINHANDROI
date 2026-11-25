using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using RestaurantManagement.API.Repositories;

namespace RestaurantManagement.API.Controllers;

[ApiController, Route("api/reports"), Authorize(Roles = "Admin,Cashier")]
public sealed class ReportController(IReportRepository reports) : ControllerBase
{
    [HttpGet("dashboard")]
    public async Task<IActionResult> Dashboard() => Ok(await reports.GetDashboardAsync());

    [HttpGet("revenue")]
    public async Task<IActionResult> Revenue([FromQuery] DateTime? from = null, [FromQuery] DateTime? to = null,
        [FromQuery] string groupBy = "day")
    {
        if (groupBy is not "day" and not "month") return BadRequest(new { message = "groupBy must be day or month." });
        var localToday = DateTimeOffset.UtcNow.ToOffset(TimeSpan.FromHours(7)).Date;
        var localStart = (from ?? localToday.AddDays(-29)).Date;
        var localEnd = (to ?? localToday).Date.AddDays(1);
        if (localEnd <= localStart || (localEnd - localStart).TotalDays > 366)
            return BadRequest(new { message = "Date range must be between 1 and 366 days." });
        var startUtc = new DateTimeOffset(localStart, TimeSpan.FromHours(7)).UtcDateTime;
        var endUtc = new DateTimeOffset(localEnd, TimeSpan.FromHours(7)).UtcDateTime;
        return Ok(await reports.GetRevenueAsync(startUtc, endUtc, groupBy));
    }

    [HttpGet("order-statuses")]
    public async Task<IActionResult> OrderStatuses() => Ok(await reports.GetOrderStatusesAsync());
}
