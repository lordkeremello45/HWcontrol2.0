import { defineConfig } from "astro/config";

export default defineConfig({
  site: "https://lordkeremello45.github.io",
  base: "/HWcontrol2.0",
  trailingSlash: "always",
  output: "static",
  compressHTML: true,
  build: {
    inlineStylesheets: "auto"
  }
});
