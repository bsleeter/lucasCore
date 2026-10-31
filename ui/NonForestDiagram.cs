// =============================================================================
// NonForestDiagram.cs - draws a NonForestBudget: pools as boxes (live, fast dead, slow; above and below the soil surface), flows as
// curves whose width is the steady-state flux, labelled with the rate as entered or the flux
// =============================================================================
// Net growth enters the live pools from the left, labelled with its share. Each box gives the pool's steady-state stock and turnover
// time (and, for emergent wetlands, its total loss rate). What a pool releases leaves it as an arrow: curving up from its top right
// corner to the atmosphere, out of its right side to water; there are no atmosphere or water boxes. A value set by this scenario's
// rows is drawn bold. Hovering a curve or arrow shows its rate, stock and flux.
// =============================================================================
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Globalization;
using System.Linq;
using System.Windows.Forms;

namespace lucasCoreUI
{
    internal class NonForestDiagram : Control
    {
        public NonForestBudget Budget;
        public bool ShowFlux, HideEmpty = true;

        private const int GAP = 34, TOP = 60, BH = 54;   // the gaps leave room for the arrows up to the atmosphere
        private static readonly int[][] Cols = { new[] { 60, 160 }, new[] { 330, 170 }, new[] { 590, 160 } };   // room on the right for arrows to water
        private readonly ToolTip m_tip = new ToolTip { InitialDelay = 100, ReshowDelay = 50 };
        private readonly List<KeyValuePair<PointF[], NonForestBudget.Edge>> m_hits = new List<KeyValuePair<PointF[], NonForestBudget.Edge>>();
        private string m_tipText = "";

        private static readonly Color LiveFill = Color.FromArgb(234, 243, 222), LiveLine = Color.FromArgb(99, 153, 34), LiveText = Color.FromArgb(39, 80, 10);
        private static readonly Color DeadFill = Color.FromArgb(250, 238, 218), DeadLine = Color.FromArgb(186, 117, 23), DeadText = Color.FromArgb(99, 56, 6);
        private static readonly Color SlowFill = Color.FromArgb(241, 239, 232), SlowLine = Color.FromArgb(136, 135, 128), SlowText = Color.FromArgb(68, 68, 65);

        public NonForestDiagram()
        {
            SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.UserPaint | ControlStyles.ResizeRedraw, true);
            BackColor = SystemColors.Window; Height = 520;
        }

        public static string Num(double x) { return (x >= 10 ? x.ToString("0.0", CultureInfo.InvariantCulture) : x >= 1 ? x.ToString("0.00", CultureInfo.InvariantCulture) : x.ToString("0.000", CultureInfo.InvariantCulture)); }
        private static string RateText(double x) { return x.ToString(x < 0.01 ? "0.0000" : "0.000", CultureInfo.InvariantCulture); }

        private bool Visible_(NonForestBudget.Pool p) { return !HideEmpty || p.Stock > 1e-6 || p.In > 1e-6; }

        // box positions: each column stacks its above-ground pools, then the soil surface, then the below-ground ones
        private Dictionary<string, RectangleF> Arrange(out float ground, out float bottom)
        {
            var pos = new Dictionary<string, RectangleF>(); float scale = Math.Max(0.6f, Math.Min(1.4f, (Width - 20) / 830f));
            float maxAg = TOP; var vis = Budget.P.Values.Where(Visible_).ToList();
            for (int c = 0; c < 3; c++)
            {
                float y = TOP; foreach (var p in vis.Where(q => q.Col == c && q.Above)) { pos[p.Key] = new RectangleF(Cols[c][0] * scale, y, Cols[c][1] * scale, BH); y += BH + GAP; }
                maxAg = Math.Max(maxAg, y);
            }
            ground = maxAg + 6; bottom = ground;
            for (int c = 0; c < 3; c++)
            {
                float y = ground + 40; foreach (var p in vis.Where(q => q.Col == c && !q.Above)) { pos[p.Key] = new RectangleF(Cols[c][0] * scale, y, Cols[c][1] * scale, BH); y += BH + GAP; }
                bottom = Math.Max(bottom, y);
            }
            return pos;
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            base.OnPaint(e);
            Graphics g = e.Graphics; g.SmoothingMode = SmoothingMode.AntiAlias; g.TextRenderingHint = System.Drawing.Text.TextRenderingHint.ClearTypeGridFit;
            m_hits.Clear();
            if (Budget == null) { TextRenderer.DrawText(g, "No values for this class in this ecodivision.", Font, new Point(10, 10), SystemColors.GrayText); return; }
            float ground, bottom; Dictionary<string, RectangleF> pos = Arrange(out ground, out bottom);
            int h = (int)bottom + 16;   // the page's table row takes its height from the minimum size, as the grid hosts do
            if (Height != h) { MinimumSize = new Size(200, h); Height = h; }
            using (var small = new Font(Font.FontFamily, Font.Size - 0.5f))
            using (var bold = new Font(Font, FontStyle.Bold))
            using (var grey = new SolidBrush(SystemColors.GrayText))
            {
                using (var dash = new Pen(SystemColors.GrayText, 1) { DashStyle = DashStyle.Dash }) g.DrawLine(dash, 4, ground, Width - 6, ground);
                g.DrawString("soil surface", small, grey, Width - 8 - g.MeasureString("soil surface", small).Width, ground - 16);
                string[] heads = { "Live", "Dead, fast", "Slow" };
                float scale = Math.Max(0.6f, Math.Min(1.4f, (Width - 20) / 830f));
                for (int c = 0; c < 3; c++) g.DrawString(heads[c], small, grey, Cols[c][0] * scale, 10);

                double maxF = Budget.Edges.Select(x => x.Flux).DefaultIfEmpty(0).Max();
                var labels = new List<Tuple<PointF, string, bool, Color, bool>>();   // where, text, the page's value, colour, centred
                foreach (var ed in Budget.Edges.Where(x => x.To != "ATM" && x.To != "AQ" && x.Flux > 1e-9 && pos.ContainsKey(x.To)))
                {
                    RectangleF t = pos[ed.To]; PointF a, b, c1, c2; Color col; bool same = false;
                    if (ed.Kind == "Net growth") { a = new PointF(4, t.Y + BH / 2f); col = LiveLine; }
                    else
                    {
                        if (!pos.ContainsKey(ed.From)) continue;
                        RectangleF s = pos[ed.From]; col = Budget.P[ed.From].Col == 0 ? LiveLine : DeadLine;
                        same = Budget.P[ed.From].Col == Budget.P[ed.To].Col;
                        a = new PointF(s.Right, s.Y + BH / 2f);
                    }
                    b = same ? new PointF(t.Right + 2, t.Y + BH / 2f) : new PointF(t.X - 2, t.Y + BH / 2f);
                    float bx = same ? a.X + 34 : (a.X + b.X) / 2; c1 = new PointF(bx, a.Y); c2 = new PointF(bx, b.Y);
                    float w = (float)(1 + 7 * Math.Sqrt(ed.Flux / Math.Max(maxF, 1e-9)));
                    using (var pen = new Pen(Color.FromArgb(140, col), w) { EndCap = LineCap.Flat })
                    {
                        g.DrawBezier(pen, a, c1, c2, b);
                        // arrow head at b
                        float dir = same ? 1 : -1; PointF[] head = { b, new PointF(b.X + dir * 7, b.Y - 4), new PointF(b.X + dir * 7, b.Y + 4) };
                        using (var hb = new SolidBrush(Color.FromArgb(200, col))) g.FillPolygon(hb, head);
                    }
                    var pts = new PointF[21];
                    for (int i = 0; i <= 20; i++) { float u = i / 20f, v = 1 - u; pts[i] = new PointF(v * v * v * a.X + 3 * v * v * u * c1.X + 3 * v * u * u * c2.X + u * u * u * b.X, v * v * v * a.Y + 3 * v * v * u * c1.Y + 3 * v * u * u * c2.Y + u * u * u * b.Y); }
                    m_hits.Add(new KeyValuePair<PointF[], NonForestBudget.Edge>(pts, ed));
                    if (ed.Flux >= 0.03 * maxF || ed.Kind == "Net growth")
                    {
                        string txt = ShowFlux ? Num(ed.Flux) : ed.Kind == "Net growth" ? (ed.Entered * 100).ToString("0.#", CultureInfo.InvariantCulture) + "%" : RateText(ed.Entered);
                        PointF at = same ? new PointF(bx + 3, (a.Y + b.Y) / 2 - 7) : ed.Kind == "Net growth" ? new PointF(8, b.Y - 17) : new PointF(pts[10].X, pts[10].Y - 16);   // the middle of the curve, clear of the boxes; centred below
                        labels.Add(Tuple.Create(at, txt, ed.Yours, col, !same && ed.Kind != "Net growth"));
                    }
                }
                foreach (var p in Budget.P.Values.Where(q => pos.ContainsKey(q.Key)))
                {
                    RectangleF r = pos[p.Key];
                    Color fill = p.Col == 0 ? LiveFill : (p.Key == "AGS" || p.Key == "BGS" || p.Key == "DS") ? SlowFill : DeadFill;
                    Color line = p.Col == 0 ? LiveLine : (p.Key == "AGS" || p.Key == "BGS" || p.Key == "DS") ? SlowLine : DeadLine;
                    Color text = p.Col == 0 ? LiveText : (p.Key == "AGS" || p.Key == "BGS" || p.Key == "DS") ? SlowText : DeadText;
                    using (var path = Round(r, 6)) using (var fb = new SolidBrush(fill)) using (var lp = new Pen(line, 1)) { g.FillPath(fb, path); g.DrawPath(lp, path); }
                    using (var tb = new SolidBrush(text))
                    {
                        g.DrawString(p.Label, bold, tb, r.X + 7, r.Y + 3);
                        double tau = p.Out > 0 ? 1 / p.Out : 0;
                        string l2 = p.Key == "DS" ? "+" + Num(p.In) + " Mg C/ha/yr" : Num(p.Stock) + " Mg C/ha" + (tau > 0 ? " · " + (tau >= 10 ? Math.Round(tau).ToString(CultureInfo.InvariantCulture) : tau.ToString("0.0", CultureInfo.InvariantCulture)) + " yr" : "");
                        g.DrawString(l2, small, tb, r.X + 7, r.Y + 20);
                        // emergent wetlands: the pool's total loss, of which the arrows out of it take shares
                        if (Budget.Totals.Contains(p.Key)) g.DrawString("loss " + RateText(p.Total) + "/yr" + (ShowFlux ? "" : ", shared out"), small, tb, r.X + 7, r.Y + 36);
                    }
                }
                // what leaves the system: up to the atmosphere from each box's top right corner, sideways to water from its right side
                Color air = Color.FromArgb(120, 120, 116), water = Color.FromArgb(55, 138, 221);
                foreach (var ed in Budget.Edges.Where(x => (x.To == "ATM" || x.To == "AQ") && x.Flux > 1e-9 && pos.ContainsKey(x.From)))
                {
                    RectangleF r = pos[ed.From]; bool up = ed.To == "ATM"; Color col = up ? air : water;
                    float w = (float)(1 + 7 * Math.Sqrt(ed.Flux / Math.Max(maxF, 1e-9)));
                    PointF a = up ? new PointF(r.Right - 26, r.Top) : new PointF(r.Right, r.Bottom - 12);
                    PointF b = up ? new PointF(r.Right - 8, r.Top - 26) : new PointF(r.Right + 26, r.Bottom - 12);
                    PointF c1 = up ? new PointF(a.X, a.Y - 14) : new PointF(a.X + 9, a.Y), c2 = up ? new PointF(a.X + 2, b.Y + 4) : new PointF(b.X - 9, b.Y);
                    using (var pen = new Pen(Color.FromArgb(150, col), w)) g.DrawBezier(pen, a, c1, c2, b);
                    // the head points along the curve's last stretch
                    double ang = Math.Atan2(b.Y - c2.Y, b.X - c2.X); float hx = (float)Math.Cos(ang), hy = (float)Math.Sin(ang);
                    PointF tip = new PointF(b.X + hx * 6, b.Y + hy * 6);
                    PointF[] head = { tip, new PointF(b.X - hy * 4, b.Y + hx * 4), new PointF(b.X + hy * 4, b.Y - hx * 4) };
                    using (var hb = new SolidBrush(Color.FromArgb(210, col))) g.FillPolygon(hb, head);
                    var pts = new PointF[11];
                    for (int i = 0; i <= 10; i++) { float u = i / 10f, v = 1 - u; pts[i] = new PointF(v * v * v * a.X + 3 * v * v * u * c1.X + 3 * v * u * u * c2.X + u * u * u * b.X, v * v * v * a.Y + 3 * v * v * u * c1.Y + 3 * v * u * u * c2.Y + u * u * u * b.Y); }
                    m_hits.Add(new KeyValuePair<PointF[], NonForestBudget.Edge>(pts, ed));
                    string txt = (up ? "CO\u2082 " : "water ") + (ShowFlux ? Num(ed.Flux) : RateText(ed.Entered));
                    labels.Add(Tuple.Create(up ? new PointF(tip.X + 3, tip.Y - 8) : new PointF(a.X + 3, a.Y + 4), txt, ed.Yours, col, false));
                }
                foreach (var l in labels)
                    using (var lb = new SolidBrush(Color.FromArgb(Math.Min(255, l.Item4.R / 2), Math.Min(255, l.Item4.G / 2), Math.Min(255, l.Item4.B / 2))))
                    {
                        Font f = l.Item3 ? bold : small; float lw = g.MeasureString(l.Item2, f).Width;
                        // curve labels are centred on the curve's middle; net growth and same-column labels keep their left edge
                        g.DrawString(l.Item2, f, lb, l.Item1.X - (l.Item5 ? lw / 2 : 0), l.Item1.Y);
                    }
            }
        }

        private static GraphicsPath Round(RectangleF r, float d)
        {
            var p = new GraphicsPath(); d *= 2;
            p.AddArc(r.X, r.Y, d, d, 180, 90); p.AddArc(r.Right - d, r.Y, d, d, 270, 90); p.AddArc(r.Right - d, r.Bottom - d, d, d, 0, 90); p.AddArc(r.X, r.Bottom - d, d, d, 90, 90);
            p.CloseFigure(); return p;
        }

        // the curve under the mouse, described
        protected override void OnMouseMove(MouseEventArgs e)
        {
            base.OnMouseMove(e);
            string text = "";
            foreach (var h in m_hits)
                if (h.Key.Any(q => Math.Abs(q.X - e.X) < 6 && Math.Abs(q.Y - e.Y) < 6))
                {
                    var ed = h.Value; var b = Budget;
                    text = ed.Kind == "Net growth"
                        ? string.Format("Net growth to {0}: {1:0.#}% of {2} = {3} Mg C/ha/yr{4}", b.P[ed.To].Label.ToLower(), ed.Entered * 100, Num(b.Growth), Num(ed.Flux), ed.Yours ? " (this page's row)" : "")
                        : string.Format("{0}: {1} to {2}\n{3} {4} x {5} Mg C/ha = {6} Mg C/ha/yr{7}", ed.Kind, b.P[ed.From].Label.ToLower(), ed.To == "ATM" ? "the atmosphere" : ed.To == "AQ" ? "water" : b.P[ed.To].Label.ToLower(),
                            b.Totals.Contains(ed.From) && ed.Kind != "Biomass Turnover" ? "share " + RateText(ed.Entered) + " of loss " + RateText(b.P[ed.From].Total) + "/yr =" : "rate", RateText(ed.Rate) + "/yr",
                            Num(b.P[ed.From].Stock), Num(ed.Flux), ed.Yours ? "\n(set by this page's rows)" : "");
                    break;
                }
            if (text != m_tipText) { m_tipText = text; if (text.Length > 0) m_tip.Show(text, this, e.X + 14, e.Y + 14); else m_tip.Hide(this); }
        }
        protected override void OnMouseLeave(EventArgs e) { base.OnMouseLeave(e); m_tipText = ""; m_tip.Hide(this); }
    }
}
