using System.ComponentModel.DataAnnotations;

namespace RestaurantManagement.API.Models;

public sealed class Area
{
    public int Id { get; set; }
    [Required, MaxLength(100)] public string Name { get; set; } = string.Empty;
    [MaxLength(300)] public string? Description { get; set; }
    public ICollection<RestaurantTable> Tables { get; set; } = new List<RestaurantTable>();
}
