using System.ComponentModel.DataAnnotations;

namespace RestaurantManagement.API.Models;

public sealed class Payment
{
    public int Id { get; set; }
    public int OrderId { get; set; }
    [Required, MaxLength(30)] public string PaymentMethod { get; set; } = string.Empty;
    public decimal Amount { get; set; }
    public DateTime PaymentDate { get; set; } = DateTime.UtcNow;
    [Required, MaxLength(20)] public string Status { get; set; } = "Completed";
    [MaxLength(100)] public string? TransactionCode { get; set; }
    public Order Order { get; set; } = null!;
}
