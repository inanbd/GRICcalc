using System.Net;
using System.Text.RegularExpressions;
using GirCalculator.Web.Services;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Microsoft.Extensions.Hosting;
using Xunit;

namespace GirCalculator.Tests;

/// <summary>Captures what would have been sent, so no test posts real mail.</summary>
public sealed class FakeEmailSender : IEmailSender
{
    public List<ContactMessage> Sent { get; } = new();

    /// <summary>Set to simulate an SMTP server that will not take the message.</summary>
    public Exception? ThrowOnSend { get; set; }

    public Task SendContactMessageAsync(
        ContactMessage message,
        CancellationToken cancellationToken = default)
    {
        if (ThrowOnSend is not null) throw ThrowOnSend;
        Sent.Add(message);
        return Task.CompletedTask;
    }
}

public sealed class SiteFactory : WebApplicationFactory<Program>
{
    public FakeEmailSender Emails { get; } = new();

    /// <summary>Configuration overlaid on appsettings.json for one test run.</summary>
    public Dictionary<string, string?> Settings { get; } = new()
    {
        ["Email:Host"] = "smtp.test",
        ["Email:FromAddress"] = "site@test",
        ["Email:ToAddress"] = "owner@test",
    };

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment(Environments.Development);
        builder.ConfigureAppConfiguration((_, config) =>
            config.AddInMemoryCollection(Settings));
        builder.ConfigureServices(services =>
        {
            services.RemoveAll<IEmailSender>();
            services.AddSingleton<IEmailSender>(Emails);
        });
    }

    public HttpClient CreateFollowingClient() =>
        CreateClient(new WebApplicationFactoryClientOptions
        {
            AllowAutoRedirect = false,
        });
}

public class PageTests
{
    [Theory]
    [InlineData("/")]
    [InlineData("/HowItWorks")]
    [InlineData("/Disclaimer")]
    [InlineData("/Contact")]
    public async Task Every_page_renders(string url)
    {
        using var factory = new SiteFactory();
        using HttpClient client = factory.CreateFollowingClient();

        HttpResponseMessage response = await client.GetAsync(url);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Contains("NICU GIR Calculator", await response.Content.ReadAsStringAsync());
    }

    [Fact]
    public async Task The_calculator_ships_its_engine_and_posts_nothing()
    {
        using var factory = new SiteFactory();
        using HttpClient client = factory.CreateFollowingClient();

        string html = await client.GetStringAsync("/");

        // The page loads its module entry point, and the engine is served.
        Assert.Contains("/js/main.js", html);
        Assert.Equal(
            HttpStatusCode.OK,
            (await client.GetAsync("/js/gir.js")).StatusCode);

        // Nothing on the calculator can post: the only form on the site is the
        // contact form, on its own page.
        Assert.DoesNotContain("<form", html, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task Responses_carry_a_policy_that_keeps_data_on_the_page()
    {
        using var factory = new SiteFactory();
        using HttpClient client = factory.CreateFollowingClient();

        HttpResponseMessage response = await client.GetAsync("/");

        string csp = Assert.Single(response.Headers.GetValues("Content-Security-Policy"));
        Assert.Contains("default-src 'self'", csp);
        Assert.Contains("connect-src 'self'", csp);
        Assert.Contains("form-action 'self'", csp);
        Assert.Equal("nosniff", Assert.Single(response.Headers.GetValues("X-Content-Type-Options")));
    }

    [Fact]
    public async Task The_play_store_button_is_hidden_until_a_url_is_configured()
    {
        using var factory = new SiteFactory();
        using HttpClient client = factory.CreateFollowingClient();

        string html = await client.GetStringAsync("/");

        Assert.DoesNotContain("Get it on Google Play", html);
    }

    [Fact]
    public async Task The_play_store_button_appears_once_the_url_is_set()
    {
        using var factory = new SiteFactory();
        factory.Settings["Site:PlayStoreUrl"] =
            "https://play.google.com/store/apps/details?id=com.griccalc.griccalc";
        using HttpClient client = factory.CreateFollowingClient();

        string html = await client.GetStringAsync("/");

        Assert.Contains("Get it on Google Play", html);
        Assert.Contains("play.google.com/store/apps/details?id=com.griccalc.griccalc", html);
    }
}

public class ContactFormTests
{
    /// <summary>Pulls the antiforgery token out of the rendered form.</summary>
    private static string ExtractToken(string html)
    {
        Match match = Regex.Match(
            html,
            """<input name="__RequestVerificationToken" type="hidden" value="([^"]+)" />""");
        Assert.True(match.Success, "The contact form should carry an antiforgery token.");
        return match.Groups[1].Value;
    }

    private static async Task<(HttpClient client, string token)> OpenFormAsync(
        SiteFactory factory)
    {
        HttpClient client = factory.CreateFollowingClient();
        string html = await client.GetStringAsync("/Contact");
        return (client, ExtractToken(html));
    }

    private static FormUrlEncodedContent Body(
        string token,
        string name = "Dr Ada",
        string email = "ada@hospital.example",
        string subject = "A question",
        string message = "Does the feed maths look right to you?",
        string website = "")
        => new(new Dictionary<string, string>
        {
            ["__RequestVerificationToken"] = token,
            ["Input.Name"] = name,
            ["Input.Email"] = email,
            ["Input.Subject"] = subject,
            ["Input.Message"] = message,
            ["Input.Website"] = website,
        });

    [Fact]
    public async Task A_valid_message_is_sent_and_confirmed()
    {
        using var factory = new SiteFactory();
        (HttpClient client, string token) = await OpenFormAsync(factory);

        HttpResponseMessage response =
            await client.PostAsync("/Contact", Body(token));

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Contains(
            "your message has been sent",
            await response.Content.ReadAsStringAsync());

        ContactMessage sent = Assert.Single(factory.Emails.Sent);
        Assert.Equal("Dr Ada", sent.Name);
        Assert.Equal("ada@hospital.example", sent.Email);
        Assert.Equal("A question", sent.Subject);
        Assert.Equal("Does the feed maths look right to you?", sent.Message);
    }

    [Fact]
    public async Task Whitespace_around_the_fields_is_trimmed_before_sending()
    {
        using var factory = new SiteFactory();
        (HttpClient client, string token) = await OpenFormAsync(factory);

        await client.PostAsync(
            "/Contact",
            Body(token, name: "  Dr Ada  ", email: "  ada@hospital.example  "));

        ContactMessage sent = Assert.Single(factory.Emails.Sent);
        Assert.Equal("Dr Ada", sent.Name);
        Assert.Equal("ada@hospital.example", sent.Email);
    }

    [Theory]
    [InlineData("", "ada@hospital.example", "Subject", "A long enough message here.")]
    [InlineData("Ada", "not-an-email", "Subject", "A long enough message here.")]
    [InlineData("Ada", "ada@hospital.example", "", "A long enough message here.")]
    [InlineData("Ada", "ada@hospital.example", "Subject", "short")]
    public async Task An_incomplete_message_is_refused_and_nothing_is_sent(
        string name, string email, string subject, string message)
    {
        using var factory = new SiteFactory();
        (HttpClient client, string token) = await OpenFormAsync(factory);

        HttpResponseMessage response = await client.PostAsync(
            "/Contact",
            Body(token, name, email, subject, message));

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.DoesNotContain(
            "your message has been sent",
            await response.Content.ReadAsStringAsync());
        Assert.Empty(factory.Emails.Sent);
    }

    [Fact]
    public async Task A_filled_honeypot_is_dropped_without_a_hint_that_it_was()
    {
        using var factory = new SiteFactory();
        (HttpClient client, string token) = await OpenFormAsync(factory);

        HttpResponseMessage response = await client.PostAsync(
            "/Contact",
            Body(token, website: "https://spam.example"));

        // Answered as though it worked, so there is nothing to tune against.
        Assert.Contains(
            "your message has been sent",
            await response.Content.ReadAsStringAsync());
        Assert.Empty(factory.Emails.Sent);
    }

    [Fact]
    public async Task A_post_without_the_antiforgery_token_is_rejected()
    {
        using var factory = new SiteFactory();
        using HttpClient client = factory.CreateFollowingClient();

        HttpResponseMessage response = await client.PostAsync(
            "/Contact",
            new FormUrlEncodedContent(new Dictionary<string, string>
            {
                ["Input.Name"] = "Dr Ada",
                ["Input.Email"] = "ada@hospital.example",
                ["Input.Subject"] = "A question",
                ["Input.Message"] = "A long enough message here.",
            }));

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Empty(factory.Emails.Sent);
    }

    [Fact]
    public async Task A_delivery_failure_says_so_rather_than_claiming_success()
    {
        using var factory = new SiteFactory();
        factory.Emails.ThrowOnSend = new InvalidOperationException("smtp down");
        (HttpClient client, string token) = await OpenFormAsync(factory);

        HttpResponseMessage response =
            await client.PostAsync("/Contact", Body(token));

        string html = await response.Content.ReadAsStringAsync();
        Assert.DoesNotContain("your message has been sent", html);
        Assert.Contains("could not be sent", html);
        // The reason stays in the log, not on the page.
        Assert.DoesNotContain("smtp down", html);
    }

    [Fact]
    public async Task With_no_smtp_configured_the_form_is_not_offered()
    {
        using var factory = new SiteFactory();
        factory.Settings["Email:Host"] = "";
        using HttpClient client = factory.CreateFollowingClient();

        string html = await client.GetStringAsync("/Contact");

        Assert.Contains("not configured on this deployment", html);
        Assert.DoesNotContain("__RequestVerificationToken", html);
    }
}
