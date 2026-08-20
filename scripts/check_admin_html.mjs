import fs from 'node:fs';
import vm from 'node:vm';

const files = ['../web/admin.html', '../web/index.html'];
let parsed = 0;

for (const file of files) {
  const url = new URL(file, import.meta.url);
  const html = fs.readFileSync(url, 'utf8');
  const scripts = [...html.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/gi)]
    .map((match) => match[1])
    .filter((source) => source.trim().length > 0);

  if (scripts.length === 0) {
    throw new Error(`${file}에 검사할 내부 스크립트가 없습니다.`);
  }

  for (const [index, source] of scripts.entries()) {
    new vm.Script(source, { filename: `${file}#script-${index + 1}` });
    parsed++;
  }
}

console.log(`web internal scripts parsed: ${parsed}`);
