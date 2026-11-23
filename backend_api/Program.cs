using Microsoft.EntityFrameworkCore;
using Npgsql;
using SmartTodo.Api.Data;

var builder = WebApplication.CreateBuilder(args);

// Render cung cấp biến môi trường PORT (mặc định 8080)
var port = Environment.GetEnvironmentVariable("PORT") ?? "8080";
builder.WebHost.UseUrls($"http://0.0.0.0:{port}");

builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

// Cho phép app Flutter trên mọi thiết bị Android gọi API
builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
        policy.AllowAnyOrigin().AllowAnyHeader().AllowAnyMethod());
});

// Tự động kết nối Supabase PostgreSQL qua biến môi trường DATABASE_URL (trên Render),
// hoặc dùng SQLite cục bộ khi chạy test trên máy dev chưa cấu hình DATABASE_URL.
var databaseUrl = Environment.GetEnvironmentVariable("DATABASE_URL")
    ?? builder.Configuration.GetConnectionString("DefaultConnection");

builder.Services.AddDbContext<AppDbContext>(options =>
{
    if (!string.IsNullOrWhiteSpace(databaseUrl))
    {
        var npgsqlConn = BuildNpgsqlConnectionString(databaseUrl);
        options.UseNpgsql(npgsqlConn);
    }
    else
    {
        options.UseSqlite("Data Source=workspace_dev.db");
    }
});

var app = builder.Build();

// Tự động khởi tạo 5 bảng trong Supabase PostgreSQL / SQLite nếu chưa tồn tại
using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
    db.Database.EnsureCreated();
}

// Bật Swagger UI ở cả Production để dễ kiểm thử & trình bày trong Báo cáo đồ án
app.UseSwagger();
app.UseSwaggerUI();

app.UseCors();
app.MapControllers();
app.MapGet("/", () => Results.Redirect("/swagger"));

app.Run();

static string BuildNpgsqlConnectionString(string raw)
{
    var trimmed = raw.Trim();
    if (!trimmed.StartsWith("postgres://", StringComparison.OrdinalIgnoreCase) &&
        !trimmed.StartsWith("postgresql://", StringComparison.OrdinalIgnoreCase))
    {
        return trimmed;
    }

    var uri = new Uri(trimmed);
    var userInfo = uri.UserInfo.Split(':', 2);
    var username = Uri.UnescapeDataString(userInfo[0]);
    var password = userInfo.Length > 1 ? Uri.UnescapeDataString(userInfo[1]) : string.Empty;

    var csBuilder = new NpgsqlConnectionStringBuilder
    {
        Host = uri.Host,
        Port = uri.Port > 0 ? uri.Port : 5432,
        Database = uri.AbsolutePath.TrimStart('/'),
        Username = username,
        Password = password,
        SslMode = SslMode.Require,
        Pooling = true
    };
    return csBuilder.ConnectionString;
}
