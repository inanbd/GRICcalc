// Applies the saved appearance before first paint, so the page never flashes
// light before switching to dark. Deliberately a plain script, not a module:
// modules are deferred, and the flash is what we are avoiding.
(function () {
  var KEY = 'griccalc.theme';
  var modes = ['system', 'light', 'dark'];

  function read() {
    try {
      var stored = window.localStorage.getItem(KEY);
      return modes.indexOf(stored) === -1 ? 'system' : stored;
    } catch (e) {
      // Private browsing, or storage blocked. The default is still usable.
      return 'system';
    }
  }

  function apply(mode) {
    document.documentElement.setAttribute('data-theme', mode);
  }

  apply(read());

  window.GirTheme = {
    get: read,
    icons: { system: 'A', light: 'L', dark: 'D' },
    labels: { system: 'Match device', light: 'Light', dark: 'Dark' },
    next: function (mode) {
      return modes[(modes.indexOf(mode) + 1) % modes.length];
    },
    set: function (mode) {
      apply(mode);
      try {
        window.localStorage.setItem(KEY, mode);
      } catch (e) {
        // Not fatal: the choice simply will not survive a reload.
      }
    },
  };

  document.addEventListener('DOMContentLoaded', function () {
    var button = document.getElementById('theme-toggle');
    var icon = document.getElementById('theme-icon');
    if (!button || !icon) return;

    function paint() {
      var mode = window.GirTheme.get();
      icon.textContent = window.GirTheme.icons[mode];
      button.title = 'Appearance: ' + window.GirTheme.labels[mode];
      button.setAttribute(
        'aria-label',
        'Appearance: ' + window.GirTheme.labels[mode]
      );
    }

    button.addEventListener('click', function () {
      window.GirTheme.set(window.GirTheme.next(window.GirTheme.get()));
      paint();
    });
    paint();
  });
})();
