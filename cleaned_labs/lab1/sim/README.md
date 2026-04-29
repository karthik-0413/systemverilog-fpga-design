# Simulation Testbenches for 16-bit Adder

This directory contains testbenches to verify the 16-bit adder design.

## Three Implementation Variations

The adder design ([adder_16bit.sv](../rtl/adder_16bit.sv)) supports three different implementations. All produce identical results!

### 1. BEHAVIORAL (Default)
Uses the `+` operator. Simple and readable.
```systemverilog
assign result = {1'b0, a} + {1'b0, b};
```

### 2. RIPPLE_CARRY_MANUAL
Manually instantiates 16 full adders one-by-one. Shows explicit connections.
```systemverilog
full_adder fa0 (.a(a[0]), .b(b[0]), .cin(c[0]), .sum(sum[0]), .cout(c[1]));
full_adder fa1 (.a(a[1]), .b(b[1]), .cin(c[1]), .sum(sum[1]), .cout(c[2]));
...
```

### 3. RIPPLE_CARRY_GENERATE
Uses `generate` statement with a for loop. Scalable and easy to modify.
```systemverilog
generate
    for (i = 0; i < 16; i = i + 1) begin
        full_adder fa (...);
    end
endgenerate
```

---

## Testbenches

### 1. Exhaustive Testing (`tb_adder_exhaustive.sv`)
- Tests MAXVAL x MAXVAL combinations (default: 256x256 = 65K tests)
- **Note**: This runs only a SUBSET of all possible combinations for speed
- Full exhaustive would be 2^32 = 4.3 billion tests
- Change MAXVAL in the file to test more combinations
- Run with MAXVAL = 65536 by editing the file and check the time to run (Ctrl+C to stop)
- Simple driver/monitor/scoreboard
- Used by: `run_behavioral.sh`, `run_manual.sh`, `run_generate.sh`

### 2. Constrained Random Testing (`tb_adder_constrained_random.sv`)
- Tests corner cases (0, max, MSB/LSB patterns)
- 10,000 random tests with smart distribution (30% corner cases, 70% random)
- Simple classes for transactions
- Automatic result checking
- Better coverage than exhaustive due to smarter test selection
- Used by: `run_coverage.sh` (default)

---

## Quick Start

### Step 1: Test each implementation (uses exhaustive testbench)
```bash
cd sim
./run_behavioral.sh    # Test behavioral implementation
./run_manual.sh        # Test manual instantiation
./run_generate.sh      # Test generate statement
./run_waveform.sh      # Shows how to save & view simulation waveforms
```

All three run `tb_adder_exhaustive.sv` which tests 256x256 = 65K input combinations.

### Step 2: Understand Coverage - Why Exhaustive Isn't Feasible

Modify `run_coverage.sh` to use the exhaustive testbench:

**Edit line 17 in run_coverage.sh**:
```bash
# Change from:
xvlog -sv tb_adder_constrained_random.sv || exit 1

# To:
xvlog -sv tb_adder_exhaustive.sv || exit 1
```

**And edit line 25**:
```bash
# Change from:
xelab -debug typical tb_adder_constrained_random -s sim \

# To:
xelab -debug typical tb_adder_exhaustive -s sim \
```

Then run and generate coverage report:
```bash
./run_coverage.sh
```

**Observation**: You'll see **poor toggle coverage**. Report the toggle coverage for the DUT from the dashboard.html file that is generated.  

**Why?** The exhaustive testbench only tests values 0-255, so upper bits [15:8] barely toggle. Running with MAXVAL = 65536 takes too long to be practical.

### Step 3: Better Coverage with Constrained Random

Now change `run_coverage.sh` back to use constrained random testbench:

**Edit line 17 in run_coverage.sh**:
```bash
# Change back to:
xvlog -sv tb_adder_constrained_random.sv || exit 1
```

**And edit line 25**:
```bash
# Change back to:
xelab -debug typical tb_adder_constrained_random -s sim \
```

Then run and generate coverage report:
```bash
./run_coverage.sh
```

**Result**: Much better toggle coverage! Report the toggle coverage for the DUT from the dashboard.html file that is generated. 

The constrained random testbench intelligently exercises corner cases and full bit ranges with minimal test cases.

---

## Learning Points

By running these tests, you'll understand:

1. **Three ways to describe hardware**:
   - Behavioral (what you want)
   - Structural manual (explicit connections)
   - Structural generate (programmatic instantiation)

2. **They all produce the same hardware** (after synthesis)

3. **Generate statements** make designs scalable (change 16 to 32 easily!)

4. **Exhaustive vs. Random Testing**:
   - Exhaustive testing s often not feasable. Testing a subset (256x256) gives poor coverage
   - Constrained random testing (10K tests) gives better coverage
   - **Key insight**: Smart test selection > brute force

5. **Code Coverage Metrics**:
   - Toggle coverage: Which bits flipped 0→1 and 1→0
   - Branch/Condition coverage: Decision logic exercised (if included)


