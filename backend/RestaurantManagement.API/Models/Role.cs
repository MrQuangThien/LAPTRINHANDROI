using System.ComponentModel.DataAnnotations;

namespace RestaurantManagement.API.Models;

public sealed class Role
{
    public int Id { get; set; }
    [Required, MaxLength(40)] public string Name { get; set; } = string.Empty;
    [MaxLength(200)] public string? Description { get; set; }
    public ICollection<Member> Members { get; set; } = new List<Member>();
}
