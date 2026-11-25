using System.ComponentModel.DataAnnotations;

namespace RestaurantManagement.API.Models;

public sealed class Member
{
    public int Id { get; set; }
    [Required, MaxLength(120)] public string FullName { get; set; } = string.Empty;
    [Required, MaxLength(256), EmailAddress] public string Email { get; set; } = string.Empty;
    [Required, MaxLength(30)] public string Phone { get; set; } = string.Empty;
    [Required, MaxLength(500)] public string PasswordHash { get; set; } = string.Empty;
    public int RoleId { get; set; }
    public bool IsActive { get; set; } = true;
    public bool IsEmailVerified { get; set; } = false;
    [MaxLength(12)] public string? EmailVerificationCode { get; set; }
    public DateTime? EmailVerificationExpiryUtc { get; set; }
    [MaxLength(12)] public string? PasswordResetCode { get; set; }
    public DateTime? PasswordResetExpiryUtc { get; set; }
    [MaxLength(30)] public string? AuthProvider { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public Role Role { get; set; } = null!;
    public ICollection<Order> Orders { get; set; } = new List<Order>();
    public ICollection<ActivityLog> ActivityLogs { get; set; } = new List<ActivityLog>();
}
