# DailyFactor Strategy Backtest Report

**Date**: 2026-03-24
**Period**: 2025-01-01 to 2026-03-20 (304 trading days, ~14.5 months)
**Initial Capital**: $30,000 | **Final Value**: $30,271.49

---

## Summary

| Metric | Value |
|--------|-------|
| Total PnL | +$148.81 |
| Total Return | +0.90% |
| Annualized Return | +0.75% |
| Sharpe Ratio | 0.164 |
| Max Drawdown | -5.25% |
| Total Trades | 1,728 |
| Win Rate | 50.6% |
| Avg Win | +$20.77 |
| Avg Loss | -$21.13 |
| Profit Factor | 1.008 |
| Avg Hold Duration | 2.5 days |
| Unique Symbols | 180+ |

**Verdict**: The DailyFactor strategy is marginally profitable but essentially flat. +0.75% annualized vs a 30% target is nowhere close. The strategy is market-neutral by design (long top 5, short bottom 5), so it has low beta exposure but also captures very little alpha.

---

## Long vs Short Breakdown

| Side | Trades | PnL | Win Rate |
|------|-------:|----:|---------:|
| Long | 1,201 | -$316.24 | 51.1% |
| Short | 527 | +$465.05 | 49.5% |

**The short book is carrying the strategy.** Longs are net negative despite a higher win rate, meaning long losers are larger than long winners. The asymmetry (1,201 long vs 527 short) suggests the strategy opens more long positions, possibly because factor scores skew positively.

---

## Monthly Performance

| Month | Trades | PnL | Win Rate |
|-------|-------:|----:|---------:|
| 2025-01 | 103 | -$507 | 50.5% |
| 2025-02 | 94 | +$688 | 54.3% |
| 2025-03 | 130 | -$381 | 46.9% |
| 2025-04 | 141 | -$783 | 48.2% |
| 2025-05 | 121 | +$971 | 57.9% |
| 2025-06 | 98 | +$449 | 56.1% |
| 2025-07 | 120 | +$78 | 50.0% |
| 2025-08 | 110 | +$264 | 55.5% |
| 2025-09 | 121 | +$3 | 51.2% |
| 2025-10 | 131 | -$333 | 47.3% |
| 2025-11 | 109 | +$287 | 55.0% |
| 2025-12 | 109 | +$235 | 53.2% |
| 2026-01 | 129 | -$416 | 45.0% |
| 2026-02 | 115 | +$139 | 50.4% |
| 2026-03 | 97 | -$544 | 40.2% |

**Pattern**: Alternating winning and losing months. Best month: May 2025 (+$971, 57.9% WR). Worst months: April 2025 (-$783) and March 2026 (-$544). No sustained winning or losing streaks.

---

## Top/Bottom Symbols

**Best**: ENPH (+$264), MOH (+$216), UNH (+$198), WBD (+$197), KEYS (+$184)
**Worst**: UVXY (-$645), TSLA (-$340), REG (-$329), PLTR (-$297), HPE (-$159)

UVXY is a leveraged volatility ETN, not a stock. It should probably be excluded from the universe.

---

## Analysis and Recommendations

### Why the strategy is flat:

1. **No ML signal**: The ML factor (15% weight) is zeroed out since we don't have the WalkForwardTrainer model running in backtest mode. This removes a potentially differentiating signal.

2. **Factor decay within a day**: The strategy rebalances daily using prior-day factors, but factor edges decay rapidly. By the time positions are opened, the factor edge may have already been captured by faster participants.

3. **Equal position sizing (3% each)**: No conviction weighting. A high-composite-score symbol gets the same allocation as a marginal one.

4. **Universe too broad**: 518 symbols dilute factor power. Academic factor strategies typically work better on concentrated universes (100 to 200 names).

5. **Short book margin**: The simplified short handling (margin = position value) may overstate returns. Real short costs (borrow fees, margin interest) would reduce the short PnL.

### Improvements to test:

1. **Add ML signal back**: Integrate WalkForwardTrainer predictions to restore the 15% ML weight. This was designed to be the differentiating factor.

2. **Increase concentration**: Try top 3 / bottom 3 instead of 5/5. Higher conviction positions capture more of the factor spread.

3. **Conviction sizing**: Weight positions by composite z-score magnitude. Top-ranked symbol gets more capital than 5th-ranked.

4. **Filter UVXY/leveraged ETFs**: These instruments have structural decay that contaminates factor signals.

5. **Sector neutrality**: Currently long/short selection can cluster in same sectors. Adding sector constraints would improve diversification.

6. **Longer holding period**: Try weekly rebalancing (5 days) instead of daily. Reduces turnover and commission drag (~1,728 trades at $0.005/share adds up).

---

## Configuration Used

```
NUM_LONG = 5, NUM_SHORT = 5
POSITION_SIZE = 3% per position (30% total deployed)
COMMISSION = $0.005/share (IBKR rate)
Factors: Momentum 35%, MeanReversion 24%, Volume 24%, Volatility 18% (rescaled without ML)
Rebalance: Daily
```

## Raw Data

Full results JSON: `daily_factor_results.json`
Backtest script: `daily_factor_backtest.py`
