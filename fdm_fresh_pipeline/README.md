# Fresh, verified-matched FDM pipeline

Generated, trained, and evaluated in one continuous session
(Sept 2026), using a corrected `fdm_common.py` that fixes a Meta
scoring bug (previously auto-passed 3 of 5 META values with no check
against the model's actual output).

Corrected results, all four architectures, guaranteed matched
model+data pairs:

| Metric | GPT-2 | Qwen3 | LFM2.5 | Hermes3 |
|--------|-------|-------|--------|---------|
| Action | 98.5% | 98.7% | 98.6%  | 98.7%   |
| Rule   | 39.1% | 39.2% | 39.1%  | 39.1%   |
| Meta   | 79.9% | 79.9% | 79.9%  | 79.8%   |
| Fact   | 100.0%| 100.0%| 100.0% | 99.9%   |
| Extra  | 99.4% | 100.0%| 93.0%  | 99.8%   |

This supersedes all prior `fdm-40ch-turbo-v3-*` model/dataset repos
on HuggingFace, which were found to be from mismatched training runs
(model and data generated at different times, in some cases a month
apart) and could not be verified as matched pairs.

Notable reproduced finding: LFM2.5 shows a genuine high-frequency
carrier collapse (ch39/COMMS at 15.9%, matching the archived-data
result to the decimal point), confirming this is a real property of
its hybrid conv-attention architecture, not a data artifact.

`patch_hermes3_optimizer.sh` documents a required fix for Hermes3-3B:
full-parameter AdamW's fp32 optimizer state (~24GB) does not fit
alongside model weights and gradients on a 32GB GPU; switching to
bitsandbytes AdamW8bit (~6GB optimizer state) resolved the OOM.
`MAX_LENGTH` was also reduced from 1024 to 768 for Hermes3 to avoid
wasted compute on padding.

Models and generated data are on HuggingFace under
`prompterminal/fdm-40ch-fresh-{arch}` (dataset) and
`prompterminal/fdm-40ch-fresh-{arch}-model` (model) for
arch in {gpt2, qwen3, lfm2, hermes3}.
