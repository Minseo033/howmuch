import { readFileSync, writeFileSync } from 'node:fs';

const [inputPath, outputPath] = process.argv.slice(2);
if (!inputPath || !outputPath) {
  throw new Error('Usage: node scripts/validate-stores-snapshot.mjs <input> <output>');
}

const stores = JSON.parse(readFileSync(inputPath, 'utf8'));
const receivedCount = Array.isArray(stores) ? stores.length : 0;
if (!Array.isArray(stores) || stores.length < 10_000) {
  throw new Error(`Snapshot must contain at least 10,000 stores (received ${receivedCount}).`);
}

const requiredFields = ['storeName', 'address', 'latitude', 'longitude'];
let validRows = 0;
for (const store of stores) {
  if (!store || typeof store !== 'object' || Array.isArray(store)) continue;
  const hasRequiredFields = requiredFields.every((field) => field in store);
  const hasLocation = Number.isFinite(Number(store.latitude))
    && Number.isFinite(Number(store.longitude));
  if (hasRequiredFields && hasLocation) validRows++;
}

if (validRows / stores.length < 0.99) {
  throw new Error(`Snapshot validation failed: only ${validRows}/${stores.length} rows are valid.`);
}

writeFileSync(outputPath, JSON.stringify(stores));
console.log(`Validated ${stores.length} stores and wrote ${outputPath}.`);
