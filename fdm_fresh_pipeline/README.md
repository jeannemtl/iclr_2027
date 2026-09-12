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

**Open discrepancy, not yet resolved:** GPT-2's Extra accuracy moved
from 89.2% (archived) to 99.4% (fresh) -- a larger shift than the
other three architectures, which landed close to their archived
values (LFM2.5 93.0% matched exactly; Hermes3 99.8% vs. 100.0%;
Qwen3 100.0% vs. 100.0%). This has not been explained. It may
indicate the archived GPT-2 model/data pairing had the same kind of
mismatch problem discovered for Qwen3, or it may reflect a genuine
difference in this fresh run. Treat GPT-2's fresh Extra number as
correct but not yet understood.

The per-channel frequency breakdown also changed qualitatively for
GPT-2: the archived data showed a smooth gradient concentrated at
ch39 (40 Hz); the fresh data shows two isolated dips (ch21 at 98.8%,
ch39 at 94.7%) with everything else at or above 99.5%, not a
monotonic decline across the high band. The "gradient" framing in
the original paper text describing GPT-2 no longer matches the fresh
per-channel data and needs rewording if the fresh table is used.

`patch_hermes3_optimizer.sh` documents a required fix for Hermes3-3B:
full-parameter AdamW's fp32 optimizer state (~24GB) does not fit
alongside model weights and gradients on a 32GB GPU; switching to
bitsandbytes AdamW8bit (~6GB optimizer state) resolved the OOM.
`MAX_LENGTH` was also reduced from 1024 to 768 for Hermes3 to avoid
wasted compute on padding.

Models and generated data are on HuggingFace:

- Datasets: [`prompterminal/fdm-40ch-fresh-gpt2`](https://huggingface.co/datasets/prompterminal/fdm-40ch-fresh-gpt2), [`fdm-40ch-fresh-qwen3`](https://huggingface.co/datasets/prompterminal/fdm-40ch-fresh-qwen3), [`fdm-40ch-fresh-lfm2`](https://huggingface.co/datasets/prompterminal/fdm-40ch-fresh-lfm2), [`fdm-40ch-fresh-hermes3`](https://huggingface.co/datasets/prompterminal/fdm-40ch-fresh-hermes3)
- Models: [`prompterminal/fdm-40ch-fresh-gpt2-model`](https://huggingface.co/prompterminal/fdm-40ch-fresh-gpt2-model), [`fdm-40ch-fresh-qwen3-model`](https://huggingface.co/prompterminal/fdm-40ch-fresh-qwen3-model), [`fdm-40ch-fresh-lfm2-model`](https://huggingface.co/prompterminal/fdm-40ch-fresh-lfm2-model), [`fdm-40ch-fresh-hermes3-model`](https://huggingface.co/prompterminal/fdm-40ch-fresh-hermes3-model)

(All repos are currently private.)
