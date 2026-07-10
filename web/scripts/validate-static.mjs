import { access, readFile } from "node:fs/promises";

const requiredFiles = [
  "404.html",
  "_headers",
  "add-meal.html",
  "index.html",
  "privacy.html",
  "terms.html",
  ".well-known/apple-app-site-association",
  ".well-known/assetlinks.json",
];

await Promise.all(requiredFiles.map((file) => access(file)));

for (const file of requiredFiles.filter((name) => name.startsWith(".well-known/"))) {
  JSON.parse(await readFile(file, "utf8"));
}

console.log(`Validated ${requiredFiles.length} static deployment files.`);
