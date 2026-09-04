namespace GirCalculator.Web.Services;

/// <summary>
/// Links and labels that differ between deployments, bound from the "Site"
/// section of appsettings.json.
/// </summary>
public sealed class SiteOptions
{
    public const string SectionName = "Site";

    /// <summary>
    /// Play Store listing for the Android app. Leave blank until the app is
    /// published: the download button only appears once this is set, so the
    /// site never shows a link that goes nowhere.
    /// </summary>
    public string PlayStoreUrl { get; set; } = string.Empty;

    /// <summary>Where the APKs and source live. Blank hides the link.</summary>
    public string GitHubUrl { get; set; } = string.Empty;

    public bool HasPlayStoreUrl => IsHttpUrl(PlayStoreUrl);

    public bool HasGitHubUrl => IsHttpUrl(GitHubUrl);

    /// <summary>
    /// Only http(s) is accepted, so a stray value in configuration cannot turn
    /// into a javascript: link in the rendered page.
    /// </summary>
    private static bool IsHttpUrl(string value) =>
        Uri.TryCreate(value, UriKind.Absolute, out Uri? uri)
        && (uri.Scheme == Uri.UriSchemeHttps || uri.Scheme == Uri.UriSchemeHttp);
}
