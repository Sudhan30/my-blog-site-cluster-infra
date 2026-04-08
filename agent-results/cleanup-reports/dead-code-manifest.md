# Dead Code Removal Manifest

**Date:** 2026-03-24
**Scanned:** `src/` in algo-trading-system
**Tools:** vulture (min-confidence 80), ruff (F401,F811,F841)
**Protected files:** engine.py, pairs_trading.py, config.yaml, main.py (modified by strategist/engineer today)

---

## Summary

| Category | Count | Actionable |
|---|---|---|
| Unused variables (F841) | 25 | 18 (excl. protected files) |
| Unused imports (F401/F811) | 18 | 10 (excl. protected, false positives) |
| Commented-out code blocks (3+ lines) | 155 blocks | ~120 (excl. protected files) |
| Functions defined but never called | 348 | LOW confidence, not auto-removable |

---

## HIGH Confidence: Unused Variables (F841, 100% vulture)

**Will remove on cleanup/dead-code branch:**

| File | Line | Variable | Confidence |
|---|---|---|---|
| `src/common/backtest_validation.py` | 151 | `is_sharpe` | HIGH |
| `src/common/hmm_regime.py` | 158 | `states` | HIGH |
| `src/common/signal_model.py` | 188 | `feature_cols` | HIGH |
| `src/common/slack_notifier.py` | 89 | `pnl_color` | HIGH |
| `src/common/slack_notifier.py` | 275 | `color` | HIGH |
| `src/orchestrator/agents.py` | 121 | `detector` | HIGH |
| `src/services/backtester/parallel_runner.py` | 31 | `frame` | HIGH (100% vulture) |
| `src/services/backtester/parallel_runner.py` | 466 | `trades` | HIGH |
| `src/services/chat_agent/prompts.py` | 76 | `e` (exception) | HIGH |
| `src/services/data_integrity/strict_controller.py` | 369 | `config` | HIGH |
| `src/services/data_integrity/strict_controller.py` | 475 | `results` | HIGH |
| `src/services/order_executor/intent_lock.py` | 72 | `e` (exception) | HIGH |
| `src/services/reconciliation/watchdog.py` | 94 | `latch_pattern` | HIGH |
| `src/services/risk_manager/capital_governor.py` | 148 | `position_value` | HIGH |
| `src/services/risk_manager/edge_preservation.py` | 131 | `force_recalc` | HIGH (100% vulture) |
| `src/services/risk_manager/entry_gate.py` | 146 | `log_data` | HIGH |
| `src/services/risk_manager/intent_normalizer.py` | 80 | `delta` | HIGH |
| `src/services/risk_manager/intent_normalizer.py` | 106 | `current_delta` | HIGH |
| `src/services/risk_manager/liquidity_filter.py` | 68 | `median_volume` | HIGH |
| `src/services/strategy_engine/regime_detector.py` | 165 | `hurst` | HIGH |
| `src/services/strategy_engine/sector_analysis.py` | 106 | `current_price` | HIGH |
| `src/services/strategy_engine/strategies/red_to_green.py` | 109 | `prev` | HIGH |
| `src/services/strategy_engine/strategies/scalping.py` | 71-73 | `ema_9`, `ema_21`, `roc` | HIGH |

## HIGH Confidence: Unused Imports (F401/F811)

**Will remove on cleanup/dead-code branch:**

| File | Line | Import | Confidence |
|---|---|---|---|
| `src/common/ml_walk_forward.py` | 20 | `field` from dataclasses | HIGH |
| `src/services/portfolio_tracker/strategy_aggregator.py` | 11 | `timedelta` | HIGH |
| `src/services/strategy_engine/strategies/daily_factor.py` | 23 | `Tuple` from typing | HIGH |
| `src/services/strategy_engine/strategies/inverse_etf.py` | 26 | `numpy as np` | HIGH |
| `src/services/strategy_engine/strategies/uvxy_volatility.py` | 28 | `numpy as np` | HIGH |
| `src/services/strategy_engine/strategy_auto_disabler.py` | 22 | `time` | HIGH |
| `src/services/strategy_engine/strategy_auto_disabler.py` | 32 | `Config` from common.utils | HIGH |

## FALSE POSITIVES (will NOT remove)

| File | Line | Import | Reason |
|---|---|---|---|
| `src/common/llm_router.py` | 129 | `litellm` | Availability check pattern (try/import/except) |
| `src/common/llm_router.py` | 135 | `google.genai` | Availability check pattern |
| `src/services/strategy_engine/strategies/daily_factor.py` | 34 | `WalkForwardTrainer` | Availability check pattern |
| `src/services/data_integrity/__init__.py` | various | re-exports | Public API surface for package |

## MEDIUM Confidence: Commented-Out Code (3+ lines)

155 blocks found across the codebase. Largest concentrations:

| File | Blocks | Total Lines |
|---|---|---|
| `src/services/backtester/engine.py` | 28 | ~120 | PROTECTED |
| `src/services/order_executor/main.py` | 20 | ~80 | PROTECTED |
| `src/services/risk_manager/main.py` | 22 | ~90 | PROTECTED |
| `src/services/strategy_engine/regime_detector.py` | 12 | ~50 |
| `src/services/strategy_engine/strategies/mean_reversion.py` | 7 | ~25 |
| `src/common/alpha_registry.py` | 4 | ~12 |
| `src/common/atr_calculator.py` | 4 | ~16 |
| `src/common/exit_attribution.py` | 3 | ~9 |

**Not auto-removing** commented code. Needs manual review to confirm intent.

## LOW Confidence: Uncalled Functions

348 functions defined but never called by name in the codebase. Many are:
- Alpha registry functions (called dynamically via registry pattern)
- Strategy methods (called via dispatch/orchestration)
- CLI/entry points
- Test helpers

**Not auto-removing.** Requires manual audit per function.

---

## Cleanup Plan

**Branch:** `cleanup/dead-code`
**Scope:** HIGH confidence unused variables and imports only (30 items)
**Excluded:** engine.py, pairs_trading.py, config.yaml, all main.py files
