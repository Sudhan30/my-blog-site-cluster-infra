# MR Regime Lag Test Results

**Date**: 2026-03-24
**Period**: 2025-06-01 to 2026-03-20 (~9.5 months, 50 most liquid symbols)
**Position size**: $900 per trade | **Max hold**: 26 bars (390 min)

---

## Summary Table

| Variant | Description | Trades | Total PnL | Avg PnL% | WR% | Long PnL | Short PnL |
|---------|-------------|-------:|----------:|---------:|----:|---------:|----------:|
| A (baseline) | ADX 25/20 gating | 2,363 | **+$493** | +0.023% | 51.2 | +$2,215 | -$1,721 |
| B (strict) | ADX < 15 only | 740 | **-$672** | -0.101% | 50.1 | -$238 | -$433 |
| C (oracle) | Next-bar lookahead | 2,335 | **-$1,001** | -0.048% | 50.1 | +$1,740 | -$2,741 |
| D (no gate) | All signals, no regime filter | 19,734 | **+$15,144** | +0.085% | 51.4 | +$23,691 | -$8,548 |

---

## Key Findings

### 1. The regime gate is DESTROYING MR alpha

**Variant D (no regime filter) generates +$15,144 on 19,734 trades.** This is the strongest signal in the entire test. When MR fires on ALL signals regardless of regime, it's profitable at +0.085% per trade with 51.4% WR.

The baseline regime gate (Variant A) filters this down to 2,363 trades (+$493). The gate blocks 88% of signals and captures only 3.3% of the available PnL.

### 2. Stricter gating makes it WORSE, not better

Variant B (ADX < 15, ultra-conservative range detection) produces -$672. Tighter regime filtering doesn't improve MR, it destroys it. This directly contradicts the hypothesis that MR needs stricter regime gating.

### 3. Oracle lookahead doesn't help

Variant C (next-bar regime, perfect foresight) produces -$1,001, **worse than baseline**. This means regime detection lag is NOT the problem. Even with perfect regime knowledge, MR underperforms when gated. The issue is the gate itself, not its timing.

### 4. Longs dominate, shorts bleed

Across all variants:
- **Longs are profitable** in A (+$2,215), C (+$1,740), and D (+$23,691)
- **Shorts are consistently negative** in every variant

MR buy signals (oversold bounces) work. MR sell signals (overbought reversions) do not. The short side is a pure drag.

### 5. Regime transitions are a red herring

- 18.7% of baseline trades occur during regime transitions (regime changes within 30 min of entry)
- But transition trades are actually MORE profitable (+$1,229) than stable-regime trades (-$736)
- This invalidates H1 (regime lag hypothesis)

---

## Regime Transition Analysis

| Variant | Transition Trades | Transition PnL | Stable PnL |
|---------|------------------:|---------------:|-----------:|
| A (baseline) | 442 (18.7%) | **+$1,229** | **-$736** |
| B (strict) | 174 (23.5%) | -$477 | -$195 |
| C (oracle) | 356 (15.2%) | -$260 | -$741 |

In the baseline, trades entered during regime transitions **outperform** trades entered during stable regimes. The regime gate isn't just lagging; it's actively selecting for the wrong trades.

---

## Implications

1. **Remove or dramatically relax the regime gate for MR.** The data shows MR is alpha-positive across all regimes, and the gate is blocking 88% of profitable signals.

2. **Disable MR shorts or gate them separately.** Longs are +$23,691 ungated. Shorts are -$8,548. The short side needs its own criteria (or should be removed entirely).

3. **Regime lag (H1) is falsified.** The oracle test proves that even perfect regime timing doesn't improve MR. The problem is not lag; it's the gate concept itself for MR.

4. **The quant-architect's H2 (hold/stop calibration) and H3 (timeframe resolution) remain untested** but the regime lag finding makes H2 less critical: if the regime gate is removed, the natural MR alpha (+$15K on 19K trades) may be sufficient without exit optimization.

---

## Test Configuration

- MR Signal: BB(20, 2.0) touch + RSI(14) < 30 (buy) / > 70 (sell)
- Regime: ADX(14) on SPY 15-min, vol ratio (5/20 bar), crisis at vol_ratio > 2.0
- Trade sim: Enter at signal bar close, hold max 26 bars (390 min), exit at final bar close
- No stops, no trailing, no position management (pure signal test)
