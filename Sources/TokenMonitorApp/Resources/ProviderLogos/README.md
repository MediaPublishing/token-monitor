# Provider marks

These assets identify connected third-party services, not Token Monitor itself.
All marks remain property of their respective owners. No endorsement is implied.
The app loads them locally, without sending requests to logo services.

- `openai.pdf`: OpenAI's Blossom symbol, converted from SVG to vector PDF without changing its geometry.
  [Brand guidelines](https://openai.com/brand/).
  [Source record](https://commons.wikimedia.org/wiki/File:OpenAI_logo_2025_(symbol).svg).
  [Source SVG](https://upload.wikimedia.org/wikipedia/commons/6/66/OpenAI_logo_2025_%28symbol%29.svg).
  Black/white template presentation follows the system appearance.
- `claude.pdf`: Claude Spark, Clay, from the original SVG in the
  [Anthropic press kit](https://www.anthropic.com/press-kit), downloaded 2026-10-12.
  Converted to vector PDF; original color and geometry retained.
- `opencode.pdf` and `opencode-dark.pdf`: light/dark OpenCode symbols from the
  [official brand assets](https://opencode.ai/brand), mirrored in
  [anomalyco/opencode](https://github.com/anomalyco/opencode/tree/dev/packages/console/app/src/asset/brand).
  Converted to vector PDF, no path changes. The deliberately blocky brand geometry is retained.
  Its redundant opaque-white full-bounds mask is omitted to prevent SVG-to-PDF raster fallback;
  clipping, logo paths, colors and viewBox are unchanged.

Original source downloads are not bundled. PDFs contain vector paths, not raster images.
They use an 18-point longest edge and render through native NSImageView at the display's backing scale.
Conversion: `rsvg-convert --format pdf --width 24 --keep-aspect-ratio` at the default 96 dpi;
OpenCode uses `--height 24` instead. No AI redrawing, runtime downloads or new app dependency.
