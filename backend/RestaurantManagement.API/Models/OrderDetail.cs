using System.ComponentModel.DataAnnotations;

namespace RestaurantManagement.API.Models;

public sealed class OrderDetail
{
    public int Id { get; set; }
    public int OrderId { get; set; }
    public int ProductId { get; set; }
    public int Quantity { get; set; }
    public decimal UnitPrice { get; set; }
    public decimal TotalPrice { get; set; }
    [MaxLength(500)] public string? Note { get; set; }
    [Required, MaxLength(20)] public string Status { get; set; } = "Pending";
    public Order Order { get; set; } = null!;
    public Product Product { get; set; } = null!;
}
