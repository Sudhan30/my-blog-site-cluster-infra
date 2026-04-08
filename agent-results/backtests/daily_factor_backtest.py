#!/usr/bin/env python3
"""
Standalone DailyFactor Backtest — Optimized Version

Loads all daily bars upfront (aggregated from 1-min in monthly chunks),
then simulates daily factor rebalancing: long top 5 / short bottom 5.
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

NUM_LONG = 5
NUM_SHORT = 5
POSITION_SIZE_PCT = 3.0
INITIAL_CASH = 30000.0
COMMISSION_PER_SHARE = 0.005
MIN_PRICE = 5.0
MIN_BARS = 30


def zscore(series):
    std = series.std()
    if std < 1e-10:
        return pd.Series(0.0, index=series.index)
    return (series - series.mean()) / std


def load_daily_bars(conn, start_date, end_date):
    """Load ALL daily bars by aggregating 1-min data in monthly chunks."""
    # Need lookback before start_date for indicators
    lookback_start = (datetime.strptime(start_date, '%Y-%m-%d') - timedelta(days=60)).strftime('%Y-%m-%d')

    all_rows = []
    cur = conn.cursor()

    # Generate monthly chunks
    from dateutil.relativedelta import relativedelta
    chunk_start = datetime.strptime(lookback_start, '%Y-%m-%d')
    final_end = datetime.strptime(end_date, '%Y-%m-%d')

    while chunk_start < final_end:
        chunk_end = min(chunk_start + relativedelta(months=1), final_end + timedelta(days=1))
        print(f"  Loading {chunk_start.strftime('%Y-%m-%d')} to {chunk_end.strftime('%Y-%m-%d')}...", end=" ", flush=True)

        cur.execute("""
            SELECT
                symbol,
                DATE(time AT TIME ZONE 'America/New_York') as trade_date,
                (array_agg(open ORDER BY time))[1] as open,
                MAX(high) as high,
                MIN(low) as low,
                (array_agg(close ORDER BY time DESC))[1] as close,
                SUM(volume) as volume
            FROM market_data
            WHERE timeframe = '1min'
              AND time >= %s AND time < %s
            GROUP BY symbol, DATE(time AT TIME ZONE 'America/New_York')
        """, (chunk_start, chunk_end))

        rows = cur.fetchall()
        print(f"{len(rows)} rows")
        all_rows.extend(rows)
        chunk_start = chunk_end

    cur.close()

    if not all_rows:
        return {}, []

    df = pd.DataFrame(all_rows, columns=['symbol', 'date', 'open', 'high', 'low', 'close', 'volume'])
    for col in ['open', 'high', 'low', 'close']:
        df[col] = df[col].astype(float)
    df['volume'] = df['volume'].astype(float)

    # Build per-symbol DataFrames
    daily_data = {}
    for sym, grp in df.groupby('symbol'):
        grp = grp.set_index('date').sort_index()
        daily_data[sym] = grp[['open', 'high', 'low', 'close', 'volume']]

    # Trading days (from SPY or most common)
    trading_days = sorted(df[df['date'] >= datetime.strptime(start_date, '%Y-%m-%d').date()]['date'].unique())

    print(f"\nLoaded {len(daily_data)} symbols, {len(trading_days)} trading days")
    return daily_data, trading_days


def compute_factors(daily_data, as_of_date):
    """Compute factor scores for all symbols as of a given date."""
    records = []

    for sym, df in daily_data.items():
        # Filter to data up to as_of_date
        mask = df.index <= as_of_date
        dfs = df[mask]
        if len(dfs) < MIN_BARS:
            continue

        close = dfs['close']
        volume = dfs['volume']

        momentum = close.pct_change(20).iloc[-1]
        delta = close.diff()
        gain = delta.where(delta > 0, 0.0).rolling(14).mean()
        loss = (-delta.where(delta < 0, 0.0)).rolling(14).mean()
        rs = gain / loss.replace(0, np.nan)
        rsi = (100 - (100 / (1 + rs))).iloc[-1]
        vol_avg = volume.rolling(20).mean().iloc[-1]
        vol_ratio = volume.iloc[-1] / vol_avg if vol_avg > 0 else 1.0
        returns = close.pct_change()
        volatility = returns.rolling(20).std().iloc[-1]
        price = close.iloc[-1]

        if any(np.isnan(v) for v in [momentum, rsi, vol_ratio, volatility, price]):
            continue
        if price < MIN_PRICE:
            continue

        records.append({
            'symbol': sym, 'momentum': momentum, 'rsi': rsi,
            'volume_ratio': vol_ratio, 'volatility': volatility, 'price': price,
        })

    if not records:
        return pd.DataFrame()
    return pd.DataFrame(records).set_index('symbol')


def rank_and_select(factors_df):
    if len(factors_df) < NUM_LONG + NUM_SHORT:
        return [], []

    df = factors_df.copy()
    df['z_momentum'] = zscore(df['momentum'])
    df['z_mean_reversion'] = -zscore(df['rsi'])
    df['z_volume'] = zscore(df['volume_ratio'])
    df['z_volatility'] = -zscore(df['volatility'])

    total_w = 0.30 + 0.20 + 0.20 + 0.15
    df['composite'] = (
        (0.30 / total_w) * df['z_momentum']
        + (0.20 / total_w) * df['z_mean_reversion']
        + (0.20 / total_w) * df['z_volume']
        + (0.15 / total_w) * df['z_volatility']
    )
    df = df.sort_values('composite', ascending=False)

    return list(df.head(NUM_LONG).index), list(df.tail(NUM_SHORT).index)


def run_backtest(start_date='2025-01-01', end_date='2026-03-20'):
    conn = psycopg2.connect(**DB_CONFIG)
    print(f"Loading daily bars from {start_date} to {end_date}...")

    try:
        daily_data, trading_days = load_daily_bars(conn, start_date, end_date)
    except Exception as e:
        print(f"ERROR loading data: {e}")
        conn.close()
        return None
    conn.close()

    if not trading_days:
        print("No trading days found")
        return None

    cash = INITIAL_CASH
    positions = {}
    trades = []
    daily_values = []

    for i, today in enumerate(trading_days):
        factors = compute_factors(daily_data, today)
        if factors.empty:
            continue

        longs, shorts = rank_and_select(factors)
        if not longs and not shorts:
            continue

        # Get today's prices
        prices = {}
        for sym in set(list(positions.keys()) + longs + shorts):
            if sym in daily_data and today in daily_data[sym].index:
                prices[sym] = daily_data[sym].loc[today, 'close']

        # Close positions not in today's selection
        for sym in list(positions.keys()):
            pos = positions[sym]
            keep = (pos['side'] == 'long' and sym in longs) or (pos['side'] == 'short' and sym in shorts)
            if keep:
                continue

            exit_price = prices.get(sym, pos['entry_price'])
            if pos['side'] == 'long':
                pnl = (exit_price - pos['entry_price']) * pos['qty']
            else:
                pnl = (pos['entry_price'] - exit_price) * pos['qty']

            commission = abs(pos['qty']) * COMMISSION_PER_SHARE * 2
            pnl -= commission

            if pos['side'] == 'long':
                cash += exit_price * pos['qty']
            else:
                # Return short margin + pnl
                cash += pos['entry_price'] * pos['qty'] + pnl

            pnl_pct = pnl / (pos['entry_price'] * pos['qty']) * 100 if pos['entry_price'] * pos['qty'] > 0 else 0
            trades.append({
                'symbol': sym, 'side': pos['side'],
                'entry_price': pos['entry_price'], 'exit_price': exit_price,
                'qty': pos['qty'], 'pnl': pnl, 'pnl_pct': pnl_pct,
                'entry_date': pos['entry_date'], 'exit_date': today,
                'hold_days': (today - pos['entry_date']).days,
            })
            del positions[sym]

        # Portfolio value for sizing
        pv = cash
        for sym, pos in positions.items():
            cp = prices.get(sym, pos['entry_price'])
            if pos['side'] == 'long':
                pv += cp * pos['qty']
            else:
                pv += (2 * pos['entry_price'] - cp) * pos['qty']

        target_val = pv * (POSITION_SIZE_PCT / 100.0)

        # Open new longs
        for sym in longs:
            if sym in positions or sym not in prices:
                continue
            price = prices[sym]
            qty = int(target_val / price)
            if qty <= 0 or qty * price > cash:
                continue
            cash -= qty * price
            positions[sym] = {'qty': qty, 'entry_price': price, 'side': 'long', 'entry_date': today}

        # Open new shorts
        for sym in shorts:
            if sym in positions or sym not in prices:
                continue
            price = prices[sym]
            qty = int(target_val / price)
            if qty <= 0:
                continue
            # Simplified: short margin = position value, received proceeds credited
            cash -= qty * price  # margin requirement
            positions[sym] = {'qty': qty, 'entry_price': price, 'side': 'short', 'entry_date': today}

        # EOD value
        eod = cash
        for sym, pos in positions.items():
            cp = prices.get(sym, pos['entry_price'])
            if pos['side'] == 'long':
                eod += cp * pos['qty']
            else:
                eod += (2 * pos['entry_price'] - cp) * pos['qty']

        daily_values.append({'date': today, 'value': eod, 'cash': cash,
                            'n_positions': len(positions)})

        if i % 20 == 0 or i == len(trading_days) - 1:
            pnl_so_far = sum(t['pnl'] for t in trades)
            print(f"  [{i+1}/{len(trading_days)}] {today}: ${eod:,.2f} "
                  f"({len(positions)} pos, {len(trades)} closed, realized=${pnl_so_far:+,.2f})")

    # Close remaining positions
    for sym, pos in list(positions.items()):
        last_day = trading_days[-1]
        exit_price = daily_data[sym].loc[last_day, 'close'] if sym in daily_data and last_day in daily_data[sym].index else pos['entry_price']
        if pos['side'] == 'long':
            pnl = (exit_price - pos['entry_price']) * pos['qty']
        else:
            pnl = (pos['entry_price'] - exit_price) * pos['qty']
        commission = abs(pos['qty']) * COMMISSION_PER_SHARE * 2
        pnl -= commission
        pnl_pct = pnl / (pos['entry_price'] * pos['qty']) * 100 if pos['entry_price'] * pos['qty'] > 0 else 0
        trades.append({
            'symbol': sym, 'side': pos['side'],
            'entry_price': pos['entry_price'], 'exit_price': exit_price,
            'qty': pos['qty'], 'pnl': pnl, 'pnl_pct': pnl_pct,
            'entry_date': pos['entry_date'], 'exit_date': last_day,
            'hold_days': (last_day - pos['entry_date']).days,
        })

    return generate_report(trades, daily_values, start_date, end_date)


def generate_report(trades, daily_values, start_date, end_date):
    if not trades:
        return {'error': 'No trades'}

    df_t = pd.DataFrame(trades)
    df_d = pd.DataFrame(daily_values)

    total_pnl = df_t['pnl'].sum()
    winners = df_t[df_t['pnl'] > 0]
    losers = df_t[df_t['pnl'] < 0]
    win_rate = len(winners) / len(df_t) * 100
    avg_win = winners['pnl'].mean() if len(winners) > 0 else 0
    avg_loss = losers['pnl'].mean() if len(losers) > 0 else 0
    pf = abs(winners['pnl'].sum() / losers['pnl'].sum()) if len(losers) > 0 and losers['pnl'].sum() != 0 else float('inf')

    final_val = df_d['value'].iloc[-1] if len(df_d) > 0 else INITIAL_CASH
    total_ret = (final_val - INITIAL_CASH) / INITIAL_CASH * 100
    n_days = (df_d['date'].iloc[-1] - df_d['date'].iloc[0]).days if len(df_d) > 1 else 1
    years = n_days / 365.25
    ann_ret = ((final_val / INITIAL_CASH) ** (1 / years) - 1) * 100 if years > 0 else 0

    if len(df_d) > 1:
        df_d['ret'] = df_d['value'].pct_change()
        sharpe = (df_d['ret'].mean() / df_d['ret'].std()) * np.sqrt(252) if df_d['ret'].std() > 0 else 0
        cummax = df_d['value'].cummax()
        max_dd = ((df_d['value'] - cummax) / cummax).min() * 100
    else:
        sharpe = 0; max_dd = 0

    longs = df_t[df_t['side'] == 'long']
    shorts = df_t[df_t['side'] == 'short']

    sym_pnl = df_t.groupby('symbol')['pnl'].sum().sort_values(ascending=False)
    df_t['exit_month'] = pd.to_datetime(df_t['exit_date']).dt.to_period('M')
    monthly = df_t.groupby('exit_month').agg(trades=('pnl','count'), pnl=('pnl','sum'),
                                              win_rate=('pnl', lambda x: (x>0).mean()*100)).reset_index()

    report = {
        'period': f'{start_date} to {end_date}',
        'trading_days': len(df_d),
        'initial_capital': INITIAL_CASH,
        'final_value': round(final_val, 2),
        'total_pnl': round(total_pnl, 2),
        'total_return_pct': round(total_ret, 2),
        'annualized_return_pct': round(ann_ret, 2),
        'sharpe_ratio': round(sharpe, 3),
        'max_drawdown_pct': round(max_dd, 2),
        'total_trades': len(df_t),
        'win_rate_pct': round(win_rate, 1),
        'avg_win': round(avg_win, 2),
        'avg_loss': round(avg_loss, 2),
        'profit_factor': round(pf, 3),
        'avg_hold_days': round(df_t['hold_days'].mean(), 1),
        'long_trades': len(longs),
        'long_pnl': round(longs['pnl'].sum(), 2),
        'long_wr': round(len(longs[longs['pnl']>0])/max(len(longs),1)*100, 1),
        'short_trades': len(shorts),
        'short_pnl': round(shorts['pnl'].sum(), 2),
        'short_wr': round(len(shorts[shorts['pnl']>0])/max(len(shorts),1)*100, 1),
        'unique_symbols': df_t['symbol'].nunique(),
        'top_5': {str(s): round(float(p),2) for s,p in sym_pnl.head(5).items()},
        'bottom_5': {str(s): round(float(p),2) for s,p in sym_pnl.tail(5).items()},
        'monthly': [{'month': str(r['exit_month']), 'trades': int(r['trades']),
                     'pnl': round(float(r['pnl']),2), 'wr': round(float(r['win_rate']),1)}
                    for _, r in monthly.iterrows()],
    }
    return report


def print_report(r):
    print("\n" + "=" * 70)
    print("  DAILYFACTOR STRATEGY BACKTEST RESULTS")
    print("=" * 70)
    for k in ['period','trading_days','initial_capital','final_value','total_pnl',
              'total_return_pct','annualized_return_pct','sharpe_ratio','max_drawdown_pct',
              'total_trades','win_rate_pct','avg_win','avg_loss','profit_factor','avg_hold_days']:
        v = r[k]
        label = k.replace('_',' ').title()
        if isinstance(v, float):
            if 'pct' in k or 'return' in k or 'drawdown' in k:
                print(f"  {label:<25} {v:+.2f}%")
            elif 'ratio' in k or 'factor' in k:
                print(f"  {label:<25} {v:.3f}")
            else:
                print(f"  {label:<25} ${v:+,.2f}")
        else:
            print(f"  {label:<25} {v}")

    print(f"\n  LONG:  {r['long_trades']} trades, PnL=${r['long_pnl']:+,.2f}, WR={r['long_wr']:.1f}%")
    print(f"  SHORT: {r['short_trades']} trades, PnL=${r['short_pnl']:+,.2f}, WR={r['short_wr']:.1f}%")
    print(f"\n  Top 5:    {r['top_5']}")
    print(f"  Bottom 5: {r['bottom_5']}")
    print(f"\n  Monthly:")
    print(f"  {'Month':<10} {'Trades':>7} {'PnL':>10} {'WR%':>6}")
    print(f"  {'-'*37}")
    for m in r.get('monthly', []):
        print(f"  {m['month']:<10} {m['trades']:>7} ${m['pnl']:>+9.2f} {m['wr']:>5.1f}%")
    print("=" * 70)


if __name__ == '__main__':
    report = run_backtest('2025-01-01', '2026-03-20')
    if report:
        print_report(report)
        out = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'daily_factor_results.json')
        with open(out, 'w') as f:
            json.dump(report, f, indent=2, default=str)
        print(f"\nSaved to {out}")
