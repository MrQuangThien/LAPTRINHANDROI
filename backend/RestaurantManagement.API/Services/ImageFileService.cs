namespace RestaurantManagement.API.Services;

public static class ImageFileService
{
    public static async Task<bool> IsAllowedAsync(IFormFile file)
    {
        var ext = Path.GetExtension(file.FileName).ToLowerInvariant();
        if (ext is not ".jpg" and not ".jpeg" and not ".png" and not ".webp") return false;
        await using var stream = file.OpenReadStream();
        var header = new byte[12];
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
        Directory.CreateDirectory(folder);
        var name = $"{Guid.NewGuid():N}{Path.GetExtension(file.FileName).ToLowerInvariant()}";
        await using var stream = File.Create(Path.Combine(folder, name));
        await file.CopyToAsync(stream);
        return $"/images/{name}";
    }

    public static void Delete(IWebHostEnvironment env, string? url)
    {
        if (string.IsNullOrWhiteSpace(url) || !url.StartsWith("/images/", StringComparison.Ordinal)) return;
        var folder = Path.GetFullPath(Path.Combine(env.WebRootPath ?? Path.Combine(env.ContentRootPath, "wwwroot"), "images"));
        var file = Path.GetFullPath(Path.Combine(folder, Path.GetFileName(url)));
        if (file.StartsWith(folder + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase) && File.Exists(file))
            File.Delete(file);
    }
}
