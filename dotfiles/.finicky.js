// Finicky config — routes URLs to the right browser.
// Docs: https://github.com/johnste/finicky/wiki/Configuration-(v4)

export default {
  // Safari for everything; Helium only on demand (Shift, below).
  defaultBrowser: "Safari",

  options: {
    // The Shift rule reads the keys held when the URL arrives, and after a
    // cold launch the key is already released. true is the default — stated
    // because that rule depends on it.
    keepRunning: true,
  },

  handlers: [
    {
      // Shift+click a link in another app → Helium. Not ⌘ (Zed and VS Code
      // open links on ⌘-click), ⌥ (⌥-click marks a Slack message unread) or
      // ⌃ (⌃-click is a right-click, and Hyper and Meh both hold ⌃).
      // First, so it also beats the Linear rule. Links clicked inside Safari
      // never reach Finicky.
      match: () => finicky.getModifierKeys().shift,
      browser: "Helium",
    },
    {
      match: "linear.app/*",
      browser: "Linear",
    },
  ],
};
