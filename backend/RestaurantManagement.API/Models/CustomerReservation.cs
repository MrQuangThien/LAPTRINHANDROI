using System.ComponentModel.DataAnnotations;

namespace RestaurantManagement.API.Models;

public sealed class CustomerReservation
{
    public int Id { get; set; }
    public Guid ReservationCode { get; set; }
    public int TableId { get; set; }
    [Required, MaxLength(120)] public string CustomerName { get; set; } = string.Empty;
    [Required, MaxLength(30)] public string CustomerPhone { get; set; } = string.Empty;
    public int PartySize { get; set; }
    public DateTime StartsAtUtc { get; set; }
    public DateTime EndsAtUtc { get; set; }
    [Required, MaxLength(20)] public string Status { get; set; } = "Confirmed";
    [MaxLength(500)] public string? Note { get; set; }
    public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;
    public RestaurantTable Table { get; set; } = null!;
}
