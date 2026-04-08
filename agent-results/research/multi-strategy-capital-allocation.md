# Multi-Strategy Capital Allocation Framework

**Author**: Quant Architect | **Date**: 2026-03-24 | **Task**: #8

---

## Current State Assessment

### Strategy Arsenal Performance Summary

| Strategy | WR | Test Period | Evidence Quality | Structural Edge | Current Alloc |
|----------|-----|------------|-----------------|-----------------|---------------|
| MeanReversion | 67-75% (short), ~33% (long) | 10d live / 915d BT | Mixed: short-term strong, long-term bleed | Range-bound reversion | 2.0x (24%) |
| BreakdownShort | 73% | 8d live | Weak: untested at scale | Bearish trend capture | 2.0x (24%) |
| DailyFactor | Unknown | Backtest script exists, no results | Unvalidated | Cross-sectional factor | 0.3x (default) |
| PairsTrading | Unknown | Rebuilt, untested | Unvalidated | Market-neutral spread | 0.3x (default) |
| ML Filter | AUC 0.594 | Trained on historical | Marginal | Overlay, not standalone | N/A (modifier) |

### Key Constraints

- **$30,000 portfolio** (from backtest config)
- **Single-node K3s** (no redundancy for execution)
- **Commission**: $0.005/share (IBKR)
- **VIX-based dynamic scaling** already reduces exposure in vol spikes
- **Regime detector** gates strategy eligibility per-bar

---

## Framework Design: Regime-Conditional Kelly Allocation

### Principle

Capital allocation should be a function of **(strategy, regime, confidence)**, not a static multiplier. The current system assigns fixed Kelly multipliers per strategy. The proposed system makes allocation conditional on the regime detector's output and strategy-regime fit.

### Architecture

```
Allocation(strategy, t) = BaseKelly(strategy)
                        * RegimeMultiplier(strategy, regime_t)
                        * ConfidenceScalar(regime_confidence_t)
                        * VolScalar(VIX_t)
                        * CorrelationPenalty(portfolio_t)
```

Each component explained below.

---

### Layer 1: Base Kelly Allocation

Derived from each strategy's edge (WR and payoff ratio) using half-Kelly for safety.

| Strategy | Expected Edge | Half-Kelly Base | Notes |
|----------|--------------|-----------------|-------|
| MeanReversion | Conditional (see H1-H3) | 1.0x (reduced from 2.0x) | Pending bleed investigation |
| BreakdownShort | Strong but unvalidated | 1.0x (reduced from 2.0x) | Scale up after 30-day validation |
| DailyFactor | Unknown | 0.5x | Market-neutral, lower risk per unit |
| PairsTrading | Unknown | 0.5x | Market-neutral, lower risk per unit |

**Rationale for reductions**: Both MR and BreakdownShort are at 2.0x Kelly based on short-window results. This is overfit to recent conditions. Half-Kelly (1.0x) is the maximum for any strategy without 100+ trade validation.

### Layer 2: Regime Multiplier Matrix

This is the core innovation. Each strategy gets a multiplier based on the current regime.

| Strategy | RANGE (ADX<20) | TREND Bullish | TREND Bearish | CRISIS | UNKNOWN |
|----------|---------------|---------------|---------------|--------|---------|
| MeanReversion | **2.0x** | 0.3x | 0.5x (shorts) | 0.5x | 0.3x |
| BreakdownShort | 0.5x | 0.0x | **2.0x** | 1.5x | 0.3x |
| DailyFactor | 1.0x | 1.0x | 1.0x | 0.5x | 0.5x |
| PairsTrading | 1.0x | 1.0x | 1.0x | 0.8x | 0.5x |

**Key design choices**:
- MR gets full 2.0x **only in confirmed RANGE**. This directly addresses H1 (regime lag): if ADX is ambiguous, MR stays at 0.3x.
- BreakdownShort is the mirror: 2.0x in bearish TREND where MR bleeds. This creates natural regime hedging.
- Market-neutral strategies (DailyFactor, PairsTrading) get 1.0x across most regimes because their PnL is less regime-dependent.
- CRISIS reduces everything except BreakdownShort (which profits from panic selling).

### Layer 3: Confidence Scalar

The regime detector already outputs confidence (0.2 to 1.0). Use it directly:

```
ConfidenceScalar = max(0.3, confidence)
```

Floor of 0.3 ensures we never fully zero out. At confidence 1.0, full allocation. At 0.5, half.

### Layer 4: Vol Scalar (existing, keep as-is)

| VIX Range | Scalar |
|-----------|--------|
| < 15 | 1.0x |
| 15-25 | 0.8x |
| 25-30 | 0.6x |
| > 30 | 0.4x |

### Layer 5: Correlation Penalty

New addition. When multiple strategies are active simultaneously, reduce marginal allocation to prevent concentration.

```
CorrelationPenalty = 1.0 / (1 + 0.1 * N_active_correlated)
```

Where `N_active_correlated` = number of other active strategies with same directional bias (all-long or all-short). Market-neutral strategies don't count.

**Example**: MR (long) + DipBuyer (long) + FirstPullback (long) = 3 correlated longs.
Penalty = 1 / (1 + 0.1 * 2) = 0.83x for each.

---

## Effective Allocation Examples

### Scenario 1: Calm Range-Bound Market (VIX 14, ADX 16, confidence 0.8)

| Strategy | Base | Regime | Conf | Vol | Corr | Effective | Portfolio % |
|----------|------|--------|------|-----|------|-----------|-------------|
| MR (long) | 1.0 | 2.0 | 0.8 | 1.0 | 1.0 | 1.6x | 19.2% |
| BreakdownShort | 1.0 | 0.5 | 0.8 | 1.0 | 1.0 | 0.4x | 4.8% |
| DailyFactor | 0.5 | 1.0 | 0.8 | 1.0 | 1.0 | 0.4x | 4.8% |
| PairsTrading | 0.5 | 1.0 | 0.8 | 1.0 | 1.0 | 0.4x | 4.8% |
| **Total deployed** | | | | | | | **33.6%** |

### Scenario 2: Bearish Trend (VIX 22, ADX 30, bearish, confidence 0.9)

| Strategy | Base | Regime | Conf | Vol | Corr | Effective | Portfolio % |
|----------|------|--------|------|-----|------|-----------|-------------|
| MR (short) | 1.0 | 0.5 | 0.9 | 0.8 | 1.0 | 0.36x | 4.3% |
| BreakdownShort | 1.0 | 2.0 | 0.9 | 0.8 | 0.91 | 1.31x | 15.7% |
| DailyFactor | 0.5 | 1.0 | 0.9 | 0.8 | 1.0 | 0.36x | 4.3% |
| PairsTrading | 0.5 | 1.0 | 0.9 | 0.8 | 1.0 | 0.36x | 4.3% |
| **Total deployed** | | | | | | | **28.6%** |

### Scenario 3: Crisis (VIX 35, confidence 0.95)

| Strategy | Base | Regime | Conf | Vol | Corr | Effective | Portfolio % |
|----------|------|--------|------|-----|------|-----------|-------------|
| MR | 1.0 | 0.5 | 0.95 | 0.4 | 1.0 | 0.19x | 2.3% |
| BreakdownShort | 1.0 | 1.5 | 0.95 | 0.4 | 1.0 | 0.57x | 6.8% |
| DailyFactor | 0.5 | 0.5 | 0.95 | 0.4 | 1.0 | 0.10x | 1.2% |
| PairsTrading | 0.5 | 0.8 | 0.95 | 0.4 | 1.0 | 0.15x | 1.8% |
| **Total deployed** | | | | | | | **12.1%** |

Note: crisis mode naturally drops to ~12% deployed. This is correct behavior: capital preservation in tail events.

---

## ML Filter Integration

The ML filter (AUC 0.594) should be used as a **final gate**, not an allocation modifier:

```
if ML_score < 0.35:  # bottom quintile
    BLOCK trade entirely
elif ML_score > 0.65:  # top quintile
    allocation *= 1.15  # modest 15% boost
else:
    no change
```

**Rationale**: AUC 0.594 is barely above random (0.5). Using it as a continuous multiplier would add noise. But as a binary filter on extremes, it can reject the worst 20% of signals (which likely contain a disproportionate share of losses) and slightly boost the best 20%.

---

## Implementation Roadmap

### Phase 1: Immediate (this week)
1. **Reduce MR to 1.0x base** in config.yaml (from 2.0x)
2. **Reduce BreakdownShort to 1.0x base** (from 2.0x)
3. **Add regime multiplier lookup table** to strategy engine's position sizing logic
4. **Wire regime confidence** into allocation calculation

### Phase 2: After H1-H3 backtest results (next 1-2 weeks)
5. **Calibrate MR regime multipliers** based on actual regime-bucketed PnL
6. **Validate BreakdownShort at scale** (need 100+ trade sample)
7. **Run DailyFactor backtest** and set base allocation
8. **Run PairsTrading validation** and set base allocation

### Phase 3: Portfolio-level optimization (after Phase 2)
9. **Implement correlation penalty** (requires tracking active positions across strategies)
10. **Backtest the full framework** on 915-day data with all strategies
11. **Compare Sharpe/drawdown** of framework vs current static allocation

---

## Risk Guardrails

| Guardrail | Value | Rationale |
|-----------|-------|-----------|
| Max single-strategy allocation | 25% of portfolio | No strategy should dominate |
| Max total deployed capital | 60% of portfolio | Always keep 40% cash reserve |
| Max directional exposure | 40% net long or short | Prevent concentrated bets |
| Min strategies active | 2 (or reduce total to 15%) | Diversification floor |
| Max daily drawdown halt | -2% of portfolio | Circuit breaker |
| Strategy validation threshold | 100 trades, WR > 45%, profit factor > 1.2 | Minimum for > 0.5x base alloc |

---

## What This Framework Does NOT Solve

1. **Signal quality**: allocation scaling cannot fix a strategy that generates bad signals. MR's bleed (Task #7) must be fixed at the signal level.
2. **Execution quality**: fill rates, slippage, and the time_decay rejection epidemic (93.4% rejection rate) are execution problems, not allocation problems.
3. **Universe selection**: the system trades 158 symbols across 233 trades (too thin). Concentrating on top 20-30 liquid names would improve signal quality more than allocation optimization.

These are separate workstreams that compound with good allocation but cannot be replaced by it.
