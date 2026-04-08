#!/usr/bin/env python3
"""
MR_REGIME_LAG_TEST — Mean Reversion Regime Transition Analysis

Tests whether MR losses come from regime detection lag:
  A) Baseline: ADX 25/20 gating with hysteresis
  B) Strict: ADX < 15 only
  C) Lookahead oracle: use next-bar regime (upper bound on lag cost)
  D) No regime gate: MR fires on all signals

For each variant, measures:
  - Trades entered during regime transitions
  - PnL by regime at entry vs regime 30 min after
  - Long vs short breakdown

Uses SPY 15-min data for regime detection, per-symbol 15-min for MR signals.
"""
import sys
import os
import json
import psycopg2
import pandas as pd
import numpy as np
from datetime import datetime, timedelta, date
from collections import defaultdict

DB_CONFIG = {
    'host': '127.0.0.1', 'port': 5510,
    'user': 'trading_user', 'password': 'xl9L3QZGX55fUQ5iquOuLFm2avFZBQcj',
    'dbname': 'trading_db', 'connect_timeout': 30,
}

# MR signal params (matching mean_reversion.py)
BB_PERIOD = 20
BB_STD = 2.0
RSI_PERIOD = 14
RSI_OVERSOLD = 30
RSI_OVERBOUGHT = 70

# Regime params
ADX_PERIOD = 14
ADX_TREND_THRESHOLD = 25
ADX_RANGE_THRESHOLD = 20
ADX_HYSTERESIS = 3
HURST_TREND = 0.55
VOL_CRISIS = 2.0

# Trade params
HOLD_MINUTES = 390  # max hold (current system default)
POSITION_SIZE = 900  # ~$900 per trade (3% of $30K)


def calculate_adx(df, period=14):
    """Calculate ADX, +DI, -DI from OHLC data."""
    high, low, close = df['high'], df['low'], df['close']
    tr1 = high - low
    tr2 = abs(high - close.shift(1))
    tr3 = abs(low - close.shift(1))
    tr = pd.concat([tr1, tr2, tr3], axis=1).max(axis=1)

    up = high - high.shift(1)
    down = low.shift(1) - low
    plus_dm = np.where((up > down) & (up > 0), up, 0)
    minus_dm = np.where((down > up) & (down > 0), down, 0)

    atr = pd.Series(tr.values, index=df.index).rolling(period).mean()
    plus_di = 100 * pd.Series(plus_dm, index=df.index).rolling(period).mean() / atr
    minus_di = 100 * pd.Series(minus_dm, index=df.index).rolling(period).mean() / atr
    dx = 100 * abs(plus_di - minus_di) / (plus_di + minus_di)
    adx = dx.rolling(period).mean()
    return adx, plus_di, minus_di


def classify_regime(adx_val, vol_ratio, threshold_trend=25, threshold_range=20):
    """Classify regime from ADX and volatility ratio."""
    if pd.isna(adx_val):
        return 'unknown'
    if vol_ratio > VOL_CRISIS:
        return 'crisis'
    if adx_val > threshold_trend:
        return 'trend'
    if adx_val < threshold_range:
        return 'range'
    return 'trend'  # between range/trend thresholds, default to trend


def compute_bb_rsi(df, bb_period=20, bb_std=2.0, rsi_period=14):
    """Compute Bollinger Bands and RSI."""
    close = df['close']
    bb_mid = close.rolling(bb_period).mean()
    bb_std_val = close.rolling(bb_period).std()
    df = df.copy()
    df['bb_upper'] = bb_mid + bb_std * bb_std_val
    df['bb_lower'] = bb_mid - bb_std * bb_std_val
    df['bb_mid'] = bb_mid
    df['bb_pct'] = (close - df['bb_lower']) / (df['bb_upper'] - df['bb_lower'])

    # RSI
    delta = close.diff()
    gain = delta.where(delta > 0, 0.0).rolling(rsi_period).mean()
    loss = (-delta.where(delta < 0, 0.0)).rolling(rsi_period).mean()
    rs = gain / loss.replace(0, np.nan)
    df['rsi'] = 100 - (100 / (1 + rs))
    return df


def load_15min_data(conn, symbol, start_date, end_date):
    """Load 15-min bars by aggregating 1-min data."""
    cur = conn.cursor()
    cur.execute("""
        SELECT
            time_bucket('15 minutes', time) AS bucket,
            (array_agg(open ORDER BY time))[1] AS open,
            MAX(high) AS high,
            MIN(low) AS low,
            (array_agg(close ORDER BY time DESC))[1] AS close,
            SUM(volume) AS volume
        FROM market_data
        WHERE symbol = %s AND timeframe = '1min'
          AND time >= %s AND time < %s::date + interval '1 day'
        GROUP BY bucket
        ORDER BY bucket
    """, (symbol, start_date, end_date))
    rows = cur.fetchall()
    cur.close()

    if not rows:
        return pd.DataFrame()

    df = pd.DataFrame(rows, columns=['time', 'open', 'high', 'low', 'close', 'volume'])
    for c in ['open', 'high', 'low', 'close']:
        df[c] = df[c].astype(float)
    df['volume'] = df['volume'].astype(float)
    df = df.set_index('time').sort_index()
    return df


def generate_mr_signals(df_15m):
    """Generate MR buy/sell signals from 15-min OHLCV data.

    BUY: price touches lower BB AND RSI < oversold
    SELL: price touches upper BB AND RSI > overbought
    """
    df = compute_bb_rsi(df_15m)
    signals = []

    for i in range(BB_PERIOD + RSI_PERIOD, len(df)):
        row = df.iloc[i]
        t = df.index[i]

        if pd.isna(row['rsi']) or pd.isna(row['bb_lower']):
            continue

        # BUY signal: touch lower BB + RSI oversold
        if row['close'] <= row['bb_lower'] and row['rsi'] < RSI_OVERSOLD:
            signals.append({
                'time': t, 'signal': 'buy', 'price': row['close'],
                'rsi': row['rsi'], 'bb_pct': row['bb_pct'],
            })

        # SELL signal: touch upper BB + RSI overbought (short)
        if row['close'] >= row['bb_upper'] and row['rsi'] > RSI_OVERBOUGHT:
            signals.append({
                'time': t, 'signal': 'sell', 'price': row['close'],
                'rsi': row['rsi'], 'bb_pct': row['bb_pct'],
            })

    return signals


def compute_regime_series(spy_15m, adx_trend=25, adx_range=20):
    """Compute regime at each 15-min bar for SPY."""
    adx, plus_di, minus_di = calculate_adx(spy_15m)

    returns = spy_15m['close'].pct_change()
    vol_short = returns.rolling(5).std()
    vol_long = returns.rolling(20).std()
    vol_ratio = vol_short / vol_long.replace(0, np.nan)

    regimes = []
    for i in range(len(spy_15m)):
        a = adx.iloc[i]
        vr = vol_ratio.iloc[i] if not pd.isna(vol_ratio.iloc[i]) else 1.0
        r = classify_regime(a, vr, adx_trend, adx_range)
        regimes.append(r)

    spy_15m = spy_15m.copy()
    spy_15m['regime'] = regimes
    spy_15m['adx'] = adx.values
    spy_15m['vol_ratio'] = vol_ratio.values
    return spy_15m


def get_regime_at(regime_df, t):
    """Get regime at time t (use most recent bar <= t)."""
    mask = regime_df.index <= t
    if mask.any():
        return regime_df.loc[mask, 'regime'].iloc[-1]
    return 'unknown'


def get_regime_after(regime_df, t, minutes=30):
    """Get regime `minutes` after time t."""
    target = t + timedelta(minutes=minutes)
    return get_regime_at(regime_df, target)


def simulate_trade(df_15m, entry_time, signal_type, entry_price, max_hold_bars=26):
    """Simulate a trade: hold up to max_hold_bars of 15-min candles.

    Returns exit_price, exit_time, pnl_pct.
    """
    entry_idx = df_15m.index.get_indexer([entry_time], method='ffill')[0]
    if entry_idx < 0:
        return None

    # Simple: hold for max_hold_bars, exit at that bar's close
    exit_idx = min(entry_idx + max_hold_bars, len(df_15m) - 1)
    exit_price = df_15m.iloc[exit_idx]['close']
    exit_time = df_15m.index[exit_idx]

    if signal_type == 'buy':
        pnl_pct = (exit_price - entry_price) / entry_price * 100
    else:
        pnl_pct = (entry_price - exit_price) / entry_price * 100

    return {
        'exit_price': exit_price,
        'exit_time': exit_time,
        'pnl_pct': pnl_pct,
        'hold_bars': exit_idx - entry_idx,
    }


def run_test(conn, start_date, end_date, symbols_sample=50):
    """Run the full MR regime lag test."""

    print(f"Loading SPY 15-min data for regime detection...")
    spy_15m = load_15min_data(conn, 'SPY', start_date, end_date)
    if spy_15m.empty:
        print("ERROR: No SPY data")
        return None
    print(f"  SPY: {len(spy_15m)} bars, {spy_15m.index[0]} to {spy_15m.index[-1]}")

    # Compute regime series for each variant
    print("Computing regime series...")
    regime_baseline = compute_regime_series(spy_15m.copy(), adx_trend=25, adx_range=20)
    regime_strict = compute_regime_series(spy_15m.copy(), adx_trend=15, adx_range=15)
    # Lookahead: shift regime forward by 1 bar (oracle)
    regime_oracle = regime_baseline.copy()
    regime_oracle['regime'] = regime_oracle['regime'].shift(-2).fillna('unknown')
    # No gate: everything is 'range' (MR always allowed)
    regime_nogate = regime_baseline.copy()
    regime_nogate['regime'] = 'range'

    variants = {
        'A_baseline': regime_baseline,
        'B_strict': regime_strict,
        'C_oracle': regime_oracle,
        'D_nogate': regime_nogate,
    }

    # Get top symbols by trading volume
    print("Getting symbol universe...")
    cur = conn.cursor()
    cur.execute("""
        SELECT symbol, COUNT(*) as bars
        FROM market_data
        WHERE timeframe = '1min' AND time >= %s AND time < %s::date + interval '1 day'
        GROUP BY symbol
        HAVING COUNT(*) > 1000
        ORDER BY SUM(volume) DESC
        LIMIT %s
    """, (start_date, end_date, symbols_sample))
    top_symbols = [r[0] for r in cur.fetchall()]
    cur.close()
    print(f"  {len(top_symbols)} symbols selected")

    # Generate MR signals for each symbol
    all_signals = []
    for j, sym in enumerate(top_symbols):
        if j % 10 == 0:
            print(f"  Scanning {sym} ({j+1}/{len(top_symbols)})...")
        df_15m = load_15min_data(conn, sym, start_date, end_date)
        if len(df_15m) < BB_PERIOD + RSI_PERIOD + 10:
            continue

        signals = generate_mr_signals(df_15m)
        for s in signals:
            # Simulate trade outcome
            result = simulate_trade(df_15m, s['time'], s['signal'], s['price'])
            if result:
                s['symbol'] = sym
                s['exit_price'] = result['exit_price']
                s['exit_time'] = result['exit_time']
                s['pnl_pct'] = result['pnl_pct']
                s['hold_bars'] = result['hold_bars']
                s['pnl_dollar'] = s['pnl_pct'] / 100 * POSITION_SIZE

                # Get regime at entry and 30 min after for each variant
                for vname, rdf in variants.items():
                    s[f'regime_entry_{vname}'] = get_regime_at(rdf, s['time'])
                    s[f'regime_after_{vname}'] = get_regime_after(rdf, s['time'], 30)

                all_signals.append(s)

    print(f"\nTotal MR signals generated: {len(all_signals)}")
    return all_signals, variants


def analyze_results(all_signals, variants):
    """Analyze results per variant."""
    df = pd.DataFrame(all_signals)
    if df.empty:
        print("No signals to analyze")
        return {}

    results = {}

    for vname in variants:
        regime_col = f'regime_entry_{vname}'
        regime_after_col = f'regime_after_{vname}'

        # Filter: MR is only allowed in 'range' regime
        if vname == 'D_nogate':
            traded = df.copy()  # all signals
        else:
            traded = df[df[regime_col] == 'range'].copy()

        if traded.empty:
            results[vname] = {'trades': 0, 'note': 'no signals in allowed regime'}
            continue

        n = len(traded)
        pnl_total = traded['pnl_dollar'].sum()
        pnl_avg = traded['pnl_dollar'].mean()
        pnl_pct_avg = traded['pnl_pct'].mean()
        winners = traded[traded['pnl_pct'] > 0]
        losers = traded[traded['pnl_pct'] < 0]
        wr = len(winners) / n * 100

        # Regime transition analysis
        regime_changed = traded[traded[regime_col] != traded[regime_after_col]]
        n_changed = len(regime_changed)
        pnl_changed = regime_changed['pnl_dollar'].sum() if n_changed > 0 else 0
        pnl_stable = (traded[traded[regime_col] == traded[regime_after_col]]['pnl_dollar'].sum()
                      if n > n_changed else 0)

        # Long vs short
        buys = traded[traded['signal'] == 'buy']
        sells = traded[traded['signal'] == 'sell']

        # By regime at entry
        regime_breakdown = {}
        for regime in ['range', 'trend', 'crisis', 'unknown']:
            subset = traded[traded[regime_col] == regime]
            if len(subset) > 0:
                regime_breakdown[regime] = {
                    'trades': len(subset),
                    'pnl': round(subset['pnl_dollar'].sum(), 2),
                    'avg_pnl_pct': round(subset['pnl_pct'].mean(), 4),
                    'wr': round(len(subset[subset['pnl_pct'] > 0]) / len(subset) * 100, 1),
                }

        results[vname] = {
            'trades': n,
            'total_pnl': round(pnl_total, 2),
            'avg_pnl': round(pnl_avg, 4),
            'avg_pnl_pct': round(pnl_pct_avg, 4),
            'win_rate': round(wr, 1),
            'avg_win_pct': round(winners['pnl_pct'].mean(), 4) if len(winners) > 0 else 0,
            'avg_loss_pct': round(losers['pnl_pct'].mean(), 4) if len(losers) > 0 else 0,
            'long_trades': len(buys),
            'long_pnl': round(buys['pnl_dollar'].sum(), 2) if len(buys) > 0 else 0,
            'long_wr': round(len(buys[buys['pnl_pct'] > 0]) / max(len(buys), 1) * 100, 1),
            'short_trades': len(sells),
            'short_pnl': round(sells['pnl_dollar'].sum(), 2) if len(sells) > 0 else 0,
            'short_wr': round(len(sells[sells['pnl_pct'] > 0]) / max(len(sells), 1) * 100, 1),
            'regime_transitions': n_changed,
            'pct_transitions': round(n_changed / n * 100, 1),
            'pnl_during_transitions': round(pnl_changed, 2),
            'pnl_stable_regime': round(pnl_stable, 2),
            'regime_breakdown': regime_breakdown,
        }

    return results


def print_results(results):
    """Print formatted comparison table."""
    print("\n" + "=" * 90)
    print("  MR REGIME LAG TEST RESULTS")
    print("=" * 90)

    header = f"{'Variant':<15} {'Trades':>7} {'PnL':>10} {'AvgPnL%':>8} {'WR%':>5} {'LongPnL':>9} {'ShortPnL':>9} {'Transitions':>12} {'TransPnL':>9}"
    print(f"\n{header}")
    print("-" * len(header))

    for vname, r in results.items():
        if r.get('trades', 0) == 0:
            print(f"{vname:<15} {'N/A':>7}")
            continue
        print(f"{vname:<15} {r['trades']:>7} ${r['total_pnl']:>+9.2f} {r['avg_pnl_pct']:>+7.4f}% {r['win_rate']:>5.1f} ${r['long_pnl']:>+8.2f} ${r['short_pnl']:>+8.2f} {r['regime_transitions']:>5}/{r['trades']}({r['pct_transitions']:.0f}%) ${r['pnl_during_transitions']:>+8.2f}")

    # Detailed per-variant
    for vname, r in results.items():
        if r.get('trades', 0) == 0:
            continue
        print(f"\n--- {vname} ---")
        print(f"  Trades: {r['trades']} (Long: {r['long_trades']}, Short: {r['short_trades']})")
        print(f"  Total PnL: ${r['total_pnl']:+.2f}, Avg PnL%: {r['avg_pnl_pct']:+.4f}%")
        print(f"  Win Rate: {r['win_rate']:.1f}%, Avg Win: {r['avg_win_pct']:+.4f}%, Avg Loss: {r['avg_loss_pct']:+.4f}%")
        print(f"  Long:  {r['long_trades']} trades, PnL=${r['long_pnl']:+.2f}, WR={r['long_wr']:.1f}%")
        print(f"  Short: {r['short_trades']} trades, PnL=${r['short_pnl']:+.2f}, WR={r['short_wr']:.1f}%")
        print(f"  Regime transitions within 30 min: {r['regime_transitions']}/{r['trades']} ({r['pct_transitions']:.1f}%)")
        print(f"    PnL during transitions: ${r['pnl_during_transitions']:+.2f}")
        print(f"    PnL during stable regime: ${r['pnl_stable_regime']:+.2f}")

        if r.get('regime_breakdown'):
            print(f"  By regime at entry:")
            for regime, data in r['regime_breakdown'].items():
                print(f"    {regime:<10}: {data['trades']:>4} trades, PnL=${data['pnl']:>+8.2f}, "
                      f"AvgPnL%={data['avg_pnl_pct']:>+.4f}%, WR={data['wr']:.1f}%")


if __name__ == '__main__':
    conn = psycopg2.connect(**DB_CONFIG)

    # Run on recent data first (faster) then scale up
    # Phase 1: Recent period (2026-03-01 to 2026-03-20) - quick validation
    # Phase 2: Full period (2023-07-01 to 2026-03-20) - production analysis
    START = '2025-06-01'  # 9 months: good balance of speed vs coverage
    END = '2026-03-20'

    print(f"MR REGIME LAG TEST: {START} to {END}")
    print(f"Symbols: top 50 by volume\n")

    all_signals, variants = run_test(conn, START, END, symbols_sample=50)
    conn.close()

    if all_signals:
        results = analyze_results(all_signals, variants)
        print_results(results)

        # Save
        out_dir = os.path.dirname(os.path.abspath(__file__))
        with open(os.path.join(out_dir, 'mr_regime_lag_results.json'), 'w') as f:
            json.dump(results, f, indent=2, default=str)
        print(f"\nSaved to {out_dir}/mr_regime_lag_results.json")
    else:
        print("ERROR: No signals generated")
