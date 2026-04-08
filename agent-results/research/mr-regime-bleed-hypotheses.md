# Research Memo: Why Mean Reversion Bleeds in Non-Bull Regimes

**Author**: Quant Architect | **Date**: 2026-03-24 | **Task**: #7

---

## Problem Statement

MeanReversion shows 67-75% WR on short windows (8-10 day live tests) but bleeds -$0.70/trade over the 915-day backtest. The strategy is the highest-allocated at 2.0x Kelly (24% of portfolio). Understanding *why* it bleeds at scale is the single highest-leverage question for the system.

## Evidence Base

| Source | Period | WR | Avg PnL/Trade | Net |
|--------|--------|-----|----------------|-----|
| 10-day live | Mar 2026 | 75% | +$0.47 | +$47 |
| 915-day backtest | Jul 2023 - Mar 2026 | ~33% | -$0.70 | large negative |
| TOD analysis (7d) | Mar 11-20, 2026 | 33.5% (all strats) | -$0.08 | -$18.19 |

**Key data points from the codebase**:
- MR uses 15-min candles for signal generation
- BUY: price <= lower BB * 1.03 AND RSI < 42
- SELL (short): price > upper BB * 1.05 AND RSI > 70 AND RSI declining >= 1.0pt
- Max hold: 90 minutes
- TP/SL: ATR * 3.0 / ATR * 2.0 (1.5:1 R:R)
- Regime gating: allowed in RANGE, CRISIS, and bearish TREND
- Regime fatigue: MR gets 0.5x modifier in early TREND, scales to 1.2x in exhausted TREND
- VIX scaling: position cut to 0.4x when VIX > 30
- ML features: VIX/SPY dominate, per-stock technicals have near-zero predictive power at 15-min

---

## Hypothesis #1: Asymmetric Regime Exposure (MR takes both sides of a trending market)

**Rank: #1 (highest testability, highest prior probability)**

### Thesis

MR's edge exists only in true range-bound regimes (ADX < 20, symbol near VWAP). But the regime detector has hysteresis (3-bar persistence + 15-min minimum duration + ADX ±3 buffer), which means:

1. **Trend-to-range transition lag**: When a trend starts, ADX takes time to rise above 25. During this lag, regime reads "RANGE" and MR fires BUY signals into a developing downtrend (or SELL into an uptrend).
2. **Range-to-trend transition lag**: When mean reversion should stop, the regime detector is still showing RANGE for 15+ minutes. MR accumulates losing positions during the transition.
3. **Bearish trend gate allows MR shorts, but MR longs in early trend are the real killer**: The direction-aware gate (v82) blocks LONG momentum in bearish trends, but MR is allowed in RANGE. The problem is that a stock declining from RANGE into TREND hasn't been gated yet.

**Why this explains the short-term vs long-term divergence**: Over 10 days in a calm market, regime detection is mostly correct. Over 915 days spanning 2023-2026 (including the 2023 rate hike volatility, 2024 Aug crash, various sector rotations), regime transitions happen frequently and the lag bleeds MR.

### Backtest Specification

```
Name: MR_REGIME_LAG_TEST
Period: 2023-07-01 to 2026-03-20 (full 915 days)
Strategy: MeanReversion only (isolate from other strategies)
Variants:
  A) Baseline: current regime gating (ADX 25/20 with hysteresis)
  B) Strict regime: ADX < 15 only (ultra-conservative range detection)
  C) Lookahead oracle: use next-bar ADX to gate (measures lag cost)
  D) No regime gate: MR fires on all signals regardless of regime

Metrics per variant:
  - Total PnL, WR, avg PnL/trade, Sharpe
  - PnL bucketed by: actual regime at entry, regime 30min after entry
  - Count of trades where regime changed within hold period
  - Separate long vs short PnL

Key question answered: What fraction of MR losses come from trades entered
during regime transitions (regime changed within 30min of entry)?
```

---

## Hypothesis #2: 90-Minute Max Hold + ATR Stops Create Negative Skew in Volatile Regimes

**Rank: #2 (high testability, strong mechanistic basis)**

### Thesis

The current TP/SL is ATR * 3.0 / ATR * 2.0 with a 90-minute max hold. This creates a structural problem:

1. **In calm markets (VIX < 20)**: ATR is small, BB bands are tight, MR signals fire on small deviations. The 1.5:1 R:R is adequate because prices revert within the hold window. This is the regime where MR's 75% WR lives.

2. **In volatile markets (VIX 20-30)**: ATR expands, stops widen proportionally, but the 90-minute hold window doesn't scale. Result: positions hit max hold before reaching TP, get force-exited at a loss. The TOD data confirms this: `time_decay` exits (which include max-hold forced exits) are net negative in **every single bucket** with 26.6% WR at 11:00.

3. **The "quick profit lock" (v71)** exacerbates this: if gain >= 0.5% within 15 min, trailing tightens to 0.3%. In volatile markets, this locks in tiny profits while letting losers run to full SL. Classic negative skew.

4. **VIX scaling (0.4x at VIX > 30) reduces position size but not frequency**. MR still generates the same number of signals; each just loses less per trade but the bleed continues.

**Why this explains short vs long term**: Short-term tests in March 2026 are in relatively calm markets. The 915-day period includes extended VIX > 25 stretches where this mechanism grinds.

### Backtest Specification

```
Name: MR_HOLD_STOP_CALIBRATION
Period: 2023-07-01 to 2026-03-20
Strategy: MeanReversion only
Variants:
  A) Baseline: 90-min hold, ATR*3/ATR*2 TP/SL
  B) Extended hold: 180-min hold, same TP/SL
  C) Tighter stops: 90-min hold, ATR*2/ATR*1.5 TP/SL (faster cut)
  D) VIX-adaptive hold: hold = 90min when VIX<20, 45min when VIX>25
  E) No quick-profit-lock: disable v71 trailing tightening
  F) Symmetric: ATR*2/ATR*2 (1:1 R:R but higher WR expected)

Segmentation:
  - Bucket all trades by VIX at entry: <15, 15-20, 20-25, 25-30, >30
  - Bucket by exit reason: TP hit, SL hit, max hold, trailing stop
  - Compute: avg hold duration, % that hit max hold, PnL by exit type

Key question answered: What % of MR losses come from max-hold forced exits,
and does VIX-adaptive hold time eliminate the bleed?
```

---

## Hypothesis #3: 15-Min Candle Aggregation Destroys Intraday MR Signal Precision

**Rank: #3 (moderate testability, supported by ML finding)**

### Thesis

MR signals are generated on 15-minute candles (aggregated from 1-min data in main.py). But mean reversion at the intraday level is a fast phenomenon: a stock touches the lower BB, bounces, and the trade should be entered and exited within minutes, not quarter-hours.

Evidence:
- **ML finding**: per-stock technicals (RSI, BB) have near-zero predictive power at 15-min. This is consistent with MR signals being stale by the time they're acted on.
- **VIX/SPY features dominate ML**: macro regime matters more than individual stock MR signals at 15-min granularity, suggesting the signal-to-noise ratio for stock-level MR is destroyed by the aggregation.
- **TOD data**: the 15:30 bucket (last 30 min) is the only positive MR window. This is when intraday ranges compress and MR signals finally align with the aggregation period.

The mechanism: a stock dips below the lower BB on a 1-min candle at minute 3 of a 15-min bar. By the time the 15-min candle closes and MR generates a BUY signal, the bounce has already happened. MR enters at minute 15+ at a worse price, and the remaining reversion potential is smaller than the ATR-based stop.

**Why this explains short vs long term**: In calm, low-vol markets (the 10-day test), 15-min candles still capture most of the range because the bands are tight relative to bar size. In trending/volatile markets, the bar-to-signal lag is fatal.

### Backtest Specification

```
Name: MR_TIMEFRAME_RESOLUTION
Period: 2023-07-01 to 2026-03-20
Strategy: MeanReversion only
Variants:
  A) Baseline: 15-min candle signal generation
  B) 5-min candles: compute BB/RSI on 5-min, same thresholds
  C) 1-min candles with 15-min confirmation: 1-min BB touch triggers
     signal, 15-min RSI must confirm
  D) Adaptive: 5-min in first/last hour (high vol), 15-min midday

Additional measurements:
  - For each trade, compute: minutes between BB touch (1-min) and
    actual entry. This is the "signal lag"
  - Correlate signal lag with trade PnL
  - Measure: % of BB touches that revert >0.5% within 5 min vs 15 min

Key question answered: Does reducing signal granularity from 15-min to 5-min
materially improve MR entry timing and PnL?
```

---

## Hypothesis Ranking Summary

| # | Hypothesis | Prior Probability | Testability | Expected Impact if True |
|---|-----------|-------------------|-------------|------------------------|
| 1 | Regime transition lag | 45% | High (oracle variant isolates) | Fix could eliminate 30-50% of MR losses |
| 2 | Hold/stop asymmetry in vol | 35% | High (clean A/B variants) | Fix could eliminate 20-40% of MR losses |
| 3 | 15-min aggregation lag | 20% | Medium (requires 1-min infra) | Fix could improve entry by 0.2-0.5% per trade |

**These are not mutually exclusive.** The most likely reality is all three contribute, with H1 and H2 being the dominant factors. H3 is a structural disadvantage that caps MR's ceiling even if H1 and H2 are fixed.

---

## Recommended Test Order

1. **Run H1 first** (regime lag): cheapest to implement (just change ADX thresholds in backtest variants), and the oracle variant gives a clean upper bound on how much regime lag costs.
2. **Run H2 second** (hold/stop): also cheap, just parameter changes. The VIX-bucketed analysis is the key deliverable.
3. **Run H3 last** (timeframe): requires backtester infrastructure to support 5-min candle MR, which may need code changes.

---

## Implications for Task #8 (Capital Allocation)

Regardless of which hypothesis dominates:
- MR's 2.0x Kelly allocation is **not justified** until the bleed source is identified and fixed
- Interim recommendation: reduce MR to 1.0x, reallocate 12% to BreakdownShort (which has structural edge in bearish regimes where MR bleeds)
- MR should be regime-conditional: 2.0x in confirmed RANGE, 0.5x otherwise
