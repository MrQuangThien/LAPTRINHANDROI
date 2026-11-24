using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using RestaurantManagement.API.Data;
using RestaurantManagement.API.DTOs;
using RestaurantManagement.API.Models;

namespace RestaurantManagement.API.Controllers;

[ApiController, Route("api/products")]
public sealed class ProductController(RestaurantDbContext db, IWebHostEnvironment env) : ControllerBase
{
    [HttpGet, AllowAnonymous]
    public async Task<ActionResult<PageResponse<object>>> List([FromQuery] int pageNumber = 1,
        [FromQuery] int pageSize = 20, [FromQuery] string? search = null, [FromQuery] int? categoryId = null,
        [FromQuery] string? sortBy = null, [FromQuery] int? excludeId = null)
    {
        pageNumber = Math.Max(1, pageNumber); pageSize = Math.Clamp(pageSize, 1, 100);
        var q = db.Products.AsNoTracking().Include(p => p.Category).AsQueryable();
        if (!string.IsNullOrWhiteSpace(search)) q = q.Where(p => p.Name.Contains(search));
        if (categoryId.HasValue) q = q.Where(p => p.CategoryId == categoryId);
        if (excludeId.HasValue) q = q.Where(p => p.Id != excludeId.Value);
        var total = await q.CountAsync();
        var ordered = string.Equals(sortBy, "newest", StringComparison.OrdinalIgnoreCase)
            ? q.OrderByDescending(p => p.CreatedAt).ThenByDescending(p => p.Id)
            : q.OrderBy(p => p.Name);
        var rows = await ordered.Skip((pageNumber - 1) * pageSize).Take(pageSize)
            .Select(p => new { p.Id, p.CategoryId, Category = p.Category.Name, CategoryIsActive = p.Category.IsActive, p.Name, p.Description, p.Price, p.ImageUrl, p.IsAvailable, p.CreatedAt }).ToListAsync();
        return Ok(new PageResponse<object>(rows.Cast<object>().ToList(), pageNumber, pageSize, total));
    }

    [HttpGet("{id:int}"), AllowAnonymous]
    public async Task<IActionResult> Get(int id)
    {
        var p = await db.Products.AsNoTracking().Include(x => x.Category).SingleOrDefaultAsync(x => x.Id == id);
        return p is null ? NotFound() : Ok(new { p.Id, p.CategoryId, Category = p.Category.Name, CategoryIsActive = p.Category.IsActive, p.Name, p.Description, p.Price, p.ImageUrl, p.IsAvailable, p.CreatedAt });
    }

    [HttpPost, Authorize(Roles = "Admin")]
    public async Task<IActionResult> Create(ProductRequest request)
    {
        if (!await db.Categories.AnyAsync(x => x.Id == request.CategoryId && x.IsActive)) return BadRequest(new { message = "An active category is required." });
        var p = new Product { CategoryId = request.CategoryId, Name = request.Name.Trim(), Description = request.Description?.Trim(), Price = request.Price, IsAvailable = request.IsAvailable };
        db.Products.Add(p); await db.SaveChangesAsync(); return CreatedAtAction(nameof(Get), new { id = p.Id }, p);
    }

    [HttpPut("{id:int}"), Authorize(Roles = "Admin")]
    public async Task<IActionResult> Update(int id, ProductRequest request)
    {
        var p = await db.Products.FindAsync(id); if (p is null) return NotFound();
        if (!await db.Categories.AnyAsync(x => x.Id == request.CategoryId && (x.IsActive || x.Id == p.CategoryId)))
            return BadRequest(new { message = "An active category is required." });
        p.CategoryId = request.CategoryId; p.Name = request.Name.Trim(); p.Description = request.Description?.Trim(); p.Price = request.Price; p.IsAvailable = request.IsAvailable;
        await db.SaveChangesAsync(); return NoContent();
    }

    [HttpDelete("{id:int}"), Authorize(Roles = "Admin")]
    public async Task<IActionResult> Delete(int id)
    {
        var p = await db.Products.Include(x => x.OrderDetails).SingleOrDefaultAsync(x => x.Id == id);
        if (p is null) return NotFound();
        var oldImage = p.ImageUrl;
        if (p.OrderDetails.Count != 0)
        {
            p.IsAvailable = false;
            p.ImageUrl = null;
            await db.SaveChangesAsync();
            ImageFiles.Delete(env, oldImage);
            return Ok(new { message = "Món đã có lịch sử đơn hàng nên hệ thống tự động chuyển sang trạng thái Ngừng bán." });
        }
        db.Products.Remove(p);
        await db.SaveChangesAsync();
        ImageFiles.Delete(env, oldImage);
        return Ok(new { message = "Đã xóa món và hình ảnh khỏi hệ thống." });
    }

    [HttpPost("{id:int}/image"), Authorize(Roles = "Admin")]
    [RequestSizeLimit(5_000_000)]
    public async Task<IActionResult> UploadImage(int id, IFormFile file)
    {
        var p = await db.Products.FindAsync(id); if (p is null) return NotFound();
        if (file.Length == 0 || file.Length > 5_000_000 || !await ImageFiles.IsAllowedAsync(file)) return BadRequest(new { message = "Upload a JPEG, PNG or WebP image up to 5 MB." });
        var old = p.ImageUrl; p.ImageUrl = await ImageFiles.SaveAsync(env, file); await db.SaveChangesAsync(); ImageFiles.Delete(env, old);
        return Ok(new { p.ImageUrl });
    }
}



