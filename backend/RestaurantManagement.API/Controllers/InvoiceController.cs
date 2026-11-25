using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using RestaurantManagement.API.Repositories;

namespace RestaurantManagement.API.Controllers;

[ApiController, Route("api/invoices"), Authorize]
public sealed class InvoiceController(IInvoiceRepository invoices) : ControllerBase
{
    [HttpGet("guest/{trackingCode}")]
    public async Task<IActionResult> Guest(string trackingCode)
    {
        if (!int.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var memberId))
            return Unauthorized();
        var invoice = await invoices.GetGuestInvoiceAsync(memberId, trackingCode);
        return invoice is null
            ? NotFound(new { message = "Không tìm thấy hóa đơn thuộc tài khoản của bạn cho đơn hàng này." })
            : Ok(invoice);
    }

    [HttpGet("{id:int}"), Authorize(Roles = "Admin,Staff,Cashier")]
    public async Task<IActionResult> Get(int id)
    {
        var invoice = await invoices.GetInvoiceByIdAsync(id);
        return invoice is null ? NotFound() : Ok(invoice);
    }

    [HttpGet("by-order/{orderId:int}"), Authorize(Roles = "Admin,Staff,Cashier")]
    public async Task<IActionResult> ByOrder(int orderId)
    {
        var id = await invoices.FindInvoiceIdByOrderIdAsync(orderId);
        return id is null ? NotFound() : await Get(id.Value);
    }
}
