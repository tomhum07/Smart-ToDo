using Microsoft.AspNetCore.Mvc;
using SmartTodo.Api.Data;

namespace SmartTodo.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class HealthController(AppDbContext db) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> Get()
    {
        var canConnect = await db.Database.CanConnectAsync();
        return Ok(new
        {
            status = "ok",
            database = canConnect ? "connected" : "disconnected",
            provider = db.Database.ProviderName,
            timestampUtc = DateTimeOffset.UtcNow
        });
    }
}
