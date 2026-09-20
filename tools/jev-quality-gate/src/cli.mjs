#!/usr/bin/env node

import { readFile } from 'node:fs/promises';
import process from 'node:process';
import { experimental_evaluate as evaluate } from 'ai';
import {
  MODEL_ID,
  formatEvaluation,
  prepareState,
  questions,
} from './quality-gate.mjs';

function parseArgs(argv) {
  const args = { pretty: false };
  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    if (arg === '--pretty') {
      args.pretty = true;
      continue;
    }
    if (arg === '--input') {
      args.input = argv[++index];
      continue;
    }
    if (arg === '--help' || arg === '-h') {
      args.help = true;
      continue;
    }
    throw new Error(`알 수 없는 옵션: ${arg}`);
  }
  return args;
}

async function readStdin() {
  const chunks = [];
  for await (const chunk of process.stdin) chunks.push(chunk);
  return Buffer.concat(chunks).toString('utf8');
}

function printHelp() {
  console.log(`HowMuch Jev quality gate

사용법:
  npm run evaluate -- --input examples/quality-signals.sample.json --pretty
  cat quality-signals.json | npm run evaluate -- --pretty

필수 환경변수:
  AI_GATEWAY_API_KEY  Vercel AI Gateway API 키`);
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  if (args.help) {
    printHelp();
    return;
  }
  if (!process.env.AI_GATEWAY_API_KEY) {
    throw new Error(
      'AI_GATEWAY_API_KEY가 없습니다. Vercel AI Gateway 키를 로컬 환경변수로만 설정하세요.',
    );
  }

  const rawInput = args.input
    ? await readFile(args.input, 'utf8')
    : await readStdin();
  if (!rawInput.trim()) {
    throw new Error('JSON 평가 입력이 필요합니다.');
  }

  const state = prepareState(JSON.parse(rawInput));
  const result = await evaluate({ model: MODEL_ID, state, questions });
  const output = formatEvaluation(result);
  console.log(JSON.stringify(output, null, args.pretty ? 2 : 0));
}

main().catch((error) => {
  console.error(`Jev 평가 실패: ${error.message}`);
  process.exitCode = 1;
});
