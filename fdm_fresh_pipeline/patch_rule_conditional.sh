#!/bin/bash
# Adds score_rule_conditional to fdm_common.py and wires it into
# evaluate_model() so Rule accuracy is reported two ways:
#   - Rule (aggregate): the existing metric, gated by the answer
#     template (RULE name only appears in the reference answer when
#     meta=="NONE", capping aggregate accuracy near ~20-40% by
#     construction, not by decoding quality).
#   - Rule (conditional, META=NONE only): the new metric, restricted
#     to the subset of samples where the check is actually
#     answerable, giving a clean read on true ch6 decoding accuracy.
#
# This does NOT change what counts as a correct answer (still an
# exact `rule in response` substring check) -- it only changes which
# samples are included in the denominator. Samples where meta !=
# "NONE" are excluded entirely, not counted as wrong.
#
# Usage:
#   bash patch_rule_conditional.sh

set -e

TARGET=/workspace/fdm_common.py

if [ ! -f "$TARGET" ]; then
    echo "ERROR: $TARGET not found."
    exit 1
fi

echo "Backing up original to ${TARGET}.bak"
cp "$TARGET" "${TARGET}.bak"

python3 << 'PYEOF'
path = "/workspace/fdm_common.py"
with open(path) as f:
    content = f.read()

# ------------------------------------------------------------------
# 1. Add score_rule_conditional() right after score_rule()
# ------------------------------------------------------------------
anchor = '''def score_rule(rule: str, response: str) -> bool:
    """Unchanged: substring match of the RULE name in the response.
    NOTE (unresolved, flagged separately): several generate_*_answer
    branches echo the rule name directly into the expected answer
    text, so this check does not by itself distinguish genuine
    decoding from template-pattern echoing. Left as-is here since
    fixing it requires a design decision (e.g. paraphrasing rule
    references out of the answer text) rather than a scoring bugfix."""
    return rule in response'''

if anchor not in content:
    print("ERROR: score_rule() not found verbatim -- no changes made.")
    raise SystemExit(1)

new_addition = anchor + '''


def score_rule_conditional(rule: str, meta: str, response: str):
    """
    Returns (applicable, correct).

    Isolates RULE-channel decoding accuracy from the META
    answer-template gate. The ground-truth answer only emits the
    RULE name when meta=="NONE" -- every non-NONE META branch in
    generate_*_answer returns before reaching the rule-name logic.
    Scoring every sample against `rule in response` (score_rule
    above) therefore caps aggregate accuracy near ~20-40% regardless
    of true decoding quality, since ~80% of samples have no rule
    name in the reference answer to match against at all.

    This restricts scoring to samples where meta == "NONE", where
    the check is actually answerable. `applicable=False` for
    meta != "NONE" samples signals the caller to exclude them from
    the conditional metric's denominator entirely -- they are not
    counted as wrong, they are not counted at all.
    """
    if meta != "NONE":
        return False, False
    return True, (rule in response)'''

content = content.replace(anchor, new_addition)

# ------------------------------------------------------------------
# 2. Add tracking counters in evaluate_model()
# ------------------------------------------------------------------
counter_anchor = "    ch_correct = {}\n    ch_total = {}"
if counter_anchor not in content:
    print("ERROR: counter initialization block not found -- no changes made.")
    raise SystemExit(1)

counter_addition = counter_anchor + "\n    rule_conditional_correct = 0\n    rule_conditional_total = 0"
content = content.replace(counter_anchor, counter_addition, 1)

# ------------------------------------------------------------------
# 3. Add scoring call inside the per-sample loop, right after the
#    existing score_rule() call
# ------------------------------------------------------------------
loop_anchor = '''        if score_rule(rule, response):
            rule_correct += 1'''

if loop_anchor not in content:
    print("ERROR: score_rule() call site not found -- no changes made.")
    raise SystemExit(1)

loop_addition = loop_anchor + '''

        applicable, cond_correct = score_rule_conditional(rule, meta, response)
        if applicable:
            rule_conditional_total += 1
            if cond_correct:
                rule_conditional_correct += 1'''

content = content.replace(loop_anchor, loop_addition, 1)

# ------------------------------------------------------------------
# 4. Add to the summary print block
# ------------------------------------------------------------------
print_anchor = '    print(f"  Rule:    {100*rule_correct/total:.1f}%")'
if print_anchor not in content:
    print("ERROR: Rule print line not found -- no changes made.")
    raise SystemExit(1)

print_addition = print_anchor + '''
    rule_cond_pct = (100 * rule_conditional_correct / rule_conditional_total) if rule_conditional_total else float('nan')
    print(f"  Rule (conditional, META=NONE only, n={rule_conditional_total}): {rule_cond_pct:.1f}%")'''

content = content.replace(print_anchor, print_addition, 1)

# ------------------------------------------------------------------
# 5. Add to the returned dict
# ------------------------------------------------------------------
return_anchor = '''    return {
        "action": 100 * action_correct / total,
        "rule": 100 * rule_correct / total,'''

if return_anchor not in content:
    print("ERROR: return dict not found verbatim -- no changes made.")
    raise SystemExit(1)

return_addition = '''    return {
        "action": 100 * action_correct / total,
        "rule": 100 * rule_correct / total,
        "rule_conditional": rule_cond_pct,
        "rule_conditional_n": rule_conditional_total,'''

content = content.replace(return_anchor, return_addition, 1)

with open(path, "w") as f:
    f.write(content)

print("Patched successfully.")
PYEOF

echo ""
echo "Done. Diff against backup:"
diff "${TARGET}.bak" "$TARGET" || true

echo ""
echo "Re-run eval for each architecture to get the conditional number, e.g.:"
echo "  python3 eidetic_gpt2_fdm_e2e_fresh.py eval 4"
echo "  python3 eidetic_qwen3_fdm_e2e_fresh.py eval 4"
echo "  python3 eidetic_lfm2_fdm_e2e_fresh.py eval 4"
echo "  python3 eidetic_hermes3_fdm_e2e_fresh.py eval 4"
echo ""
echo "No retraining needed -- this only changes evaluation, not the"
echo "trained checkpoints. Existing fresh model_final/ directories"
echo "and stage4_test.jsonl files are unaffected and reusable."
