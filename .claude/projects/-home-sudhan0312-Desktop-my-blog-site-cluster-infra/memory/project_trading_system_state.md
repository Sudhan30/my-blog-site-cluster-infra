---
name: Trading system state as of 2026-03-24
description: Key findings and pending decisions for algo-trading system strategies
type: project
---

**Critical finding**: time_decay exit strategy destroys PnL. Trades held 2-4h (time_decay zone) lose -$23.88 at 23.4% WR. Trades held 4h+ earn +$7.32 at 87.5% WR. Entry signals are directionally correct; exits are the problem.

**Why:** Bimodal hold-time distribution is textbook adverse selection by exit timing. v88 disables time_decay, sets max_hold=390min.

**How to apply:** All future backtests must use v88 as baseline. Do not test hypotheses against old time_decay code.

**Strategy status**:
- MR: 1.0x base (reduced from 2.0x), regime-conditional to 2.0x in RANGE only
- BreakdownShort: 1.0x base (reduced from 2.0x), scales to 2.0x in bearish TREND
- DailyFactor: 0.5x, short book profitable (+$465), long book negative (-$316), recommend short-only
- PairsTrading: 0.5x, rebuilt with spread exits, unvalidated
- RegimeAlpha: proposed new strategy, trade SPY/QQQ/SH/UVXY on regime transitions
- ML filter: AUC 0.594, VIX/SPY features dominate, per-stock technicals near-zero at 15-min
