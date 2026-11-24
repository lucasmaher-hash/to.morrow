# Project skills

Skills committed here travel with the repo, so anyone working on shove.95
gets them automatically.

## aso-appstore-screenshots

From https://github.com/adamlyttleapps/claude-skill-aso-appstore-screenshots
(MIT). Generates marketing App Store screenshots — the kind with a headline
above a device frame — rather than the plain device captures in `store/`.

Needs three things, two of which are already present on this machine:

| Requirement | Status |
|---|---|
| Pillow | ✅ 11.3.0 |
| SF Pro Display Black at `/Library/Fonts/` | ✅ installed |
| Gemini MCP server (`generate_image` tool) | ❌ not configured |

Without the third, the analysis and layout phases run but the final image
generation does not. Set up with `npm install -g @houtini/gemini-mcp` and add
it to the MCP config.
