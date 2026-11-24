using Microsoft.EntityFrameworkCore;
using RestaurantManagement.API.Models;

namespace RestaurantManagement.API.Data;

public sealed class RestaurantDbContext(DbContextOptions<RestaurantDbContext> options) : DbContext(options)
{
    public DbSet<Role> Roles => Set<Role>();
    public DbSet<Member> Members => Set<Member>();
    public DbSet<Category> Categories => Set<Category>();
    public DbSet<Product> Products => Set<Product>();
    public DbSet<Area> Areas => Set<Area>();
    public DbSet<RestaurantTable> Tables => Set<RestaurantTable>();
    public DbSet<Order> Orders => Set<Order>();
    public DbSet<OrderDetail> OrderDetails => Set<OrderDetail>();
    public DbSet<Payment> Payments => Set<Payment>();
    public DbSet<Invoice> Invoices => Set<Invoice>();
    public DbSet<ActivityLog> ActivityLogs => Set<ActivityLog>();
    public DbSet<CustomerReservation> CustomerReservations => Set<CustomerReservation>();
    public DbSet<BlogPost> BlogPosts => Set<BlogPost>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);
        modelBuilder.Entity<Role>(e => {
            e.HasKey(x => x.Id); e.HasIndex(x => x.Name).IsUnique();
            e.Property(x => x.Name).IsRequired().HasMaxLength(40);
            e.HasData(new Role { Id = 1, Name = "Admin", Description = "System administrator" },
                new Role { Id = 2, Name = "Staff", Description = "Service staff" },
                new Role { Id = 3, Name = "Cashier", Description = "Cashier" },
                new Role { Id = 4, Name = "Kitchen", Description = "Kitchen staff" });
        });
        modelBuilder.Entity<Member>(e => {
            e.HasIndex(x => x.Email).IsUnique(); e.HasIndex(x => x.Phone).IsUnique();
            e.Property(x => x.Email).HasMaxLength(256).IsRequired();
            e.Property(x => x.PasswordHash).HasMaxLength(500).IsRequired();
            e.HasOne(x => x.Role).WithMany(x => x.Members).HasForeignKey(x => x.RoleId).OnDelete(DeleteBehavior.Restrict);
        });
        modelBuilder.Entity<Category>(e => { e.HasIndex(x => x.Name).IsUnique(); e.Property(x => x.Name).HasMaxLength(100).IsRequired(); });
        modelBuilder.Entity<Product>(e => {
            e.Property(x => x.Price).HasPrecision(18, 2);
            e.HasOne(x => x.Category).WithMany(x => x.Products).HasForeignKey(x => x.CategoryId).OnDelete(DeleteBehavior.Restrict);
        });
        modelBuilder.Entity<Area>(e => e.HasIndex(x => x.Name).IsUnique());
        modelBuilder.Entity<RestaurantTable>(e => {
            e.HasIndex(x => new { x.AreaId, x.TableName }).IsUnique();
            e.HasOne(x => x.Area).WithMany(x => x.Tables).HasForeignKey(x => x.AreaId).OnDelete(DeleteBehavior.Restrict);
        });
        modelBuilder.Entity<CustomerReservation>(e => {
            e.HasIndex(x => x.ReservationCode).IsUnique();
            e.HasIndex(x => new { x.TableId, x.StartsAtUtc, x.EndsAtUtc });
            e.Property(x => x.Status).HasMaxLength(20).IsRequired();
            e.HasOne(x => x.Table).WithMany(x => x.Reservations).HasForeignKey(x => x.TableId).OnDelete(DeleteBehavior.Restrict);
        });
        modelBuilder.Entity<Order>(e => {
            e.HasIndex(x => x.OrderCode).IsUnique(); e.HasIndex(x => x.ClientRequestId).IsUnique();
            e.Property(x => x.SubTotal).HasPrecision(18, 2); e.Property(x => x.Discount).HasPrecision(18, 2);
            e.Property(x => x.Tax).HasPrecision(18, 2); e.Property(x => x.TotalAmount).HasPrecision(18, 2);
            e.Property(x => x.CustomerName).HasMaxLength(120); e.Property(x => x.CustomerPhone).HasMaxLength(30);
            e.HasOne(x => x.Table).WithMany(x => x.Orders).HasForeignKey(x => x.TableId).OnDelete(DeleteBehavior.Restrict);
            e.HasOne(x => x.Member).WithMany(x => x.Orders).HasForeignKey(x => x.MemberId).OnDelete(DeleteBehavior.Restrict);
        });
        modelBuilder.Entity<OrderDetail>(e => {
            e.Property(x => x.UnitPrice).HasPrecision(18, 2); e.Property(x => x.TotalPrice).HasPrecision(18, 2);
            e.HasOne(x => x.Order).WithMany(x => x.Details).HasForeignKey(x => x.OrderId).OnDelete(DeleteBehavior.Cascade);
            e.HasOne(x => x.Product).WithMany(x => x.OrderDetails).HasForeignKey(x => x.ProductId).OnDelete(DeleteBehavior.Restrict);
        });
        modelBuilder.Entity<Payment>(e => {
            e.Property(x => x.Amount).HasPrecision(18, 2);
            e.HasOne(x => x.Order).WithMany(x => x.Payments).HasForeignKey(x => x.OrderId).OnDelete(DeleteBehavior.Restrict);
        });
        modelBuilder.Entity<Invoice>(e => {
            e.HasIndex(x => x.OrderId).IsUnique(); e.HasIndex(x => x.InvoiceCode).IsUnique();
            e.Property(x => x.TotalAmount).HasPrecision(18, 2);
            e.HasOne(x => x.Order).WithOne(x => x.Invoice).HasForeignKey<Invoice>(x => x.OrderId).OnDelete(DeleteBehavior.Restrict);
        });
        modelBuilder.Entity<ActivityLog>(e => e.HasOne(x => x.Member).WithMany(x => x.ActivityLogs)
            .HasForeignKey(x => x.MemberId).OnDelete(DeleteBehavior.Restrict));
        modelBuilder.Entity<BlogPost>(e => {
            e.HasKey(x => x.Id);
            e.Property(x => x.Title).HasMaxLength(200).IsRequired();
            e.Property(x => x.Category).HasMaxLength(80).IsRequired();
            e.Property(x => x.Summary).HasMaxLength(500).IsRequired();
            e.Property(x => x.Content).HasMaxLength(8000).IsRequired();
            e.Property(x => x.AuthorName).HasMaxLength(120).IsRequired();
        });
    }
}


