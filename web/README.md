# NICU GIR Calculator — website

The same calculator as the Android app, as an ASP.NET Core Razor Pages site,
plus a contact form that emails the site owner.

```bash
cd web
dotnet run --project GirCalculator.Web      # http://localhost:5000
dotnet test                                 # C# tests
node --test tests/gir.test.mjs              # calculation tests
```

> Razor Pages is ASP.NET **Core** (this targets `net8.0`), not the legacy
> Windows-only .NET Framework — Core is what runs Razor Pages today and it runs
> on Linux, macOS and Windows.

## Pages

| Page | What it is |
| --- | --- |
| `/` | The calculator: patients, IV lines, feeds, totals, copy and print |
| `/HowItWorks` | Every formula, with worked examples for both IV and feeds |
| `/Disclaimer` | What the tool is, what it is not, and where the data lives |
| `/Contact` | Sends a message to the configured mailbox |

## Nothing leaves the browser

The calculator is client-side JavaScript. It posts nothing: no weight, no
patient name, no rate ever reaches the server. The contact form is the single
exception, and it carries only what is typed into it.

Records are kept in `localStorage` rather than cookies. Cookies would have been
the smaller change, but a cookie is attached to **every** request, so patient
data would travel to the server on each page load — the opposite of the
requirement. `localStorage` stays on the device and is never transmitted.

A strict `Content-Security-Policy` backs this up: same-origin scripts and
styles only, `connect-src 'self'`, `form-action 'self'`. There is nowhere for
the page to send anything even if something tried. It also means no inline
`style` or `<script>` blocks — anything dynamic is set through the CSSOM in
`wwwroot/js/app.js`.

## Configuration

`appsettings.json` holds two sections.

### Site

```json
"Site": {
  "PlayStoreUrl": "",
  "GitHubUrl": "https://github.com/inanbd/GRICcalc"
}
```

Paste the Play Store listing URL into `PlayStoreUrl` when the app is published.
The **Get it on Google Play** button appears only once it is set, so the site
never shows a link that goes nowhere. Only `http`/`https` values are accepted,
so a stray value cannot become a `javascript:` link.

### Email

```json
"Email": {
  "Host": "smtp.example.com",
  "Port": 587,
  "UseStartTls": true,
  "UserName": "you@example.com",
  "Password": "",
  "FromAddress": "you@example.com",
  "FromName": "NICU GIR Calculator",
  "ToAddress": "where-messages-go@example.com",
  "ToName": "Site owner",
  "TimeoutSeconds": 20
}
```

`ToAddress` is where contact messages land — set it to your own address. It is
left blank in the committed file rather than carrying a real address into a
public repository. While `Host`, `FromAddress` or `ToAddress` are blank the
contact page says the form is unavailable instead of accepting a message it
would silently drop.

**Keep the password out of the file.** Supply it out of band:

```bash
dotnet user-secrets set "Email:Password" "..."   # development
export Email__Password="..."                     # production
```

Port 587 with `UseStartTls: true` is the usual submission setup; port 465 wants
`UseStartTls: false` (implicit TLS). Gmail needs an app password rather than
the account password.

`From` stays the authenticated account so SPF still passes, and the sender's
address goes in `Reply-To`, so replying reaches them.

## Contact form protections

Antiforgery token, server-side validation, a hidden honeypot field, a fixed
window rate limit of five submissions per ten minutes, and subject sanitising
so a newline cannot smuggle in a second mail header. A delivery failure says so
rather than showing a success page for a message that never left; the reason
goes to the log, not to the visitor.

## Tests

- `tests/gir.test.mjs` — 21 tests over the browser calculation engine, ported
  from the Flutter suite: the GIR checked against two independently derived
  formulations across a grid of weights, concentrations and rates; the worked
  figures published by infantfeeds.com; totals that never drift from the sum of
  their parts; and no input producing a negative or non-finite result.
- `GirCalculator.Tests` — 42 tests covering message construction (From,
  Reply-To, header-injection, subject capping), the Play Store URL guard, every
  page rendering, the CSP headers, and the contact form end to end: valid send,
  validation failures, honeypot, missing antiforgery token, delivery failure,
  and the unconfigured case.

The calculation engine is a direct port of `lib/logic/gir_calculator.dart`, and
both suites assert the same reference figures, so the app and the site agree.
