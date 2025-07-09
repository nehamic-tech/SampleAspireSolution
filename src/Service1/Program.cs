var builder = WebApplication.CreateBuilder(args);

builder.AddServiceDefaults();

var service2Url = Environment.GetEnvironmentVariable("SERVICE2_URL");
var service3Url = Environment.GetEnvironmentVariable("SERVICE3_URL");

builder.Services.AddHttpClient("Service2", client =>
{
    client.BaseAddress = new Uri(service2Url!);
});

builder.Services.AddHttpClient("Service3", client =>
{
    client.BaseAddress = new Uri(service3Url!);
});

var app = builder.Build();

app.MapDefaultEndpoints();

//app.UseHttpsRedirection();

app.MapGet("/service", () =>
{    
    return "this is service 1";
});

app.MapGet("/internal", async (IHttpClientFactory httpClientFactory) =>
{
    var client = httpClientFactory.CreateClient("Service2");
    var response = await client.GetAsync("/service");
    return await response.Content.ReadAsStringAsync();
});

app.MapGet("/external", async (IHttpClientFactory httpClientFactory) =>
{
    var client = httpClientFactory.CreateClient("Service3");
    var response = await client.GetAsync("/service");
    return await response.Content.ReadAsStringAsync();
});

app.Run();
