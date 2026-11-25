using System.ComponentModel.DataAnnotations;

namespace RestaurantManagement.API.Models;

public sealed class Invoice
{
    public int Id { get; set; }
    public int OrderId { get; set; }
    [Required, MaxLength(40)] public string InvoiceCode { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public decimal TotalAmount { get; set; }
    public Order Order { get; set; } = null!;
}
