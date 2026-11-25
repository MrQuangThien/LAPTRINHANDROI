using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using RestaurantManagement.API.DTOs;
using RestaurantManagement.API.Models;
using RestaurantManagement.API.Repositories;
using RestaurantManagement.API.Services;

namespace RestaurantManagement.API.Controllers;

[ApiController, Route("api/products")]
public sealed class ProductController(IProductRepository products, IWebHostEnvironment env) : ControllerBase
{
    [HttpGet, AllowAnonymous]
    public async Task<ActionResult<PageResponse<object>>> List([FromQuery] int pageNumber = 1,
        [FromQuery] int pageSize = 50, [FromQuery] int? categoryId = null, [FromQuery] string? search = null,
        [FromQuery] bool? availableOnly = null)
    {
        pageNumber = Math.Max(1, pageNumber);
        pageSize = Math.Clamp(pageSize, 1, 100);
        return Ok(await products.ListAsync(pageNumber, pageSize, categoryId, search, availableOnly));
    }

    [HttpGet("{id:int}"), AllowAnonymous]
    public async Task<IActionResult> Get(int id)
    {
        var p = await products.GetDetailAsync(id);
        return p is null ? NotFound() : Ok(p);
    }

    [HttpPost, Authorize(Roles = "Admin")]
    public async Task<IActionResult> Create(ProductRequest request)
    {
        if (!await products.IsCategoryActiveAsync(request.CategoryId))
            return BadRequest(new { message = "An active category is required." });
        var p = new Product { CategoryId = request.CategoryId, Name = request.Name.Trim(), Description = request.Description?.Trim(), Price = request.Price, IsAvailable = request.IsAvailable };
        products.Add(p);
        await products.SaveChangesAsync();
        return CreatedAtAction(nameof(Get), new { id = p.Id }, p);
    }

    [HttpPut("{id:int}"), Authorize(Roles = "Admin")]
    public async Task<IActionResult> Update(int id, ProductRequest request)
    {
        var p = await products.FindByIdAsync(id);
        if (p is null) return NotFound();
        if (!await products.IsCategoryActiveAsync(request.CategoryId, p.CategoryId))
            return BadRequest(new { message = "An active category is required." });
        p.CategoryId = request.CategoryId;
        p.Name = request.Name.Trim();
        p.Description = request.Description?.Trim();
        p.Price = request.Price;
        p.IsAvailable = request.IsAvailable;
        await products.SaveChangesAsync();
        return NoContent();
    }

    [HttpDelete("{id:int}"), Authorize(Roles = "Admin")]
    public async Task<IActionResult> Delete(int id)
    {
        var p = await products.FindWithOrderDetailsAsync(id);
        if (p is null) return NotFound();
        var oldImage = p.ImageUrl;
        if (p.OrderDetails.Count != 0)
        {
            p.IsAvailable = false;
            p.ImageUrl = null;
            await products.SaveChangesAsync();
            ImageFileService.Delete(env, oldImage);
            return Ok(new { message = "Món đã có lịch sử đơn hàng nên hệ thống tự động chuyển sang trạng thái Ngừng bán." });
        }
        products.Remove(p);
        await products.SaveChangesAsync();
        ImageFileService.Delete(env, oldImage);
        return Ok(new { message = "Đã xóa món và hình ảnh khỏi hệ thống." });
    }

    [HttpPost("{id:int}/image"), Authorize(Roles = "Admin")]
    [RequestSizeLimit(5_000_000)]
    public async Task<IActionResult> UploadImage(int id, IFormFile file)
    {
        var p = await products.FindByIdAsync(id);
        if (p is null) return NotFound();
        if (file.Length == 0 || file.Length > 5_000_000 || !await ImageFileService.IsAllowedAsync(file))
            return BadRequest(new { message = "Upload a JPEG, PNG or WebP image up to 5 MB." });
        var old = p.ImageUrl;
        p.ImageUrl = await ImageFileService.SaveAsync(env, file);
        await products.SaveChangesAsync();
        ImageFileService.Delete(env, old);
        return Ok(new { p.ImageUrl });
    }
}
