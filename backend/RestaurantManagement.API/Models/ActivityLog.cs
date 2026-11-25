using System.ComponentModel.DataAnnotations;

namespace RestaurantManagement.API.Models;

public sealed class ActivityLog
{
    public int Id { get; set; }
    public int MemberId { get; set; }
    [Required, MaxLength(100)] public string Action { get; set; } = string.Empty;
    [MaxLength(1000)] public string? Description { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public Member Member { get; set; } = null!;
}
