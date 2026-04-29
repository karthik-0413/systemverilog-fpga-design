# FIR Filter – Golden Reference

## Filter Specification

| Parameter       | Value                     |
|-----------------|---------------------------|
| Filter Order    | 4-tap (N=4)               |
| FIR Equation    | y[n] = h0·x[n] + h1·x[n-1] + h2·x[n-2] + h3·x[n-3] |

## Coefficients

| Tap | Coefficient | Value |
|-----|-------------|-------|
| 0   | h0          | 1     |
| 1   | h1          | 2     |
| 2   | h2          | 3     |
| 3   | h3          | 4     |

## Input Sequence

| Index | x[n] |
|-------|------|
| x[0]  | 10   |
| x[1]  | 20   |
| x[2]  | 30   |
| x[3]  | 40   |
| x[4]  | 50   |
| x[5]  | 60   |
| x[6]  | 70   |
| x[7]  | 80   |
| x[8]  | 90   |

**Boundary conditions:**
- For n < 0 : values are what is stored in memory (unkown). Output data not valid till new input count == tap count. The filter outputs only N - (4-1) values. starting at y[3] - 200 and stopping at y[8] - 700.

---

## Output Calculations

```
y[0]  = 1×10 + 2×0  + 3×0  + 4×0  = 10 + 0   + 0   + 0   = 10
y[1]  = 1×20 + 2×10 + 3×0  + 4×0  = 20 + 20  + 0   + 0   = 40
y[2]  = 1×30 + 2×20 + 3×10 + 4×0  = 30 + 40  + 30  + 0   = 100
y[3]  = 1×40 + 2×30 + 3×20 + 4×10 = 40 + 60  + 60  + 40  = 200
y[4]  = 1×50 + 2×40 + 3×30 + 4×20 = 50 + 80  + 90  + 80  = 300
y[5]  = 1×60 + 2×50 + 3×40 + 4×30 = 60 + 100 + 120 + 120 = 400
y[6]  = 1×70 + 2×60 + 3×50 + 4×40 = 70 + 120 + 150 + 160 = 500
y[7]  = 1×80 + 2×70 + 3×60 + 4×50 = 80 + 140 + 180 + 200 = 600
y[8]  = 1×90 + 2×80 + 3×70 + 4×60 = 90 + 160 + 210 + 240 = 700
```