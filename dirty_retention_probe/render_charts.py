#!/usr/bin/env python3
"""Render SVG charts from dirty_retention_probe CSV output."""

from __future__ import annotations

import csv
import sys
from pathlib import Path


SAMPLE_CSV = """scenario,n,depth,fan_in,rss_before_kb,rss_after_build_kb,rss_delta_kb,first_dirty_us,steady_total_us,steady_iterations,steady_avg_ns,checksum
baseline_ephemeral,1000,1,1,4672,4672,0,2105,0,200,0,500500
baseline_ephemeral,2500,1,1,4672,4672,0,5251,0,200,0,3126250
baseline_ephemeral,5000,1,1,4672,4816,144,10613,0,200,0,12502500
baseline_ephemeral,10000,1,1,4768,4768,0,20775,0,200,0,50005000
baseline_ephemeral,20000,1,1,4768,4816,48,41628,0,200,0,200010000
baseline_ephemeral,40000,1,1,4768,4960,192,83882,0,200,0,800020000
map_fanout,1000,1,1,4960,4912,-48,85,14823,200,74115,720410
map_fanout,2500,1,1,4944,5088,144,263,38550,200,192750,3346160
map_fanout,5000,1,1,5312,5552,240,414,74521,200,372605,12722410
map_fanout,10000,1,1,6096,6368,272,788,148120,200,740600,50224910
map_fanout,20000,1,1,8128,9104,976,1616,300249,200,1501245,200229910
map_fanout,40000,1,1,13440,13792,352,3377,625716,200,3128580,800239910
chain_depth4,1000,4,1,18000,18000,0,275,15185,200,75925,723410
chain_depth4,2500,4,1,16976,16992,16,687,39213,200,196065,3353660
chain_depth4,5000,4,1,14944,14944,0,1428,79535,200,397675,12737410
chain_depth4,10000,4,1,14640,14496,-144,3961,157105,200,785525,50254910
chain_depth4,20000,4,1,14320,17808,3488,6464,352286,200,1761430,200289910
chain_depth4,40000,4,1,16272,28224,11952,17196,767145,200,3835725,800359910
map12,1000,1,12,18992,19088,96,82,14613,200,73065,797410
map12,2500,1,12,19088,19232,144,205,37091,200,185455,3538660
map12,5000,1,12,18208,18384,176,387,74752,200,373760,13107410
map12,10000,1,12,14288,15888,1600,860,146528,200,732640,50994910
map12,20000,1,12,15888,17648,1760,1884,293912,200,1469560,201769910
map12,40000,1,12,19664,25280,5616,3240,617630,200,3088150,803319910
zip12,1000,2,12,29344,29344,0,137,13697,200,68485,797410
zip12,2500,2,12,29344,28320,-1024,373,38440,200,192200,3538660
zip12,5000,2,12,26272,24416,-1856,870,77119,200,385595,13107410
zip12,10000,2,12,23392,22496,-896,1462,153049,200,765245,50994910
zip12,20000,2,12,23504,29472,5968,3012,308231,200,1541155,201769910
zip12,40000,2,12,30496,38640,8144,6972,676413,200,3382065,803319910
bind_branch,1000,1,2,40240,40240,0,83,14784,200,73920,1100
bind_branch,2500,1,2,40240,39216,-1024,198,37734,200,188670,2600
bind_branch,5000,1,2,39216,38192,-1024,378,73974,200,369870,5100
bind_branch,10000,1,2,38192,30880,-7312,870,147276,200,736380,10100
bind_branch,20000,1,2,30880,29872,-1008,1550,297874,200,1489370,20100
bind_branch,40000,1,2,29872,30960,1088,3111,622712,200,3113560,40100
bind_live_root_subgraph,1000,2,1,34032,31984,-2048,171,17534,200,87670,1844820
bind_live_root_subgraph,2500,2,1,30960,28912,-2048,381,41000,200,205000,7702320
bind_live_root_subgraph,5000,2,1,28912,27888,-1024,787,79758,200,398790,27464820
bind_live_root_subgraph,10000,2,1,27888,26800,-1088,1957,155461,200,777305,104489820
bind_live_root_subgraph,20000,2,1,27536,29072,1536,3491,322672,200,1613360,408539820
bind_live_root_subgraph,40000,2,1,29648,34960,5312,7444,704471,200,3522355,1616639820
bind_live_local_subgraph,1000,2,0,30896,30896,0,6,1190,200,5950,1845204
bind_live_local_subgraph,2500,2,0,30896,30896,0,6,1193,200,5965,7702704
bind_live_local_subgraph,5000,2,0,29872,29872,0,6,1240,200,6200,27465204
bind_live_local_subgraph,10000,2,0,29872,28848,-1024,6,1166,200,5830,104490204
bind_live_local_subgraph,20000,2,0,28848,27824,-1024,6,1225,200,6125,408540204
bind_live_local_subgraph,40000,2,0,27824,27856,32,6,1204,200,6020,1616640204
interleaved_map_batch,20000,1,1,27872,28496,624,40860,0,200,0,10181210
"""

PALETTE = {
    "map_fanout": "#2563eb",
    "chain_depth4": "#7c3aed",
    "map12": "#059669",
    "zip12": "#0891b2",
    "bind_branch": "#d97706",
    "bind_live_root_subgraph": "#db2777",
    "bind_live_local_subgraph": "#111827",
    "baseline_ephemeral": "#64748b",
}

W, H = 1080, 520
L, R, T, B = 84, 340, 54, 80
PLOT_W, PLOT_H = W - L - R, H - T - B


def read_rows() -> list[dict[str, str]]:
    text = sys.stdin.read()
    if not text.strip():
        text = SAMPLE_CSV
    return list(csv.DictReader(text.splitlines()))


def fmt_number(value: float) -> str:
    if abs(value) >= 1_000_000:
        return f"{value / 1_000_000:.1f}M"
    if abs(value) >= 1_000:
        return f"{value / 1_000:.0f}k"
    return str(int(value))


def scale(value: float, lo: float, hi: float, start: float, stop: float) -> float:
    if hi == lo:
        return (start + stop) / 2
    return start + (value - lo) * (stop - start) / (hi - lo)


def render_line_chart(
    out_dir: Path,
    filename: str,
    title: str,
    y_label: str,
    rows: list[dict[str, str]],
    scenarios: list[str],
    value_column: str,
    y_min: float | None = None,
    y_max: float | None = None,
    note: str | None = None,
) -> None:
    data = {
        scenario: [
            (int(row["n"]), float(row[value_column]))
            for row in rows
            if row["scenario"] == scenario
        ]
        for scenario in scenarios
    }
    xs = sorted({x for points in data.values() for x, _ in points})
    values = [y for points in data.values() for _, y in points]
    lo = min(values) if y_min is None else y_min
    hi = max(values) if y_max is None else y_max
    pad = (hi - lo) * 0.08 if hi != lo else 1
    lo -= pad
    hi += pad
    if y_min is not None:
        lo = y_min
    if y_max is not None:
        hi = y_max

    def x_pos(x: float) -> float:
        return scale(x, min(xs), max(xs), L, L + PLOT_W)

    def y_pos(y: float) -> float:
        return scale(y, lo, hi, T + PLOT_H, T)

    parts = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" '
        f'viewBox="0 0 {W} {H}" role="img" aria-labelledby="title desc">',
        f'<title id="title">{title}</title>',
        f'<desc id="desc">Line chart for {title}</desc>',
        '<rect width="100%" height="100%" fill="#ffffff"/>',
        f'<text x="{L}" y="30" font-family="Arial, sans-serif" font-size="20" '
        f'font-weight="700" fill="#111827">{title}</text>',
        f'<text x="{L}" y="50" font-family="Arial, sans-serif" font-size="12" '
        'fill="#475569">Native probe sample, lower is better</text>',
    ]

    for tick in [lo + (hi - lo) * i / 5 for i in range(6)]:
        y = y_pos(tick)
        parts.append(
            f'<line x1="{L}" y1="{y:.1f}" x2="{L + PLOT_W}" y2="{y:.1f}" '
            'stroke="#e5e7eb" stroke-width="1"/>'
        )
        parts.append(
            f'<text x="{L - 10}" y="{y + 4:.1f}" text-anchor="end" '
            'font-family="Arial, sans-serif" font-size="11" '
            f'fill="#64748b">{fmt_number(tick)}</text>'
        )

    for tick in xs:
        x = x_pos(tick)
        parts.append(
            f'<line x1="{x:.1f}" y1="{T + PLOT_H}" x2="{x:.1f}" '
            f'y2="{T + PLOT_H + 5}" stroke="#94a3b8" stroke-width="1"/>'
        )
        parts.append(
            f'<text x="{x:.1f}" y="{T + PLOT_H + 24}" text-anchor="middle" '
            f'font-family="Arial, sans-serif" font-size="12" '
            f'fill="#475569">{fmt_number(tick)}</text>'
        )

    if lo < 0 < hi:
        zero = y_pos(0)
        parts.append(
            f'<line x1="{L}" y1="{zero:.1f}" x2="{L + PLOT_W}" '
            f'y2="{zero:.1f}" stroke="#334155" stroke-width="1.2" '
            'stroke-dasharray="4 4"/>'
        )

    parts.append(
        f'<line x1="{L}" y1="{T}" x2="{L}" y2="{T + PLOT_H}" '
        'stroke="#334155" stroke-width="1.2"/>'
    )
    parts.append(
        f'<line x1="{L}" y1="{T + PLOT_H}" x2="{L + PLOT_W}" '
        f'y2="{T + PLOT_H}" stroke="#334155" stroke-width="1.2"/>'
    )
    parts.append(
        f'<text x="{L + PLOT_W / 2:.1f}" y="{H - 24}" text-anchor="middle" '
        'font-family="Arial, sans-serif" font-size="13" '
        'fill="#334155">dropped derived graphs (n)</text>'
    )
    parts.append(
        f'<text transform="translate(22 {T + PLOT_H / 2:.1f}) rotate(-90)" '
        'text-anchor="middle" font-family="Arial, sans-serif" font-size="13" '
        f'fill="#334155">{y_label}</text>'
    )

    legend_x = L + PLOT_W + 34
    legend_y = T + 18
    for index, scenario in enumerate(scenarios):
        points = data[scenario]
        coords = [(x_pos(x), y_pos(y)) for x, y in points]
        path = " ".join(
            ("M" if i == 0 else "L") + f"{x:.1f},{y:.1f}"
            for i, (x, y) in enumerate(coords)
        )
        color = PALETTE[scenario]
        parts.append(
            f'<path d="{path}" fill="none" stroke="{color}" stroke-width="2.6" '
            'stroke-linecap="round" stroke-linejoin="round"/>'
        )
        for x, y in coords:
            parts.append(
                f'<circle cx="{x:.1f}" cy="{y:.1f}" r="4" fill="#ffffff" '
                f'stroke="{color}" stroke-width="2"/>'
            )
        y = legend_y + index * 24
        parts.append(
            f'<line x1="{legend_x}" y1="{y}" x2="{legend_x + 22}" y2="{y}" '
            f'stroke="{color}" stroke-width="3"/>'
        )
        parts.append(
            f'<text x="{legend_x + 30}" y="{y + 4}" '
            f'font-family="Arial, sans-serif" font-size="12" '
            f'fill="#334155">{scenario}</text>'
        )

    if note:
        parts.append(
            f'<text x="{L}" y="{H - 8}" font-family="Arial, sans-serif" '
            f'font-size="11" fill="#64748b">{note}</text>'
        )
    parts.append("</svg>")
    (out_dir / filename).write_text("\n".join(parts) + "\n")


def main() -> None:
    out_dir = Path(__file__).resolve().parent / "charts"
    out_dir.mkdir(parents=True, exist_ok=True)
    rows = read_rows()
    main_scenarios = [
        "map_fanout",
        "chain_depth4",
        "map12",
        "zip12",
        "bind_branch",
        "bind_live_root_subgraph",
        "bind_live_local_subgraph",
    ]

    render_line_chart(
        out_dir,
        "steady-update-cost.svg",
        "Steady update cost grows linearly",
        "steady avg ns / update",
        rows,
        main_scenarios,
        "steady_avg_ns",
        y_min=0,
        note="External-root cases grow to ~3.1-3.8 ms/update at 40k; local-only bind stays near 6 us/update.",
    )
    render_line_chart(
        out_dir,
        "first-dirty-cost.svg",
        "First dirty propagation pays for depth",
        "first dirty us",
        rows,
        main_scenarios,
        "first_dirty_us",
        y_min=0,
        note="chain_depth4 and zip12 pay more on the first dirty because retained clean dirty chains are traversed once.",
    )
    render_line_chart(
        out_dir,
        "rss-after-build.svg",
        "RSS after build by sample size",
        "RSS after build KiB",
        rows,
        main_scenarios,
        "rss_after_build_kb",
        note="Compare trends within each scenario; absolute RSS includes runtime and allocator state.",
    )


if __name__ == "__main__":
    main()
