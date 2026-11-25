using System.ComponentModel.DataAnnotations;

namespace RestaurantManagement.API.Models;

public sealed class Order
{
    public int Id { get; set; }
    [Required, MaxLength(40)] public string OrderCode { get; set; } = string.Empty;
    public Guid? ClientRequestId { get; set; }
    public int TableId { get; set; }
    public int MemberId { get; set; }
    public DateTime OrderDate { get; set; } = DateTime.UtcNow;
    [Required, MaxLength(20)] public string Status { get; set; } = "Pending";
    public decimal SubTotal { get; set; }
    public decimal Discount { get; set; }
    public decimal Tax { get; set; }
    public decimal TotalAmount { get; set; }
    [MaxLength(1000)] public string? Note { get; set; }
    [MaxLength(120)] public string? CustomerName { get; set; }
    [MaxLength(30)] public string? CustomerPhone { get; set; }
    public RestaurantTable Table { get; set; } = null!;
    public Member Member { get; set; } = null!;
    public ICollection<OrderDetail> Details { get; set; } = new List<OrderDetail>();
    public ICollection<Payment> Payments { get; set; } = new List<Payment>();
    public Invoice? Invoice { get; set; }
}
