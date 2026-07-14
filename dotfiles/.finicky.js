// Finicky config — routes URLs to the right browser.
// Docs: https://github.com/johnste/finicky/wiki/Configuration-(v4)

export default {
  defaultBrowser: "Safari",

  handlers: [
    {
      match: "linear.app/*",
      browser: "Linear",
    },
    {
      match: (_, { opener }) =>
        !opener?.bundleId || // CLI tools (gcloud, etc.)
        [
          "com.tinyspeck.slackmacgap", // Slack
          "com.superhuman.electron", // Superhuman
          "com.TickTick.task.mac", // TickTick
          "com.linear", // Linear
          "com.figma.Desktop", // Figma
          "com.anthropic.claudefordesktop", // Claude
          "notion.id", // Notion
          "com.openai.codex", // ChatGPT
          "com.cron.electron", // Notion Calendar
          "dev.zed.Zed", // Zed
          "com.microsoft.VSCode", // Visual Studio Code
          "com.github.wez.wezterm", // WezTerm
        ].includes(opener?.bundleId),
      browser: "Helium",
    },
  ],
};
