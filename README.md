[README.md](https://github.com/user-attachments/files/30624742/README.md)
# TaxÍs

Mobile-first pocket accountant for Icelandic hybrid workers - people with a
payslip job plus contractor/gig income, multiple part-time employers, or both.
Never positioned publicly as "for expats," even though expats and gig
contractors (Wolt/Aha couriers, etc.) are the real target segment - see
docs/taxis-architecture-map.md's core design principle.

This repo is the code scaffold generated from a long architecture/design
process. **The docs are the source of truth for intent and verification; this
code implements them.** If code and docs disagree, read the doc first - it
usually has the primary-source citation the code comment only summarizes.

## What's actually implemented vs. stubbed

**Real, tested TypeScript** (`src/lib/tax/`):
- `combinedEngine.ts` - the core differentiator: progressive tax on TOTAL
  income across employment + contractor streams, not per-stream.
- `mileage.ts` - okutaekjastyrkur (vehicle allowance) calculator, verified
  against the actual government regulation's own worked example.
- `reiknadEndurgjald.ts` - self-employed minimum-wage validation against
  RSK's real flokkar A-H reference table, including the multi-job reduction
  rule.
- `settlementProjector.ts` - the "will I owe money or get money back this
  year" projection engine, with the one-time-vs-recurring income distinction
  that prevents a single large payment from wrecking the projection.

Every one of these is tested against **real numbers**, not synthetic
fixtures - the test fixtures are this project's own verified June 2026
calculation, run against two actual Icelandic payslips and a real contractor
payment. Run `npm test` to see them pass.

**Stubbed, spec exists, implementation doesn't** (`src/lib/ocr/`,
`src/lib/auth/`): payslip OCR extraction and passwordless auth. Both throw
`Error('Not implemented...')` pointing at the exact doc section to implement
against - these need real provider credentials (OCR provider, LLM API, auth
provider) that aren't part of this scaffold.

**Not started at all**: the actual UI (the mockups shown during design are
HTML/SVG prototypes, not this codebase), the notification engine, and payment
processing. See `docs/` for the full designs of each.

## Setup

```bash
npm install
cp .env.example .env   # fill in real provider credentials
npm run prisma:generate
npm run typecheck
npm test
```

## Structure

```
prisma/schema.prisma       consolidated DB schema from every design doc
src/lib/tax/                the real, tested calculation engines
src/lib/ocr/                 payslip/receipt extraction (stub)
src/lib/auth/                 passwordless auth (stub)
src/types/                     shared domain types
docs/                            the full design docs these implement
```

## Before this goes anywhere near real users

Two items block public launch regardless of code readiness - both are
product/legal decisions, not engineering ones:

1. **Icelandic legal review of the regulated-advice question** -
   `docs/taxis-architecture-map.md` section 3.3. Whether Module C's
   form/reitur guidance counts as regulated tax advice needs a real answer
   before that feature ships as designed.
2. **A payment processor that actually settles in ISK** -
   `docs/taxis-commercial-architecture.md` section 4. Stripe doesn't have a
   native Icelandic entity; an earlier version of that doc assumed Stripe
   without checking.

See `docs/taxis-terms-of-service-disclaimer.md` for the full open-items list
before shipping.
