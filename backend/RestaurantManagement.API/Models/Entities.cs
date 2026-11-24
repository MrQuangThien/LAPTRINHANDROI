using System.ComponentModel.DataAnnotations;

namespace RestaurantManagement.API.Models;

public sealed class Role
{
    public int Id { get; set; }
    [Required, MaxLength(40)] public string Name { get; set; } = string.Empty;
    [MaxLength(200)] public string? Description { get; set; }
    public ICollection<Member> Members { get; set; } = new List<Member>();
}

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

public sealed class Category
{
    public int Id { get; set; }
    [Required, MaxLength(100)] public string Name { get; set; } = string.Empty;
    [MaxLength(500)] public string? Description { get; set; }
    [MaxLength(500)] public string? ImageUrl { get; set; }
    public bool IsActive { get; set; } = true;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public ICollection<Product> Products { get; set; } = new List<Product>();
}

public sealed class Product
{
    public int Id { get; set; }
    public int CategoryId { get; set; }
    [Required, MaxLength(150)] public string Name { get; set; } = string.Empty;
    [MaxLength(1000)] public string? Description { get; set; }
    public decimal Price { get; set; }
    [MaxLength(500)] public string? ImageUrl { get; set; }
    public bool IsAvailable { get; set; } = true;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public Category Category { get; set; } = null!;
    public ICollection<OrderDetail> OrderDetails { get; set; } = new List<OrderDetail>();
}

public sealed class Area
{
    public int Id { get; set; }
    [Required, MaxLength(100)] public string Name { get; set; } = string.Empty;
    [MaxLength(300)] public string? Description { get; set; }
    public ICollection<RestaurantTable> Tables { get; set; } = new List<RestaurantTable>();
}

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

public sealed class Invoice
{
    public int Id { get; set; }
    public int OrderId { get; set; }
    [Required, MaxLength(40)] public string InvoiceCode { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public decimal TotalAmount { get; set; }
    public Order Order { get; set; } = null!;
}

public sealed class ActivityLog
{
    public int Id { get; set; }
    public int MemberId { get; set; }
    [Required, MaxLength(100)] public string Action { get; set; } = string.Empty;
    [MaxLength(1000)] public string? Description { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public Member Member { get; set; } = null!;
}

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


