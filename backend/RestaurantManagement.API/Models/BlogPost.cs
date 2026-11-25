using System.ComponentModel.DataAnnotations;

namespace RestaurantManagement.API.Models;

public sealed class BlogPost
{
    public int Id { get; set; }
    [Required, MaxLength(200)] public string Title { get; set; } = string.Empty;
    [Required, MaxLength(80)] public string Category { get; set; } = "Câu chuyện quán";
    [Required, MaxLength(500)] public string Summary { get; set; } = string.Empty;
    [Required, MaxLength(8000)] public string Content { get; set; } = string.Empty;
    [MaxLength(500)] public string? ImageUrl { get; set; }
    [Required, MaxLength(120)] public string AuthorName { get; set; } = "Bếp Nhà";
    public int ReadingMinutes { get; set; } = 3;
    public bool IsFeatured { get; set; }
    public bool IsPublished { get; set; } = true;
    public DateTime PublishedAtUtc { get; set; } = DateTime.UtcNow;
}
