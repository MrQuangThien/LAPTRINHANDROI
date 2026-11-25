using System.ComponentModel.DataAnnotations;

namespace RestaurantManagement.API.Models;

public sealed class RestaurantTable
{
    public int Id { get; set; }
    public int AreaId { get; set; }
    [Required, MaxLength(50)] public string TableName { get; set; } = string.Empty;
    public int Capacity { get; set; }
    [Required, MaxLength(20)] public string Status { get; set; } = "Available";
    public Area Area { get; set; } = null!;
    public ICollection<Order> Orders { get; set; } = new List<Order>();
    public ICollection<CustomerReservation> Reservations { get; set; } = new List<CustomerReservation>();
}
