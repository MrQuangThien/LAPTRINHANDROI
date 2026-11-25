using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using RestaurantManagement.API.DTOs;
using RestaurantManagement.API.Models;
using RestaurantManagement.API.Repositories;

namespace RestaurantManagement.API.Controllers;

[ApiController, Route("api/payments"), Authorize(Roles = "Admin,Cashier")]
public sealed class PaymentController(IPaymentRepository payments, IConfiguration configuration) : ControllerBase
{
    [HttpGet("pending")]
    public async Task<IActionResult> Pending([FromQuery] int pageNumber = 1, [FromQuery] int pageSize = 20)
    {
        pageNumber = Math.Max(1, pageNumber);
        pageSize = Math.Clamp(pageSize, 1, 100);
        return Ok(await payments.GetPendingAsync(pageNumber, pageSize));
    }

    [HttpPost("orders/{orderId:int}/checkout")]
    public async Task<IActionResult> Checkout(int orderId, PaymentRequest request)
    {
        await using var tx = await payments.BeginSerializableTransactionAsync();
        var order = await payments.FindOrderForCheckoutAsync(orderId);
        if (order is null) return NotFound();
        if (order.Invoice is not null || order.Status == "Completed") return Conflict(new { message = "Order has already been paid." });
        if (order.Status is not "Served" and not "Ready") return Conflict(new { message = "Only ready or served orders can be paid." });
        foreach (var line in order.Details) line.Status = "Served";
        var pendingRequest = await payments.FindPendingConfirmationAsync(order.Id);
        var transactionCode = request.TransactionCode?.Trim();
        if (string.IsNullOrWhiteSpace(transactionCode)) transactionCode = pendingRequest?.TransactionCode;
        if (request.PaymentMethod != "Cash" && string.IsNullOrWhiteSpace(request.TransactionCode) && string.IsNullOrWhiteSpace(transactionCode))
            return BadRequest(new { message = "A transaction reference is required for non-cash payments." });
        if (request.Discount > order.SubTotal) return BadRequest(new { message = "Discount cannot exceed the subtotal." });
        var rate = configuration.GetValue<decimal>("Payments:TaxRate");
        if (rate is < 0 or > 100) return Problem("Payments:TaxRate must be between 0 and 100.", statusCode: 500);
        var taxableAmount = order.SubTotal - request.Discount;
        var tax = decimal.Round(taxableAmount * rate / 100m, 2, MidpointRounding.AwayFromZero);
        var total = taxableAmount + tax;
        if (total < 0) return BadRequest(new { message = "Payment total cannot be negative." });
        order.Discount = request.Discount;
        order.Tax = tax;
        order.TotalAmount = total;
        order.Status = "Completed";
        if (!await payments.HasOtherOpenOrdersOnTableAsync(order.Id, order.TableId))
        {
            order.Table.Status = "Cleaning";
            var seated = await payments.FindActiveSeatedReservationsAsync(order.TableId);
            foreach (var r in seated) r.EndsAtUtc = DateTime.UtcNow;
        }
        var code = $"INV-{DateTime.UtcNow:yyyyMMddHHmmss}-{Guid.NewGuid():N}"[..31];
        if (pendingRequest is not null)
        {
            pendingRequest.PaymentMethod = request.PaymentMethod;
            pendingRequest.Amount = total;
            pendingRequest.PaymentDate = DateTime.UtcNow;
            pendingRequest.Status = "Completed";
            pendingRequest.TransactionCode = transactionCode;
        }
        else
        {
            payments.AddPayment(new Payment
            {
                OrderId = order.Id, PaymentMethod = request.PaymentMethod, Amount = total,
                PaymentDate = DateTime.UtcNow, Status = "Completed", TransactionCode = transactionCode
            });
        }
        payments.AddInvoice(new Invoice { OrderId = order.Id, InvoiceCode = code, TotalAmount = total, CreatedAt = DateTime.UtcNow });
        await payments.SaveChangesAsync();
        await tx.CommitAsync();
        return Ok(new { order.Id, order.OrderCode, order.Status, order.TotalAmount, Tax = tax, InvoiceCode = code });
    }

    [HttpGet("orders/{orderId:int}/history")]
    public async Task<IActionResult> History(int orderId) => Ok(await payments.GetHistoryAsync(orderId));
}
