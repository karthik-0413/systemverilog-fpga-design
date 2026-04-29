import numpy as np
import matplotlib
matplotlib.use("Agg")           # non-interactive backend (no display needed)
import matplotlib.pyplot as plt
from scipy.signal import firwin

# ── Parameters ────────────────────────────────────────────────────────────────
NUM_TAPS    = 15         # number of FIR taps (odd → linear phase, symmetric)
NUM_SAMPLES = 32         # number of input samples
Q15_SCALE   = 2**15      # 32768  (Q15: ap_fixed<16,1>)

# Accumulator width analysis:
#   Q15 × Q15  → Q30 product  (up to 32767² ≈ 2^30)
#   sum of 15  → needs ceil(log2(15)) = 4 extra integer bits → Q30 + 4 guard bits
#   In HLS: ap_fixed<35, 5> is sufficient; golden model uses int64 (no overflow).
#   After >>15 the result fits in int16 (Q15); we sign-extend to int32.

SEED = 42
np.random.seed(SEED)

# ── Coefficients: scipy low-pass FIR (Hamming window, cutoff = 0.3 × Nyquist) ─
coeff_float = firwin(NUM_TAPS, cutoff=0.04)          # float64, sum ≈ 1, no DC overflow
coeff_q15   = np.clip(
    np.round(coeff_float * Q15_SCALE),
    -Q15_SCALE, Q15_SCALE - 1
).astype(np.int16)
coeff_i64   = coeff_q15.astype(np.int64)             # wide type for MAC

# ── Input samples in Q15 ─────────────────────────────────────────────────────
# Sine at 0.1 × Nyquist (10 samples/cycle → 3 visible cycles in 32 samples, above LP cutoff of 0.04)
FREQ_NORM   = 0.10                                   # normalised frequency (0=DC, 1=Nyquist)
n            = np.arange(NUM_SAMPLES)
input_float  = np.sin(2 * np.pi * FREQ_NORM * n)    # amplitude 1.0, no clipping needed
input_q15    = np.clip(
    np.round(input_float * Q15_SCALE),
    -Q15_SCALE, Q15_SCALE - 1
).astype(np.int16)

# ── Golden FIR model ──────────────────────────────────────────────────────────
# Causal, sample-by-sample; shift register initialised to 0.
# Integer MAC in Q30 (int64), then >>15 to scale back to Q15, sign-extend to int32.
shift_reg  = np.zeros(NUM_TAPS, dtype=np.int64)
output_i32 = []

for i in range(NUM_SAMPLES):
    # shift new sample in at index 0
    shift_reg = np.roll(shift_reg, 1)
    shift_reg[0] = np.int64(input_q15[i])

    # MAC: accumulate Q15×Q15 products → Q30 in int64
    acc_q30 = np.dot(coeff_i64, shift_reg)           # int64, no overflow for ≤7 taps

    # Scale back to Q15: arithmetic right-shift by 15
    acc_q15 = int(acc_q30) >> 15

    # Clamp to Q15 range (should not clip for a unity-gain LP filter)
    acc_q15 = max(-Q15_SCALE, min(Q15_SCALE - 1, acc_q15))

    # Sign-extend int16 → int32 (Python int is arbitrary precision; cast explicitly)
    acc_i32 = np.int32(acc_q15)
    output_i32.append(int(acc_i32))

# ── Print summary ─────────────────────────────────────────────────────────────
print(f"Low-pass FIR coefficients (scipy firwin, Q15, {NUM_TAPS} taps, cutoff=0.3):")
for k, (ci, cf) in enumerate(zip(coeff_q15, coeff_float)):
    print(f"  h[{k}] = {ci:6d}  ({cf:+.6f})")

print(f"\nInput samples (Q15, {NUM_SAMPLES} samples):")
for k, (xi) in enumerate(input_q15):
    print(f"  x[{k:2d}] = {xi:6d}  ({xi / Q15_SCALE:+.6f})")

print(f"\nOutput samples (Q15 in int32, {NUM_SAMPLES} samples):")
for k, y in enumerate(output_i32):
    print(f"  y[{k:2d}] = {y:8d}  ({y / Q15_SCALE:+.8f})")

# ── Save files for HLS testbench ──────────────────────────────────────────────
with open("coeffs.txt", "w") as f:
    for c in coeff_q15:
        f.write(f"{c}\n")

with open("input.txt", "w") as f:
    for x in input_q15:
        f.write(f"{x}\n")

with open("golden.txt", "w") as f:
    for y in output_i32:
        f.write(f"{y}\n")

print("\nWrote: coeffs.txt  input.txt  golden.txt")

# ── Plot input vs filtered output ──────────────────────────────────────────────
samples = np.arange(NUM_SAMPLES)
input_norm  = input_q15  / Q15_SCALE
output_norm = np.array(output_i32) / Q15_SCALE

fig, axes = plt.subplots(2, 1, figsize=(10, 6), sharex=True)

axes[0].stem(samples, input_norm, linefmt="C0-", markerfmt="C0o", basefmt="k-")
axes[0].set_ylabel("Amplitude")
axes[0].set_title(f"Input: {FREQ_NORM}\u00d7Nyquist sine (Q15, full scale) — {1/FREQ_NORM:.0f} samples/cycle")
axes[0].set_ylim(-1.2, 1.2)
axes[0].grid(True)

axes[1].stem(samples, output_norm, linefmt="C1-", markerfmt="C1o", basefmt="k-")
axes[1].set_ylabel("Amplitude")
axes[1].set_title(f"Output: after {NUM_TAPS}-tap LP filter (cutoff=0.04\u00d7Nyquist, Q15)")
axes[1].set_xlabel("Sample index")
axes[1].set_ylim(-1.2, 1.2)
axes[1].grid(True)

plt.tight_layout()
plt.savefig("fir_response.png", dpi=120)
print("Wrote: fir_response.png")
