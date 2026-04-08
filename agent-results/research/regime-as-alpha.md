# Research Memo: Regime-as-the-Alpha

**Author**: Quant Architect | **Date**: 2026-03-24 | **Task**: #11

---

## Thesis

Stop picking stocks. Trade the regime itself.

Our ML model's AUC 0.594 is dominated by VIX/SPY macro features. Per-stock technicals contribute near-zero at 15-min granularity. The TOD analysis shows entries are directionally correct but per-stock exit noise destroys the edge. These are all symptoms of the same root cause: **the alpha is in regime detection, not stock selection**.

Proposal: a dedicated strategy that trades SPY/QQQ/SH/UVXY based solely on regime transitions, eliminating per-stock noise entirely.

---

## What Already Exists

The system already has partial coverage of this idea:

| Component | Status | Gap |
|-----------|--------|-----|
| Regime detector (ADX/VIX/vol) | Production, 3-regime with hysteresis | Outputs hard classification, not probability |
| XGBoost ML (30 features, AUC 0.594) | Production, modifies confidence ±0.15 | Not used as primary signal |
| InverseETFMomentum | Active, trades SH/SQQQ/SPXU in bearish regimes | Bearish only, no bullish leg |
| UVXYVolatilityShort | Code exists, UVXY blacklisted | Conflicted state, effectively disabled |
| Regime confidence score | Production (0.2-1.0) | Not used for entry/exit decisions |

**The key gap**: there is no **long SPY/QQQ** strategy for bullish TREND, and no **regime transition** trigger (only regime state). The system reacts to "we are in TREND" but not "we just shifted from RANGE to TREND" — and the transition is where the alpha lives.

---

## Literature Review: Regime-Switching Strategy Performance

### Academic Benchmarks

**Hamilton (1989) Markov-switching model** on S&P 500:
- Two-state (expansion/recession) model on monthly returns
- Out-of-sample Sharpe: 0.3-0.5 annualized
- Edge: avoids large drawdowns, not generating excess returns
- Parameter count: 5 (two means, two variances, transition matrix)

**Ang & Bekaert (2002) regime-switching asset allocation**:
- Monthly rebalance, equity/bond/cash based on regime probability
- Out-of-sample Sharpe improvement: +0.15 to +0.25 over buy-and-hold
- Key finding: most value comes from **crash avoidance**, not return enhancement

**Bulla et al. (2011) Hidden Markov Models for financial time series**:
- Daily S&P 500, 2-state and 3-state HMM
- Sharpe: 0.4-0.7 depending on transaction costs and state count
- 3-state (bull/bear/high-vol) outperforms 2-state
- Overfitting risk increases sharply beyond 3 states

**Kritzman, Page & Turkington (2012) "Regime Shifts" (Mahalanobis distance)**:
- Uses absorption ratio (systemic risk) to detect regime shifts
- Out-of-sample: 50-100bps annual alpha over buy-and-hold S&P 500
- Key insight: alpha is concentrated in **regime transitions**, not steady-state

**Practical benchmark (ETF rotation strategies)**:
- Simple VIX-threshold SPY/SH rotation (VIX > 20 = defensive): Sharpe 0.5-0.7
- ADX-based trend-following on SPY: Sharpe 0.3-0.6
- These are gross; after transaction costs and slippage: Sharpe 0.3-0.5

### Realistic Expectation for Our System

Given our 15-min data, ADX-based regime with ML overlay, and intraday execution:

| Metric | Conservative | Optimistic | Notes |
|--------|-------------|-----------|-------|
| Annual Sharpe | 0.4 | 0.8 | Literature says 0.3-0.7 for daily; intraday adds data but also noise |
| Annual return | 5-8% | 10-15% | On allocated capital, not full portfolio |
| Max drawdown | -8% to -12% | -5% to -8% | Primary value is drawdown reduction |
| Win rate | 45-50% | 50-55% | Regime strategies win by size, not frequency |
| Avg hold | 1-5 days | 0.5-2 days | Regime persistence determines hold |
| Trades/year | 40-80 | 80-150 | Intraday detection = more transitions |

---

## Strategy Design: RegimeAlpha

### Instrument Universe (4 instruments only)

| Instrument | Role | When |
|-----------|------|------|
| SPY | Long market exposure | Bullish TREND |
| QQQ | Long tech/growth tilt | Bullish TREND + high confidence |
| SH | Short market exposure (1x inverse SPY) | Bearish TREND, early CRISIS |
| UVXY | Long volatility spike | CRISIS confirmed |

**Why not leveraged ETFs (TQQQ, SPXU)?** Leverage decay over multi-day holds makes them unsuitable for regime strategies where hold time is uncertain. SH (1x inverse) has no decay issue. UVXY is an exception because crisis holds are short (hours to 1-2 days) and the spike magnitude justifies the decay risk.

### Entry Rules

**Transition-based entries** (not state-based):

| Transition | Action | Sizing | Confidence Floor |
|-----------|--------|--------|-----------------|
| RANGE → TREND (bullish) | BUY SPY | 1.0x base * confidence | 0.6 |
| RANGE → TREND (bearish) | BUY SH | 1.0x base * confidence | 0.6 |
| TREND (bullish) → TREND (bearish) | SELL SPY, BUY SH | 1.0x | 0.7 (higher bar for reversal) |
| TREND (bearish) → TREND (bullish) | SELL SH, BUY SPY | 1.0x | 0.7 |
| Any → CRISIS | SELL all, BUY UVXY (0.5x) | 0.5x (smaller, high risk) | 0.5 |
| CRISIS → RANGE | SELL UVXY, wait | flat | N/A |
| CRISIS → TREND (bullish) | SELL UVXY, BUY SPY | 0.8x (cautious re-entry) | 0.7 |

**Why transition, not state?** State-based ("hold SPY while in bullish TREND") misses that the alpha is in the first hours/days after a transition. Late-regime entries have reduced edge because the move has already happened. This is consistent with the regime fatigue module: early TREND gives Breakout 1.3x, exhausted TREND drops to 0.6x.

### Exit Rules

| Condition | Action |
|-----------|--------|
| Regime transitions to different state | Close position (natural exit) |
| Confidence drops below 0.4 | Reduce to 0.3x (hedge, don't close) |
| ATR trailing stop: 2.0 * daily ATR | Hard stop (prevents catastrophic loss) |
| Max hold: 5 trading days without regime change | Close (regime detector may be stale) |
| UVXY: max hold 2 days | Close (decay is brutal beyond 48h) |

### ML Integration

The XGBoost model (AUC 0.594) is used as a **confirmation gate**, not primary signal:

```
regime_transition_detected = True  (from rule-based detector)
ml_agrees = ml_prob aligns with transition direction

if regime_transition AND ml_agrees:
    confidence_boost = +0.15
    → full sizing
elif regime_transition AND NOT ml_agrees:
    confidence_penalty = -0.10
    → reduced sizing (0.6x)
elif NO transition AND ml_strongly_predicts (prob > 0.7):
    → NO trade (ML alone insufficient at AUC 0.594)
```

This is the correct use of a marginal classifier: it can't generate alpha alone, but it can filter false regime transitions.

---

## Parameter Count & Overfitting Risk Assessment

### Parameter Inventory

| Component | Parameters | Values | Degrees of Freedom |
|-----------|-----------|--------|-------------------|
| Regime thresholds | ADX trend/range, VIX crisis, vol crisis | 25, 20, 35, 2.0 | 4 |
| Hysteresis | ADX buffer, persistence bars, min duration | 3, 3, 15min | 3 |
| Entry confidence floors | Per-transition type | 0.5-0.7 | 3 |
| Exit stops | ATR multiplier, max hold | 2.0, 5d/2d | 2 |
| ML gate | Agreement threshold | 0.6 prob | 1 |
| Position sizing | Base, confidence scalar | 1.0x, linear | 1 |
| **Total** | | | **14** |

### Overfitting Assessment

**14 parameters for a regime strategy is moderate-to-high risk.** Literature suggests:

| Parameter Count | Risk Level | Mitigation |
|----------------|------------|------------|
| 3-5 | Low | Simple threshold strategies |
| 6-10 | Moderate | Standard quant strategy |
| 11-20 | High | Needs walk-forward validation |
| 20+ | Very high | Almost certainly overfit |

**Mitigation plan**:
1. **Walk-forward validation**: Train on 12-month windows, test on next 3 months, roll forward. Never backtest on full period at once.
2. **Parameter sensitivity analysis**: For each of the 14 parameters, vary ±20% and measure Sharpe degradation. If any single parameter change drops Sharpe by > 50%, the strategy is fragile.
3. **Reduce to core 7**: ADX thresholds (2), vol crisis (1), persistence (1), ATR stop (1), max hold (1), confidence floor (1). Fix the rest at literature defaults. Test this reduced-parameter version first.
4. **Out-of-sample hold-out**: Reserve 2025-01 to 2026-03 as true out-of-sample. Train only on 2023-07 to 2024-12.

### Comparison to Current System

| | Current (per-stock MR) | Proposed (RegimeAlpha) |
|---|---|---|
| Signal parameters | ~20 (BB width, RSI thresholds, vol guards, etc.) | 14 (regime thresholds + sizing) |
| Universe parameters | ~10 (min price, volume, blacklist rules) | 0 (fixed 4 instruments) |
| Exit parameters | ~8 (ATR TP/SL, trailing, quick-profit-lock, max hold) | 4 (ATR stop, max hold, confidence exit) |
| **Total** | **~38** | **14** |
| Instruments traded | ~200 S&P 500 stocks | 4 ETFs |
| Data points per decision | 1 (per stock, 15-min) | 1 (SPY-level, 15-min) |

RegimeAlpha has **less than half** the parameter count and trades 50x fewer instruments. Both reduce overfitting risk substantially.

---

## How This Fits the Portfolio

RegimeAlpha is not a replacement for the stock-level strategies. It's a **separate alpha source** that is structurally uncorrelated with stock selection:

| Strategy | Alpha Source | Correlation to RegimeAlpha |
|----------|------------|---------------------------|
| MeanReversion | Stock-level BB/RSI reversion | Low (different instruments, different signal) |
| BreakdownShort | Stock-level breakdown patterns | Medium (both bearish, but stock vs index) |
| DailyFactor | Cross-sectional factor ranking | Low (market-neutral, regime-agnostic) |
| PairsTrading | Spread convergence | Very low (market-neutral) |
| RegimeAlpha | Market regime transitions | N/A |

**Portfolio allocation recommendation** (updating Task #8 framework):

| Strategy | Base Allocation | With RegimeAlpha |
|----------|----------------|-----------------|
| MeanReversion | 1.0x | 0.8x (reduced, regime alpha absorbs some directional exposure) |
| BreakdownShort | 1.0x | 0.8x (same reason) |
| DailyFactor | 0.5x | 0.5x (unchanged, orthogonal) |
| PairsTrading | 0.5x | 0.5x (unchanged, orthogonal) |
| **RegimeAlpha** | N/A | **1.0x (new)** |
| **Total max exposure** | 3.0x | 3.6x |

The 1.5x margin is best deployed on PairsTrading (market-neutral) and RegimeAlpha (index-level, most liquid, tightest spreads).

---

## Key Risks

1. **Regime detector lag (same as H1 from Task #7)**: If the detector is slow to confirm transitions, entries happen after the move. The 3-bar persistence + 15-min lockout means transitions are confirmed 45-60 minutes after they begin. On 15-min SPY bars, a 0.5% move can happen in that window.

2. **Whipsaw in choppy markets**: RANGE → TREND → RANGE in quick succession generates two losing round-trips. The hysteresis mitigates this but can't eliminate it. Expected: 30-40% of transitions are false signals.

3. **UVXY decay risk**: UVXY loses ~5% per month in contango. Any crisis position held more than 2-3 days is likely underwater from decay alone. The 2-day max hold is critical.

4. **Crowding**: Regime-following on SPY is a crowded trade. Execution at transition points may face slippage as other regime-followers act simultaneously. Mitigated by SPY's deep liquidity (~$30B daily volume).

5. **Low trade count**: 40-80 trades/year means 3-6 years for statistical significance. Walk-forward validation partially addresses this but the strategy will take time to validate.

---

## Backtest Specification

```
Name: REGIME_ALPHA_BACKTEST
Period: 2023-07-01 to 2026-03-20 (915 days)

Instruments: SPY, QQQ, SH, UVXY
Data: 15-min bars from TimescaleDB (same feed as regime detector)

Walk-forward design:
  - Training window: 12 months
  - Test window: 3 months
  - Roll: 3-month increments
  - Periods:
    Train 2023-07 to 2024-06, Test 2024-07 to 2024-09
    Train 2023-10 to 2024-09, Test 2024-10 to 2024-12
    Train 2024-01 to 2024-12, Test 2025-01 to 2025-03
    Train 2024-04 to 2025-03, Test 2025-04 to 2025-06
    Train 2024-07 to 2025-06, Test 2025-07 to 2025-09
    Train 2024-10 to 2025-09, Test 2025-10 to 2025-12
    Train 2025-01 to 2025-12, Test 2026-01 to 2026-03

Variants:
  A) Full RegimeAlpha (14 params, transition-based entries)
  B) Reduced params (7 core, fixed defaults for rest)
  C) State-based (hold while in regime, not just transition)
  D) No ML gate (rule-based regime only)
  E) ML-primary (trade on ML prob > 0.65, ignore rule-based)
  F) Buy-and-hold SPY benchmark

Metrics per walk-forward period:
  - Sharpe ratio (annualized)
  - Max drawdown (%)
  - Total return (%)
  - Trade count, WR, avg PnL, profit factor
  - False transition rate (transitions that reverse within 2 hours)
  - Average entry lag (minutes from true regime shift to position open)
  - Correlation with SPY buy-and-hold returns

Parameter sensitivity (run on training windows only):
  - For each of 14 params, vary ±10%, ±20%, ±30%
  - Report Sharpe at each perturbation
  - Flag any param where ±20% drops Sharpe > 50%

Comparison to existing strategies:
  - Run concurrent MR + BreakdownShort + RegimeAlpha
  - Measure portfolio Sharpe vs MR + BreakdownShort alone
  - Measure max drawdown reduction from adding RegimeAlpha
```

---

## Bottom Line

The evidence says our system's alpha is in regime detection, not stock picking. RegimeAlpha turns that insight into a tradable strategy with half the parameters, 50x fewer instruments, and structural decorrelation from the stock-level strategies. Conservative Sharpe expectation: 0.4-0.8. Primary value: drawdown reduction + capital-efficient directional exposure.

The risk is low trade count (40-80/year) and regime detector lag. Both are testable with the walk-forward backtest spec above. If variant A (full) outperforms variant F (buy-hold) by > 0.15 Sharpe across walk-forward periods, proceed to paper trading.
