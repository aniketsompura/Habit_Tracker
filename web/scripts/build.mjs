// Bundles the app into one artifact page: React and Motion load from the CDN, everything else is inline.
import { build } from "rolldown";
import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const pkg = (name) => JSON.parse(readFileSync(join(root, "node_modules", name, "package.json"), "utf8")).version;

const CDN = [
  `https://cdnjs.cloudflare.com/ajax/libs/react/${pkg("react")}/umd/react.production.min.js`,
  `https://cdnjs.cloudflare.com/ajax/libs/react-dom/${pkg("react-dom")}/umd/react-dom.production.min.js`,
  `https://cdn.jsdelivr.net/npm/framer-motion@${pkg("framer-motion")}/dist/framer-motion.js`,
];

const result = await build({
  input: join(root, "src/main.jsx"),
  onLog(level, log, handler) { if (log.code !== "MODULE_LEVEL_DIRECTIVE") handler(level, log); },
  external: ["react", "react-dom", "react-dom/client", "framer-motion"],
  transform: { jsx: { runtime: "classic" }, define: { "process.env.NODE_ENV": '"production"' } },
  output: {
    format: "iife",
    minify: true,
    globals: { react: "React", "react-dom": "ReactDOM", "react-dom/client": "ReactDOM", "framer-motion": "Motion" },
  },
  write: false,
});

const js = result.output.find((o) => o.type === "chunk").code.replace(/<\/script/gi, "<\\/script");
const css = readFileSync(join(root, "src/styles.css"), "utf8");

const html = `<title>Hexis</title>
<style>
${css}
</style>
<div id="root"></div>
${CDN.map((src) => `<script src="${src}" crossorigin="anonymous"></script>`).join("\n")}
<script>
${js}
</script>
`;

mkdirSync(join(root, "dist"), { recursive: true });
writeFileSync(join(root, "dist/hexis.html"), html);
console.log(`dist/hexis.html ${(html.length / 1024).toFixed(1)} KB (script ${(js.length / 1024).toFixed(1)} KB)`);
