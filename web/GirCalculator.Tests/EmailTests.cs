using GirCalculator.Web.Services;
using MimeKit;
using Xunit;

namespace GirCalculator.Tests;

public class EmailOptionsTests
{
    private static EmailOptions Configured() => new()
    {
        Host = "smtp.example.com",
        FromAddress = "site@example.com",
        ToAddress = "owner@example.com",
    };

    [Fact]
    public void IsConfigured_is_false_until_the_essentials_are_set()
    {
        Assert.False(new EmailOptions().IsConfigured);
    }

    [Theory]
    [InlineData("", "site@example.com", "owner@example.com")]
    [InlineData("smtp.example.com", "", "owner@example.com")]
    [InlineData("smtp.example.com", "site@example.com", "")]
    [InlineData("   ", "site@example.com", "owner@example.com")]
    public void IsConfigured_is_false_when_any_essential_is_missing(
        string host, string from, string to)
    {
        var options = new EmailOptions
        {
            Host = host,
            FromAddress = from,
            ToAddress = to,
        };
        Assert.False(options.IsConfigured);
    }

    [Fact]
    public void IsConfigured_is_true_once_host_from_and_to_are_present()
    {
        Assert.True(Configured().IsConfigured);
    }

    [Fact]
    public void Defaults_target_starttls_on_the_submission_port()
    {
        var options = new EmailOptions();
        Assert.Equal(587, options.Port);
        Assert.True(options.UseStartTls);
    }
}

public class SmtpEmailSenderTests
{
    private static EmailOptions Settings() => new()
    {
        Host = "smtp.example.com",
        FromAddress = "site@example.com",
        FromName = "NICU GIR Calculator",
        ToAddress = "owner@example.com",
        ToName = "Owner",
    };

    private static ContactMessage Message(string subject = "A question") =>
        new("Dr Ada", "ada@hospital.example", subject, "Is the feed maths right?");

    [Fact]
    public void From_is_the_configured_account_so_spf_still_passes()
    {
        MimeMessage mail = SmtpEmailSender.BuildMessage(Message(), Settings());

        MailboxAddress from = Assert.IsType<MailboxAddress>(Assert.Single(mail.From));
        Assert.Equal("site@example.com", from.Address);
    }

    [Fact]
    public void Reply_to_is_the_sender_so_a_reply_reaches_them()
    {
        MimeMessage mail = SmtpEmailSender.BuildMessage(Message(), Settings());

        MailboxAddress replyTo =
            Assert.IsType<MailboxAddress>(Assert.Single(mail.ReplyTo));
        Assert.Equal("ada@hospital.example", replyTo.Address);
        Assert.Equal("Dr Ada", replyTo.Name);
    }

    [Fact]
    public void Message_goes_to_the_configured_recipient()
    {
        MimeMessage mail = SmtpEmailSender.BuildMessage(Message(), Settings());

        MailboxAddress to = Assert.IsType<MailboxAddress>(Assert.Single(mail.To));
        Assert.Equal("owner@example.com", to.Address);
    }

    [Fact]
    public void Body_carries_every_field_the_sender_filled_in()
    {
        MimeMessage mail = SmtpEmailSender.BuildMessage(Message(), Settings());

        string body = Assert.IsType<TextPart>(mail.Body).Text;
        Assert.Contains("Dr Ada", body);
        Assert.Contains("ada@hospital.example", body);
        Assert.Contains("A question", body);
        Assert.Contains("Is the feed maths right?", body);
    }

    [Fact]
    public void Subject_is_prefixed_so_it_is_recognisable_in_a_mailbox()
    {
        Assert.Equal(
            "[GIR Calculator] A question",
            SmtpEmailSender.BuildSubject("A question"));
    }

    [Theory]
    [InlineData("Hello\r\nBcc: someone@evil.example")]
    [InlineData("Hello\nX-Injected: yes")]
    public void Subject_cannot_smuggle_in_another_header(string subject)
    {
        string built = SmtpEmailSender.BuildSubject(subject);

        Assert.DoesNotContain('\r', built);
        Assert.DoesNotContain('\n', built);
    }

    [Fact]
    public void Subject_is_capped_so_it_cannot_run_away()
    {
        string built = SmtpEmailSender.BuildSubject(new string('x', 400));

        Assert.True(built.Length <= "[GIR Calculator] ".Length + 150);
    }

    [Theory]
    [InlineData("")]
    [InlineData("    ")]
    public void An_empty_subject_still_produces_something_readable(string subject)
    {
        Assert.Equal(
            "[GIR Calculator] Contact form",
            SmtpEmailSender.BuildSubject(subject));
    }
}

public class SiteOptionsTests
{
    [Fact]
    public void No_play_store_url_means_no_button()
    {
        Assert.False(new SiteOptions().HasPlayStoreUrl);
    }

    [Theory]
    [InlineData("https://play.google.com/store/apps/details?id=com.griccalc.griccalc")]
    [InlineData("http://example.com/app")]
    public void An_http_url_shows_the_button(string url)
    {
        Assert.True(new SiteOptions { PlayStoreUrl = url }.HasPlayStoreUrl);
    }

    [Theory]
    [InlineData("javascript:alert(1)")]
    [InlineData("not a url")]
    [InlineData("   ")]
    [InlineData("ftp://example.com/app")]
    public void Anything_that_is_not_http_is_refused(string url)
    {
        // A stray configuration value must not become a javascript: link.
        Assert.False(new SiteOptions { PlayStoreUrl = url }.HasPlayStoreUrl);
    }
}
