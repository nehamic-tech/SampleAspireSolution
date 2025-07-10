var builder = WebApplication.CreateBuilder(args);
builder.AddServiceDefaults();
builder.Logging.AddConsole();
var app = builder.Build();

app.MapDefaultEndpoints();

//app.UseHttpsRedirection();

app.MapGet("/service", () =>
{    
    return "this is service 2";
});

app.Run();
