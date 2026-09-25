#!/usr/bin/env node

const fs = require("fs");
const path = require("path");

const [inputArg, outputArg, densityArg] = process.argv.slice(2);

if (!inputArg) {
  console.error("Usage: node render-svg.cjs <input.svg> [output.png] [density]");
  process.exit(2);
}

let sharp;
try {
  sharp = require("sharp");
} catch (error) {
  console.error(
    "The 'sharp' package is required. Run this script in a Node environment that provides sharp, or install it in an approved project workspace."
  );
  process.exit(2);
}

const input = path.resolve(inputArg);
const output = path.resolve(
  outputArg || path.join(path.dirname(input), `${path.basename(input, path.extname(input))}.png`)
);
const density = Number.parseInt(densityArg || "180", 10);

if (!fs.existsSync(input)) {
  console.error(`Input does not exist: ${input}`);
  process.exit(2);
}

if (path.extname(input).toLowerCase() !== ".svg") {
  console.error(`Input must be an SVG file: ${input}`);
  process.exit(2);
}

if (!Number.isInteger(density) || density < 72 || density > 600) {
  console.error("Density must be an integer between 72 and 600.");
  process.exit(2);
}

sharp(input, { density })
  .png()
  .toFile(output)
  .then((info) => {
    console.log(`${output} (${info.width}x${info.height}, ${info.size} bytes)`);
  })
  .catch((error) => {
    console.error(error.message);
    process.exit(1);
  });
