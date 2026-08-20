export const meta = {
  name: 'fix-ai-scan',
  description: 'Haiku finds FIX-AI: comments, Sonnet fixes each, main model reviews',
  phases: [
    { title: 'Scan', detail: 'haiku greps repo for FIX-AI: comments' },
    { title: 'Fix', detail: 'sonnet fixes each found comment, one file edit each' },
  ],
}

const FOUND_SCHEMA = {
  type: 'object',
  properties: {
    items: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          file: { type: 'string' },
          line: { type: 'number' },
          comment: { type: 'string' },
          context: { type: 'string' },
        },
        required: ['file', 'line', 'comment'],
      },
    },
  },
  required: ['items'],
}

const FIX_SCHEMA = {
  type: 'object',
  properties: {
    status: { type: 'string', enum: ['fixed', 'needs_clarification', 'skipped'] },
    summary: { type: 'string', description: 'What was changed, or why skipped' },
    question: { type: 'string', description: 'Set only when status=needs_clarification: the exact question to ask the user' },
  },
  required: ['status', 'summary'],
}

phase('Scan')
const planRef = typeof args === 'string' ? args.trim() : ''
const root = '.'
const found = await agent(
  `Search the codebase rooted at "${root}" for comments containing "FIX-AI:" (grep recursively, skip node_modules/.git/dist/build). For each match, return file path, line number, the full comment text, and a few surrounding lines of code as context.`,
  { model: 'claude-haiku-4-5-20251001', schema: FOUND_SCHEMA }
)
const items = found.items || []
if (!items.length) return { items: [] }

const planContext = planRef
  ? `This is part of a larger feature; the plan/ticket it belongs to is ${planRef} — read it for context on what the feature is trying to do before fixing.\n\n`
  : ''

const fixes = await pipeline(
  items,
  item => agent(
    `${planContext}A FIX-AI comment was found at ${item.file}:${item.line}:\n"${item.comment}"\n\nSurrounding context:\n${item.context}\n\nDo what the comment asks: fix the code in that file. If the intent is genuinely ambiguous (unclear what change is wanted, multiple valid interpretations, missing info you cannot infer from the codebase), do NOT guess — set status=needs_clarification and write the exact question to ask. Otherwise make the fix directly, remove the FIX-AI comment once resolved, and set status=fixed with a one-line summary of the change. If the comment turns out to be stale/already resolved, set status=skipped and say why.`,
    { label: `fix:${item.file}:${item.line}`, phase: 'Fix', schema: FIX_SCHEMA }
  ).then(r => ({ ...item, ...r }))
)

return fixes
