using Microsoft.EntityFrameworkCore;
using RestaurantManagement.API.Data;
using RestaurantManagement.API.DTOs;
using RestaurantManagement.API.Models;

namespace RestaurantManagement.API.Repositories;

public interface ICategoryRepository
{
    Task<PageResponse<object>> ListAsync(int pageNumber, int pageSize, string? search);
    Task<bool> ExistsByNameAsync(string name, int? excludeId = null);
    Task<Category?> FindByIdAsync(int id);
    Task<Category?> FindWithProductsAsync(int id);
    void Add(Category category);
    void Remove(Category category);
    Task SaveChangesAsync();
}

public sealed class CategoryRepository(RestaurantDbContext db) : ICategoryRepository
{
    public async Task<PageResponse<object>> ListAsync(int pageNumber, int pageSize, string? search)
    {
        var q = db.Categories.AsNoTracking().AsQueryable();
        if (!string.IsNullOrWhiteSpace(search)) q = q.Where(x => x.Name.Contains(search));
        var total = await q.CountAsync();
        var rows = await q.OrderBy(x => x.Name).Skip((pageNumber - 1) * pageSize).Take(pageSize)
            .Select(x => new { x.Id, x.Name, x.Description, x.ImageUrl, x.IsActive, x.CreatedAt })
            .ToListAsync();
        return new PageResponse<object>(rows.Cast<object>().ToList(), pageNumber, pageSize, total);
    }

    public Task<bool> ExistsByNameAsync(string name, int? excludeId = null) =>
        excludeId is null
            ? db.Categories.AnyAsync(x => x.Name == name)
            : db.Categories.AnyAsync(x => x.Id != excludeId && x.Name == name);

    public Task<Category?> FindByIdAsync(int id) => db.Categories.FindAsync(id).AsTask();

    public Task<Category?> FindWithProductsAsync(int id) =>
        db.Categories.Include(x => x.Products).SingleOrDefaultAsync(x => x.Id == id);

    public void Add(Category category) => db.Categories.Add(category);
    public void Remove(Category category) => db.Categories.Remove(category);
    public Task SaveChangesAsync() => db.SaveChangesAsync();
}
