# Time-of-Day Bucketing Analysis

**Date**: 2026-03-24
**Data Range**: 2026-03-11 to 2026-03-20 (7 trading days)
**Total Orders**: 2,111 | **Total Trades**: 233
**Net PnL**: -$18.19 | **Overall Win Rate**: 33.5%

---

## Executive Summary

The system is **net negative across all time buckets except 10:00 and 15:30**. The dominant exit strategy (`eod_forced_exit`) accounts for 125/233 trades, indicating most positions are held until EOD rather than being closed by the entry strategy's own logic. The `time_decay` rejection rate is extremely high (>95%) in afternoon buckets, suggesting risk filters are overly aggressive or the strategy generates too many low-quality signals.

**Key findings:**
1. **Best entry window**: 15:30 ET (+$0.90, 51.9% WR) and 10:00 ET (+$1.74, 46.7% WR)
2. **Worst entry window**: 09:30 ET (-$6.58, 27.8% WR) and 11:00 ET (-$8.13, 30.9% WR)
3. **Exit clustering**: 131/233 trades (56%) exit in the 15:30 bucket (EOD forced exits)
4. **Rejection epidemic**: 1,551/2,111 orders (73.5%) rejected, almost all from `time_decay` strategy

---

## Orders: 30-min Time Buckets (ET)

| Bucket | Total | Filled | Rejected | Buys | Sells | Fill% | Symbols | Days |
|--------|------:|-------:|---------:|-----:|------:|------:|--------:|-----:|
| 09:30  |    27 |     21 |        6 |   18 |     9 |  77.8 |      18 |    4 |
| 10:00  |    20 |     20 |        0 |   20 |     0 | 100.0 |      20 |    3 |
| 10:30  |    22 |     22 |        0 |   22 |     0 | 100.0 |      22 |    2 |
| 11:00  |    87 |     87 |        0 |   85 |     2 | 100.0 |      76 |    8 |
| 11:30  |     3 |      3 |        0 |    3 |     0 | 100.0 |       3 |    3 |
| 12:30  |   229 |     13 |      214 |    2 |   227 |   5.7 |      15 |    6 |
| 13:00  |   247 |     12 |      235 |    1 |   246 |   4.9 |      15 |    4 |
| 13:30  |   234 |     16 |      218 |    0 |   234 |   6.8 |      18 |    3 |
| 14:00  |   300 |     82 |      218 |    1 |   299 |  27.3 |      77 |    8 |
| 14:30  |   228 |      8 |      220 |    3 |   225 |   3.5 |      10 |    5 |
| 15:00  |   324 |    104 |      220 |   99 |   225 |  32.1 |      86 |    8 |
| 15:30  |   390 |    170 |      220 |   25 |   365 |  43.6 |     115 |    8 |

**Observation**: Morning buckets (09:30 to 11:30) are almost entirely buy orders with high fill rates. Afternoon buckets (12:30+) are dominated by sell orders with massive rejection rates. The afternoon sell orders are `time_decay` exit signals being blocked by risk filters.

---

## Trades: PnL by Entry Time Bucket (ET)

| Bucket | Trades | Total PnL | Avg PnL | Avg PnL% | Win | Loss | WR%  | Best  | Worst  |
|--------|-------:|----------:|--------:|----------:|----:|-----:|-----:|------:|-------:|
| 09:30  |     18 |    -$6.58 |  -$0.37 |   -0.519% |   5 |   13 | 27.8 | $1.64 | -$1.74 |
| 10:00  |     15 |    +$1.74 |  +$0.12 |   +0.113% |   7 |    8 | 46.7 | $2.49 | -$0.76 |
| 10:30  |      8 |    -$3.89 |  -$0.49 |   -0.649% |   2 |    6 | 25.0 | $0.22 | -$1.09 |
| 11:00  |     68 |    -$8.13 |  -$0.12 |   -0.295% |  21 |   45 | 30.9 | $1.16 | -$2.10 |
| 11:30  |      2 |    -$0.25 |  -$0.13 |   -0.800% |   0 |    2 |  0.0 | -$0.02 | -$0.23 |
| 12:30  |      2 |    -$0.04 |  -$0.02 |   -0.130% |   1 |    1 | 50.0 | $0.02 | -$0.06 |
| 14:30  |      2 |    -$0.29 |  -$0.15 |   -0.970% |   0 |    2 |  0.0 | -$0.05 | -$0.24 |
| 15:00  |     91 |    -$1.65 |  -$0.02 |   -0.187% |  28 |   60 | 30.8 | $0.90 | -$0.79 |
| 15:30  |     27 |    +$0.90 |  +$0.03 |   +0.034% |  14 |   12 | 51.9 | $0.54 | -$0.12 |

**Note**: Hold duration is 0 for all buckets, meaning the `hold_duration` column is not being populated correctly in the trades table.

---

## Trades: PnL by Exit Time Bucket (ET)

| Bucket | Trades | Total PnL | Avg PnL | Avg PnL% | Win | Loss | WR%  |
|--------|-------:|----------:|--------:|----------:|----:|-----:|-----:|
| 09:30  |      3 |    -$2.16 |  -$0.72 |   -0.967% |   0 |    3 |  0.0 |
| 11:00  |      2 |    -$0.20 |  -$0.10 |   -0.105% |   0 |    2 |  0.0 |
| 12:30  |     10 |    -$5.29 |  -$0.53 |   -0.781% |   1 |    9 | 10.0 |
| 13:00  |     10 |    -$4.02 |  -$0.40 |   -0.593% |   1 |    9 | 10.0 |
| 13:30  |     11 |    -$3.29 |  -$0.30 |   -0.400% |   5 |    6 | 45.5 |
| 14:00  |     56 |   -$11.27 |  -$0.20 |   -0.471% |  11 |   43 | 19.6 |
| 14:30  |      5 |    +$0.03 |  +$0.01 |   -0.174% |   3 |    2 | 60.0 |
| 15:00  |      5 |    +$0.45 |  +$0.09 |   +0.162% |   3 |    2 | 60.0 |
| 15:30  |    131 |    +$7.56 |  +$0.06 |   -0.039% |  54 |   73 | 41.2 |

**Observation**: Mid-day exits (12:30 to 14:00) are catastrophically bad. The 14:00 exit bucket alone accounts for -$11.27 (62% of total losses). In contrast, 15:30 exits (EOD forced) are slightly net positive at +$7.56, suggesting holding until close recovers some intraday drawdowns.

---

## Trades: PnL by Strategy x Entry Time

| Strategy        | Bucket | Trades | Total PnL | Avg PnL% | WR%   |
|-----------------|--------|-------:|----------:|----------:|------:|
| eod_forced_exit | 10:00  |      3 |    +$3.92 |   +1.737% | 100.0 |
| eod_forced_exit | 11:00  |      4 |    +$2.61 |   +1.253% | 100.0 |
| eod_forced_exit | 14:30  |      2 |    -$0.29 |   -0.970% |   0.0 |
| eod_forced_exit | 15:00  |     89 |    -$1.61 |   -0.190% |  31.5 |
| eod_forced_exit | 15:30  |     27 |    +$0.90 |   +0.034% |  51.9 |
| time_decay      | 09:30  |     17 |    -$8.22 |   -0.677% |  23.5 |
| time_decay      | 10:00  |     12 |    -$2.18 |   -0.293% |  33.3 |
| time_decay      | 10:30  |      8 |    -$3.89 |   -0.649% |  25.0 |
| time_decay      | 11:00  |     64 |   -$10.74 |   -0.392% |  26.6 |
| time_decay      | 11:30  |      2 |    -$0.25 |   -0.800% |   0.0 |
| time_decay      | 12:30  |      2 |    -$0.04 |   -0.130% |  50.0 |
| time_decay      | 15:00  |      2 |    -$0.04 |   -0.025% |   0.0 |
| trailing_stop   | 09:30  |      1 |    +$1.64 |   +2.150% | 100.0 |

**Critical finding**: `time_decay` is the primary exit strategy and it is net negative in every single bucket. The 11:00 bucket is the worst (-$10.74 across 64 trades, 26.6% WR). This strategy is systematically losing money.

---

## Daily PnL Summary

| Date       | Trades | Daily PnL | Win Rate | Symbols | Cumulative |
|------------|-------:|----------:|---------:|--------:|-----------:|
| 2026-03-11 |     52 |    -$1.64 |    48.1% |      50 |     -$1.64 |
| 2026-03-12 |     27 |    -$5.19 |    44.4% |      27 |     -$6.83 |
| 2026-03-13 |     27 |    -$6.39 |    14.8% |      27 |    -$13.22 |
| 2026-03-17 |     52 |    -$1.79 |    19.2% |      49 |    -$15.01 |
| 2026-03-18 |     39 |    -$2.06 |    35.9% |      38 |    -$17.07 |
| 2026-03-19 |     18 |    -$0.74 |    22.2% |      17 |    -$17.81 |
| 2026-03-20 |     18 |    -$0.38 |    50.0% |      18 |    -$18.19 |

**Note**: Every single day is net negative. No winning days in the 7-day sample. March 13 was the worst day (-$6.39, 14.8% WR). The system lost on all 7 trading days.

---

## Order Entry Strategy Breakdown

| Strategy          | Bucket | Orders | Filled | Rejected | Fill% |
|-------------------|--------|-------:|-------:|---------:|------:|
| FirstPullback     | 10:00  |     18 |     18 |        0 | 100%  |
| FirstPullback     | 10:30  |     16 |     16 |        0 | 100%  |
| FirstPullback     | 11:00  |     64 |     64 |        0 | 100%  |
| FirstPullback     | 12:30  |      1 |      1 |        0 | 100%  |
| FirstPullback     | 15:00  |     35 |     35 |        0 | 100%  |
| FirstPullback     | 15:30  |      4 |      4 |        0 | 100%  |
| IntradayMomentum  | 09:30  |     18 |     18 |        0 | 100%  |
| IntradayMomentum  | 10:00  |      1 |      1 |        0 | 100%  |
| IntradayMomentum  | 10:30  |      5 |      5 |        0 | 100%  |
| IntradayMomentum  | 11:00  |     12 |     12 |        0 | 100%  |
| IntradayMomentum  | 11:30  |      3 |      3 |        0 | 100%  |
| IntradayMomentum  | 14:00  |      1 |      1 |        0 | 100%  |
| IntradayMomentum  | 14:30  |      3 |      3 |        0 | 100%  |
| IntradayMomentum  | 15:00  |     53 |     53 |        0 | 100%  |
| IntradayMomentum  | 15:30  |     19 |     19 |        0 | 100%  |
| MeanReversion     | 10:00  |      1 |      1 |        0 | 100%  |
| MeanReversion     | 11:00  |      2 |      2 |        0 | 100%  |
| ORB               | 10:30  |      1 |      1 |        0 | 100%  |
| ORB               | 11:00  |      7 |      7 |        0 | 100%  |
| ORB               | 13:00  |      1 |      1 |        0 | 100%  |
| ORB               | 15:00  |     11 |     11 |        0 | 100%  |
| ORB               | 15:30  |      2 |      2 |        0 | 100%  |

Entry strategies have 100% fill rate. All rejections come from exit strategies.

---

## Rejection Analysis

| Bucket | Strategy   | Rejections |
|--------|------------|----------:|
| 13:00  | time_decay |       235 |
| 15:30  | time_decay |       220 |
| 15:00  | time_decay |       220 |
| 14:30  | time_decay |       220 |
| 14:00  | time_decay |       218 |
| 13:30  | time_decay |       218 |
| 12:30  | time_decay |       214 |
| 09:30  | time_decay |         6 |

**1,551 rejections, ALL from `time_decay`**. The time_decay exit strategy generates an enormous number of sell signals that are rejected (likely by risk management filters). This is a signal quality problem: the strategy wants to exit constantly but is being blocked.

---

## Top/Bottom 10 Symbols

**Best performers:**

| Symbol | Trades | PnL    | Avg PnL% | WR%   |
|--------|-------:|-------:|----------:|------:|
| CF     |      2 | +$2.33 |   +1.570% |  50.0 |
| APD    |      2 | +$1.91 |   +1.255% | 100.0 |
| CVX    |      3 | +$1.11 |   +0.413% |  33.3 |
| NTRS   |      1 | +$0.90 |   +1.190% | 100.0 |
| FSLR   |      3 | +$0.78 |   +0.197% |  33.3 |
| CME    |      1 | +$0.73 |   +0.970% | 100.0 |
| JBL    |      1 | +$0.67 |   +0.890% | 100.0 |
| MU     |      1 | +$0.57 |   +0.750% | 100.0 |
| EOG    |      2 | +$0.46 |   +0.305% | 100.0 |
| APA    |      1 | +$0.43 |   +0.570% | 100.0 |

**Worst performers:**

| Symbol | Trades | PnL    | Avg PnL% | WR% |
|--------|-------:|-------:|----------:|----:|
| PAYC   |      1 | -$2.10 |   -2.800% |   0 |
| HPE    |      1 | -$1.74 |   -1.190% |   0 |
| CBOE   |      1 | -$1.49 |   -1.020% |   0 |
| UVXY   |      2 | -$1.42 |   -0.675% |  50 |
| CRWD   |      1 | -$1.24 |   -1.630% |   0 |
| ADBE   |      1 | -$1.21 |   -1.610% |   0 |
| FTV    |      1 | -$1.20 |   -1.610% |   0 |
| DRI    |      1 | -$1.13 |   -1.490% |   0 |
| SMCI   |      1 | -$1.09 |   -1.450% |   0 |
| TSLA   |      2 | -$1.00 |   -0.840% |   0 |

---

## Actionable Recommendations

1. **Avoid 09:30 entries**: The first 30 minutes show the worst risk-adjusted returns (-0.52% avg, 27.8% WR). Consider a 10:00 ET start time.

2. **Limit 11:00 bucket exposure**: 68 trades with -$8.13 total PnL and 30.9% WR. This is the highest-volume losing bucket. Either reduce position sizing or tighten entry criteria during this window.

3. **Investigate time_decay strategy**: 1,551 rejections out of 1,661 time_decay orders (93.4% rejection rate). Either the strategy signal quality is too low, or the risk filters are miscalibrated. When time_decay trades do execute, they lose money in every bucket.

4. **Lean into 15:30 and 10:00 entries**: These are the only net-positive entry windows. Consider increasing allocation during these periods.

5. **Fix hold_duration tracking**: All trades show 0 hold duration, which means the field is not being computed correctly. This needs a code fix.

6. **EOD forced exits are recovering losses**: Positions forced to close at EOD (+$7.56) perform better than mid-day exits, suggesting the entry strategies are directionally correct but time_decay exits are cutting winners too early.

7. **Reduce symbol universe**: 158 unique symbols across 233 trades means extremely thin coverage. Focus on the top 20 most liquid names to improve signal quality.
