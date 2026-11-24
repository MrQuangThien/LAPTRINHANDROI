using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using RestaurantManagement.API.Data;
using RestaurantManagement.API.DTOs;
using RestaurantManagement.API.Models;

namespace RestaurantManagement.API.Controllers;

[ApiController, Route("api/categories")]
public sealed class CategoryController(RestaurantDbContext db, IWebHostEnvironment env) : ControllerBase
{
    [HttpGet, AllowAnonymous]
    public async Task<ActionResult<PageResponse<object>>> List([FromQuery] int pageNumber = 1, [FromQuery] int pageSize = 50, [FromQuery] string? search = null)
    {
        pageNumber = Math.Max(1, pageNumber); pageSize = Math.Clamp(pageSize, 1, 100);
        var q = db.Categories.AsNoTracking().AsQueryable();
        if (!string.IsNullOrWhiteSpace(search)) q = q.Where(x => x.Name.Contains(search));
        var total = await q.CountAsync(); var rows = await q.OrderBy(x => x.Name).Skip((pageNumber - 1) * pageSize).Take(pageSize)
            .Select(x => new { x.Id, x.Name, x.Description, x.ImageUrl, x.IsActive, x.CreatedAt }).ToListAsync();
        return Ok(new PageResponse<object>(rows.Cast<object>().ToList(), pageNumber, pageSize, total));
    }

    [HttpPost, Authorize(Roles = "Admin")]
    public async Task<IActionResult> Create(CategoryRequest request)
    {
        var name = request.Name.Trim();
        if (await db.Categories.AnyAsync(x => x.Name == name)) return Conflict(new { message = "Category name already exists." });
        var category = new Category { Name = name, Description = request.Description?.Trim(), IsActive = request.IsActive };
        db.Categories.Add(category); await db.SaveChangesAsync(); return CreatedAtAction(nameof(List), new { id = category.Id }, category);
    }

    [HttpPut("{id:int}"), Authorize(Roles = "Admin")]
    public async Task<IActionResult> Update(int id, CategoryRequest request)
    {
        var category = await db.Categories.FindAsync(id); if (category is null) return NotFound();
        var name = request.Name.Trim();
        if (await db.Categories.AnyAsync(x => x.Id != id && x.Name == name)) return Conflict(new { message = "Category name already exists." });
        category.Name = name; category.Description = request.Description?.Trim(); category.IsActive = request.IsActive;
        await db.SaveChangesAsync(); return NoContent();
    }

    [HttpDelete("{id:int}"), Authorize(Roles = "Admin")]
    public async Task<IActionResult> Delete(int id)
    {
        var category = await db.Categories.Include(x => x.Products).SingleOrDefaultAsync(x => x.Id == id);
        if (category is null) return NotFound();
        if (category.Products.Count != 0) return Conflict(new { message = "This category still has products. Move or remove them first." });
        var oldImage = category.ImageUrl; db.Categories.Remove(category); await db.SaveChangesAsync(); DeleteImage(oldImage); return NoContent();
    }

    [HttpPost("{id:int}/image"), Authorize(Roles = "Admin")]
    [RequestSizeLimit(5_000_000)]
    public async Task<IActionResult> UploadImage(int id, IFormFile file)
    {
        var category = await db.Categories.FindAsync(id); if (category is null) return NotFound();
        if (file.Length == 0 || file.Length > 5_000_000 || !await ImageFiles.IsAllowedAsync(file)) return BadRequest(new { message = "Upload a JPEG, PNG or WebP image up to 5 MB." });
        var old = category.ImageUrl; category.ImageUrl = await ImageFiles.SaveAsync(env, file);
        await db.SaveChangesAsync(); DeleteImage(old); return Ok(new { category.ImageUrl });
    }

    private void DeleteImage(string? url) => ImageFiles.Delete(env, url);
}

internal static class ImageFiles
{
    public static async Task<bool> IsAllowedAsync(IFormFile file)
    {
        var ext = Path.GetExtension(file.FileName).ToLowerInvariant();
        if (ext is not ".jpg" and not ".jpeg" and not ".png" and not ".webp") return false;
        await using var stream = file.OpenReadStream(); var header = new byte[12];
        var count = await stream.ReadAsync(header);
        if (count < 4) return false;
        var jpeg = header[0] == 0xFF && header[1] == 0xD8 && header[2] == 0xFF;
        var png = count >= 8 && header.AsSpan(0, 8).SequenceEqual(new byte[] { 137, 80, 78, 71, 13, 10, 26, 10 });
        var webp = count >= 12 && header.AsSpan(0, 4).SequenceEqual("RIFF"u8) && header.AsSpan(8, 4).SequenceEqual("WEBP"u8);
        return (ext is ".jpg" or ".jpeg") && jpeg || ext == ".png" && png || ext == ".webp" && webp;
    }
    public static async Task<string> SaveAsync(IWebHostEnvironment env, IFormFile file)
    {
        var folder = Path.Combine(env.WebRootPath ?? Path.Combine(env.ContentRootPath, "wwwroot"), "images");
        Directory.CreateDirectory(folder); var name = $"{Guid.NewGuid():N}{Path.GetExtension(file.FileName).ToLowerInvariant()}";
        await using var stream = System.IO.File.Create(Path.Combine(folder, name)); await file.CopyToAsync(stream);
        return $"/images/{name}";
    }
    public static void Delete(IWebHostEnvironment env, string? url)
    {
        if (string.IsNullOrWhiteSpace(url) || !url.StartsWith("/images/", StringComparison.Ordinal)) return;
        var folder = Path.GetFullPath(Path.Combine(env.WebRootPath ?? Path.Combine(env.ContentRootPath, "wwwroot"), "images"));
        var file = Path.GetFullPath(Path.Combine(folder, Path.GetFileName(url)));
        if (file.StartsWith(folder + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase) && System.IO.File.Exists(file)) System.IO.File.Delete(file);
    }
}





