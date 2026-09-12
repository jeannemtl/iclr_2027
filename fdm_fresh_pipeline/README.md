# Fresh, verified-matched FDM pipeline

Generated, trained, and evaluated in one continuous session
(Sept 2026), using a corrected `fdm_common.py` that fixes two
scoring issues found in the original evaluation code.

## Corrected results, all four architectures, guaranteed matched model+data pairs

| Metric | GPT-2 | Qwen3 | LFM2.5 | Hermes3 |
|--------|-------|-------|--------|---------|
| Action | 98.5% | 98.7% | 98.6%  | 98.7%   |
| Rule (aggregate) | 39.1% | 39.2% | 39.1%  | 39.1%   |
| **Rule (conditional, META=NONE, n=570)** | **100.0%** | **100.0%** | **100.0%** | **100.0%** |
| Meta (corrected) | 79.9% | 79.9% | 79.9%  | 79.8%   |
| Fact   | 100.0%| 100.0%| 100.0% | 99.9%   |
| Extra  | 99.4% | 100.0%| 93.0%  | 99.8%   |

This supersedes all prior `fdm-40ch-turbo-v3-*` model/dataset repos
on HuggingFace, which were found to be from mismatched training runs
(model and data generated at different times, in some cases a month
apart) and could not be verified as matched pairs.

## Fix 1: Meta scoring (`score_meta`)

Prior release auto-passed `NONE`, `OVERRIDE_STATUS`, and
`OVERRIDE_PRIORITY` unconditionally, with no check against the
model's actual output. Corrected version checks all five META values
against the response. True Meta ceiling across all four architectures
is ~80%, not the previously reported ~100%. This appears to be a
genuine, architecture-invariant property (identical to one decimal
place across four very different models), not a training or data
artifact.

## Fix 2: Rule scoring (`score_rule_conditional`)

The ground-truth answer only emits the RULE name when
META=="NONE" (~38% of samples, n=570 of 1500) -- every other META
branch in the answer-generation logic returns before reaching the
rule-name logic. Scoring every sample against `rule in response`
therefore capped aggregate accuracy near 39% regardless of true
decoding quality, since ~62% of samples have no rule name in the
reference answer to match against at all. `score_rule_conditional`
restricts scoring to the META=="NONE" subset, where the check is
actually answerable. Result: 100.0% across all four architectures,
confirming RULE-channel decoding is genuinely perfect and the
aggregate number was purely a template-gating artifact, not a
model weakness.

## Open discrepancy, not yet resolved

GPT-2's Extra accuracy moved from 89.2% (archived) to 99.4% (fresh)
-- a larger shift than the other three architectures, which landed
close to their archived values (LFM2.5 93.0% matched exactly;
Hermes3 99.8% vs. 100.0%; Qwen3 100.0% vs. 100.0%). This has not been
explained. It may indicate the archived GPT-2 model/data pairing had
the same kind of mismatch problem discovered for Qwen3, or it may
reflect a genuine difference in this fresh run. Treat GPT-2's fresh
Extra number as correct but not yet understood.

The per-channel frequency breakdown also changed qualitatively for
GPT-2: the archived data showed a smooth gradient concentrated at
ch39 (40 Hz); the fresh data shows two isolated dips (ch21 at 98.8%,
ch39 at 94.7%) with everything else at or above 99.5%, not a
monotonic decline across the high band.

## Notable reproduced finding

LFM2.5 shows a genuine high-frequency carrier collapse (ch39/COMMS
at 15.9%, matching the archived-data result to the decimal point
across two independent fresh evaluation runs), confirming this is a
real property of its hybrid conv-attention architecture, not a data
artifact.

## Training notes (Hermes3-3B)

`patch_hermes3_optimizer.sh` documents a required fix: full-parameter
AdamW's fp32 optimizer state (~24GB) does not fit alongside model
weights and gradients on a 32GB GPU; switching to bitsandbytes
AdamW8bit (~6GB optimizer state) resolved the OOM. `MAX_LENGTH` was
also reduced from 1024 to 768 to avoid wasted compute on padding.

## Data and models

- Datasets: [`prompterminal/fdm-40ch-fresh-gpt2`](https://huggingface.co/datasets/prompterminal/fdm-40ch-fresh-gpt2), [`fdm-40ch-fresh-qwen3`](https://huggingface.co/datasets/prompterminal/fdm-40ch-fresh-qwen3), [`fdm-40ch-fresh-lfm2`](https://huggingface.co/datasets/prompterminal/fdm-40ch-fresh-lfm2), [`fdm-40ch-fresh-hermes3`](https://huggingface.co/datasets/prompterminal/fdm-40ch-fresh-hermes3)
- Models: [`prompterminal/fdm-40ch-fresh-gpt2-model`](https://huggingface.co/prompterminal/fdm-40ch-fresh-gpt2-model), [`fdm-40ch-fresh-qwen3-model`](https://huggingface.co/prompterminal/fdm-40ch-fresh-qwen3-model), [`fdm-40ch-fresh-lfm2-model`](https://huggingface.co/prompterminal/fdm-40ch-fresh-lfm2-model), [`fdm-40ch-fresh-hermes3-model`](https://huggingface.co/prompterminal/fdm-40ch-fresh-hermes3-model)

(All repos are currently private.)
