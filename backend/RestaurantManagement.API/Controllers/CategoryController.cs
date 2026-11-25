using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using RestaurantManagement.API.DTOs;
using RestaurantManagement.API.Models;
using RestaurantManagement.API.Repositories;
using RestaurantManagement.API.Services;

namespace RestaurantManagement.API.Controllers;

[ApiController, Route("api/categories")]
public sealed class CategoryController(ICategoryRepository categories, IWebHostEnvironment env) : ControllerBase
{
    [HttpGet, AllowAnonymous]
    public async Task<ActionResult<PageResponse<object>>> List([FromQuery] int pageNumber = 1, [FromQuery] int pageSize = 50, [FromQuery] string? search = null)
    {
        pageNumber = Math.Max(1, pageNumber);
        pageSize = Math.Clamp(pageSize, 1, 100);
        return Ok(await categories.ListAsync(pageNumber, pageSize, search));
    }

    [HttpPost, Authorize(Roles = "Admin")]
    public async Task<IActionResult> Create(CategoryRequest request)
    {
        var name = request.Name.Trim();
        if (await categories.ExistsByNameAsync(name)) return Conflict(new { message = "Category name already exists." });
        var category = new Category { Name = name, Description = request.Description?.Trim(), IsActive = request.IsActive };
        categories.Add(category);
        await categories.SaveChangesAsync();
        return CreatedAtAction(nameof(List), new { id = category.Id }, category);
    }

    [HttpPut("{id:int}"), Authorize(Roles = "Admin")]
    public async Task<IActionResult> Update(int id, CategoryRequest request)
    {
        var category = await categories.FindByIdAsync(id);
        if (category is null) return NotFound();
        var name = request.Name.Trim();
        if (await categories.ExistsByNameAsync(name, id)) return Conflict(new { message = "Category name already exists." });
        category.Name = name;
        category.Description = request.Description?.Trim();
        category.IsActive = request.IsActive;
        await categories.SaveChangesAsync();
        return NoContent();
    }

    [HttpDelete("{id:int}"), Authorize(Roles = "Admin")]
    public async Task<IActionResult> Delete(int id)
    {
        var category = await categories.FindWithProductsAsync(id);
        if (category is null) return NotFound();
        if (category.Products.Count != 0) return Conflict(new { message = "This category still has products. Move or remove them first." });
        var oldImage = category.ImageUrl;
        categories.Remove(category);
        await categories.SaveChangesAsync();
        ImageFileService.Delete(env, oldImage);
        return NoContent();
    }

    [HttpPost("{id:int}/image"), Authorize(Roles = "Admin")]
    [RequestSizeLimit(5_000_000)]
    public async Task<IActionResult> UploadImage(int id, IFormFile file)
    {
        var category = await categories.FindByIdAsync(id);
        if (category is null) return NotFound();
        if (file.Length == 0 || file.Length > 5_000_000 || !await ImageFileService.IsAllowedAsync(file))
            return BadRequest(new { message = "Upload a JPEG, PNG or WebP image up to 5 MB." });
        var old = category.ImageUrl;
        category.ImageUrl = await ImageFileService.SaveAsync(env, file);
        await categories.SaveChangesAsync();
        ImageFileService.Delete(env, old);
        return Ok(new { category.ImageUrl });
    }
}
