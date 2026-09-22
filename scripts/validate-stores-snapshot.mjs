import { readFileSync, writeFileSync } from 'node:fs';
import { isValidSnapshotStore } from './data_integrity.mjs';

const [inputPath, outputPath] = process.argv.slice(2);
if (!inputPath || !outputPath) {
  throw new Error('Usage: node scripts/validate-stores-snapshot.mjs <input> <output>');
}

const stores = JSON.parse(readFileSync(inputPath, 'utf8'));
const receivedCount = Array.isArray(stores) ? stores.length : 0;
if (!Array.isArray(stores) || stores.length < 10_000) {
  throw new Error(`Snapshot must contain at least 10,000 stores (received ${receivedCount}).`);
}

let validRows = 0;
for (const store of stores) {
  if (isValidSnapshotStore(store)) validRows++;
}

if (validRows / stores.length < 0.99) {
  throw new Error(`Snapshot validation failed: only ${validRows}/${stores.length} rows are valid.`);
}

writeFileSync(outputPath, JSON.stringify(stores));
console.log(`Validated ${stores.length} stores and wrote ${outputPath}.`);
