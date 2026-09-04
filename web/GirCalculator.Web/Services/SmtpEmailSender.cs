using System.Text;
using MailKit.Net.Smtp;
using MailKit.Security;
using Microsoft.Extensions.Options;
using MimeKit;

namespace GirCalculator.Web.Services;

/// <summary>Sends contact messages over SMTP using the configured account.</summary>
public sealed class SmtpEmailSender : IEmailSender
{
    private readonly IOptionsMonitor<EmailOptions> _options;
    private readonly ILogger<SmtpEmailSender> _logger;

    public SmtpEmailSender(
        IOptionsMonitor<EmailOptions> options,
        ILogger<SmtpEmailSender> logger)
    {
        _options = options;
        _logger = logger;
    }

    public async Task SendContactMessageAsync(
        ContactMessage message,
        CancellationToken cancellationToken = default)
    {
        EmailOptions settings = _options.CurrentValue;
        if (!settings.IsConfigured)
        {
            throw new InvalidOperationException(
                "Email is not configured. Set Email:Host, Email:FromAddress "
                + "and Email:ToAddress.");
        }

        MimeMessage mail = BuildMessage(message, settings);

        using var client = new SmtpClient
        {
            Timeout = (int)TimeSpan
                .FromSeconds(settings.TimeoutSeconds)
                .TotalMilliseconds,
        };

        SecureSocketOptions security = settings.UseStartTls
            ? SecureSocketOptions.StartTls
            : SecureSocketOptions.SslOnConnect;

        await client.ConnectAsync(
            settings.Host,
            settings.Port,
            security,
            cancellationToken);

        if (!string.IsNullOrWhiteSpace(settings.UserName))
        {
            await client.AuthenticateAsync(
                settings.UserName,
                settings.Password,
                cancellationToken);
        }

        await client.SendAsync(mail, cancellationToken);
        await client.DisconnectAsync(true, cancellationToken);

        // The sender's address is logged nowhere: the message itself is the
        // record, and the log should not become a copy of the mailbox.
        _logger.LogInformation("Contact message delivered.");
    }

    /// <summary>
    /// Builds the outgoing mail. Reply-To carries the sender's address so a
    /// reply reaches them, while From stays the authenticated account, which
    /// is what providers and SPF expect.
    /// </summary>
    internal static MimeMessage BuildMessage(
        ContactMessage message,
        EmailOptions settings)
    {
        var mail = new MimeMessage();
        mail.From.Add(new MailboxAddress(settings.FromName, settings.FromAddress));
        mail.To.Add(new MailboxAddress(settings.ToName, settings.ToAddress));
        mail.ReplyTo.Add(new MailboxAddress(message.Name, message.Email));
        mail.Subject = BuildSubject(message.Subject);

        var body = new StringBuilder()
            .AppendLine("New message from the NICU GIR Calculator contact form.")
            .AppendLine()
            .Append("Name:    ").AppendLine(message.Name)
            .Append("Email:   ").AppendLine(message.Email)
            .Append("Subject: ").AppendLine(message.Subject)
            .AppendLine()
            .AppendLine("Message:")
            .AppendLine(message.Message)
            .ToString();

        mail.Body = new TextPart("plain") { Text = body };
        return mail;
    }

    /// <summary>
    /// Prefixes the subject and strips anything that could inject a second
    /// header line.
    /// </summary>
    internal static string BuildSubject(string subject)
    {
        string cleaned = subject
            .Replace('\r', ' ')
            .Replace('\n', ' ')
            .Trim();
        if (cleaned.Length > 150) cleaned = cleaned[..150];
        return cleaned.Length == 0
            ? "[GIR Calculator] Contact form"
            : $"[GIR Calculator] {cleaned}";
    }
}
