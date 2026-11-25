using Microsoft.EntityFrameworkCore;
using RestaurantManagement.API.Data;
using RestaurantManagement.API.DTOs;
using RestaurantManagement.API.Models;

namespace RestaurantManagement.API.Repositories;

public interface IProductRepository
{
    Task<PageResponse<object>> ListAsync(int pageNumber, int pageSize, int? categoryId, string? search, bool? availableOnly);
    Task<object?> GetDetailAsync(int id);
    Task<Product?> FindByIdAsync(int id);
    Task<Product?> FindWithOrderDetailsAsync(int id);
    Task<bool> IsCategoryActiveAsync(int categoryId, int? allowExistingCategoryId = null);
    void Add(Product product);
    void Remove(Product product);
    Task SaveChangesAsync();
}

public sealed class ProductRepository(RestaurantDbContext db) : IProductRepository
{
    public async Task<PageResponse<object>> ListAsync(int pageNumber, int pageSize, int? categoryId, string? search, bool? availableOnly)
    {
        var q = db.Products.AsNoTracking().Include(p => p.Category).AsQueryable();
        if (categoryId is not null) q = q.Where(p => p.CategoryId == categoryId);
        if (availableOnly == true) q = q.Where(p => p.IsAvailable && p.Category.IsActive);
        if (!string.IsNullOrWhiteSpace(search)) q = q.Where(p => p.Name.Contains(search));
        var total = await q.CountAsync();
        var rows = await q.OrderBy(p => p.Name).Skip((pageNumber - 1) * pageSize).Take(pageSize)
            .Select(p => new { p.Id, p.CategoryId, CategoryName = p.Category.Name, p.Name, p.Description, p.Price, p.ImageUrl, p.IsAvailable, p.CreatedAt })
            .ToListAsync();
        return new PageResponse<object>(rows.Cast<object>().ToList(), pageNumber, pageSize, total);
    }

    public async Task<object?> GetDetailAsync(int id) =>
        await db.Products.AsNoTracking().Include(x => x.Category).Where(x => x.Id == id)
            .Select(x => new { x.Id, x.CategoryId, CategoryName = x.Category.Name, x.Name, x.Description, x.Price, x.ImageUrl, x.IsAvailable })
            .SingleOrDefaultAsync();

    public Task<Product?> FindByIdAsync(int id) => db.Products.FindAsync(id).AsTask();

    public Task<Product?> FindWithOrderDetailsAsync(int id) =>
        db.Products.Include(x => x.OrderDetails).SingleOrDefaultAsync(x => x.Id == id);

    public Task<bool> IsCategoryActiveAsync(int categoryId, int? allowExistingCategoryId = null) =>
        allowExistingCategoryId is null
            ? db.Categories.AnyAsync(x => x.Id == categoryId && x.IsActive)
            : db.Categories.AnyAsync(x => x.Id == categoryId && (x.IsActive || x.Id == allowExistingCategoryId));

    public void Add(Product product) => db.Products.Add(product);
    public void Remove(Product product) => db.Products.Remove(product);
    public Task SaveChangesAsync() => db.SaveChangesAsync();
}
