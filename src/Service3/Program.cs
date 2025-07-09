var builder = WebApplication.CreateBuilder(args);

builder.AddServiceDefaults();

var app = builder.Build();
app.MapDefaultEndpoints();


//app.UseHttpsRedirection();

app.MapGet("/service", () =>
{    
    return "this is service 3";
});

app.Run();
