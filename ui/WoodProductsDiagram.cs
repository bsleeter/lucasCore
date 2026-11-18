// =============================================================================
// WoodProductsDiagram.cs - draws a WoodProductsFate result: where 100 units of harvested carbon are some years after the harvest
// =============================================================================
// Five columns, left to right: the harvest; the products in use by class; what has been discarded (wood, paper); recovered products
// and disposal sites; what has been emitted. A box gives the carbon there in the year shown, in % of the harvest; a curve's width is
// the carbon that has passed along it by then. The curve over the top is what is burned for energy in the harvest year (bark,
// fuelwood, mill residue, and the page's extra share). Beside each value, the value with the default parameters when it differs
// (the value is then bold). Hovering a curve describes it.
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
    internal class WoodProductsDiagram : Control
    {
        public WoodProductsFate.Result Fate, Base;   // with the page's parameters; with the defaults
        public string Empty = "";

        private const int BH = 52, TOPY = 86, H = 386;
        private static readonly int[][] Cols = { new[] { 8, 116 }, new[] { 172, 172 }, new[] { 392, 120 }, new[] { 558, 124 }, new[] { 726, 136 } };
        private readonly ToolTip m_tip = new ToolTip { InitialDelay = 100, ReshowDelay = 50 };
        private readonly List<KeyValuePair<PointF[], string>> m_hits = new List<KeyValuePair<PointF[], string>>();
        private string m_tipText = "";

        private static readonly Color UseFill = Color.FromArgb(234, 243, 222), UseLine = Color.FromArgb(99, 153, 34), UseText = Color.FromArgb(39, 80, 10);
        private static readonly Color DisFill = Color.FromArgb(250, 238, 218), DisLine = Color.FromArgb(186, 117, 23), DisText = Color.FromArgb(99, 56, 6);
        private static readonly Color AirFill = Color.FromArgb(241, 239, 232), AirLine = Color.FromArgb(136, 135, 128), AirText = Color.FromArgb(68, 68, 65);

        public WoodProductsDiagram()
        {
            SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.UserPaint | ControlStyles.ResizeRedraw, true);
            BackColor = SystemColors.Window; Height = H; MinimumSize = new Size(200, H);
        }

        public static string Pct(double x) { return (Math.Abs(x) < 0.05 ? "0" : x.ToString("0.0", CultureInfo.InvariantCulture)) + "%"; }

        private class Box { public RectangleF R; public string Label, Extra; public double V, D; public int Kind; }
        private float m_scale = 1;
        private Box Make(int col, float y, string label, double v, double d, int kind, string extra)
        {
            return new Box { R = new RectangleF(Cols[col][0] * m_scale, y, Cols[col][1] * m_scale, BH), Label = label, V = v, D = d, Kind = kind, Extra = extra };
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            base.OnPaint(e);
            Graphics g = e.Graphics; g.SmoothingMode = SmoothingMode.AntiAlias; g.TextRenderingHint = System.Drawing.Text.TextRenderingHint.ClearTypeGridFit;
            m_hits.Clear();
            if (Fate == null) { TextRenderer.DrawText(g, Empty.Length > 0 ? Empty : "No values for this choice.", Font, new Point(10, 10), SystemColors.GrayText); return; }
            WoodProductsFate.Result f = Fate, b = Base ?? Fate;
            m_scale = Math.Max(0.7f, Math.Min(1.5f, (Width - 16) / 870f));
            using (var small = new Font(Font.FontFamily, Font.Size - 0.5f))
            using (var bold = new Font(Font, FontStyle.Bold))
            using (var grey = new SolidBrush(SystemColors.GrayText))
            {
                string[] heads = { "Harvest", "Products in use", "Discarded so far", "Recovered and disposal", "Emitted so far" };
                for (int c = 0; c < 5; c++) g.DrawString(heads[c], small, grey, Cols[c][0] * m_scale, 4);

                Box harvest = Make(0, TOPY + 99, "Harvested wood", 100, 100, 0, "wood and bark");
                var cls = new Box[4];
                for (int k = 0; k < 4; k++) cls[k] = Make(1, TOPY + k * (BH + 14), WoodProductsFate.Classes[k], f.InUse[k], b.InUse[k], 0, "of " + Pct(f.Made[k]) + " made");
                Box[] disc = { Make(2, TOPY + 50, "Discarded wood", f.DiscTotal[0], b.DiscTotal[0], 1, null), Make(2, TOPY + 174, "Discarded paper", f.DiscTotal[1], b.DiscTotal[1], 1, null) };
                Box[] ends = { Make(3, TOPY + 20, "Recovered, in use again", f.Recovered, b.Recovered, 0, null), Make(3, TOPY + 112, "Landfills", f.Landfill, b.Landfill, 1, null), Make(3, TOPY + 204, "Dumps", f.Dump, b.Dump, 1, null) };
                Box[] air = { Make(4, TOPY - 56, "With energy capture", f.EmitEnergy, b.EmitEnergy, 2, null), Make(4, TOPY + 150, "Without energy capture", f.EmitNo, b.EmitNo, 2, null) };

                var labels = new List<Tuple<PointF, string, Color>>();
                Action<PointF, PointF, PointF, PointF, double, Color, string, bool> curve = (a, c1, c2, z, flux, col, tip, label) =>
                {
                    if (flux < 0.05) return;
                    float w = (float)Math.Max(1, 0.42 * flux * m_scale);
                    using (var pen = new Pen(Color.FromArgb(120, col), w) { EndCap = LineCap.Flat }) g.DrawBezier(pen, a, c1, c2, z);
                    PointF[] head = { new PointF(z.X + 2, z.Y), new PointF(z.X - 5, z.Y - 4), new PointF(z.X - 5, z.Y + 4) };
                    using (var hb = new SolidBrush(Color.FromArgb(200, col))) g.FillPolygon(hb, head);
                    var pts = new PointF[21];
                    for (int i = 0; i <= 20; i++) { float u = i / 20f, v = 1 - u; pts[i] = new PointF(v * v * v * a.X + 3 * v * v * u * c1.X + 3 * v * u * u * c2.X + u * u * u * z.X, v * v * v * a.Y + 3 * v * v * u * c1.Y + 3 * v * u * u * c2.Y + u * u * u * z.Y); }
                    m_hits.Add(new KeyValuePair<PointF[], string>(pts, tip));
                    if (label && flux >= 3) labels.Add(Tuple.Create(new PointF(pts[7].X, pts[7].Y - 16), Pct(flux), col));
                };
                Action<Box, float, Box, float, double, Color, string, bool> link = (s, sy, t, ty, flux, col, tip, label) =>
                {
                    PointF a = new PointF(s.R.Right, s.R.Y + sy), z = new PointF(t.R.X - 3, t.R.Y + ty); float mx = (a.X + z.X) / 2;
                    curve(a, new PointF(mx, a.Y), new PointF(mx, z.Y), z, flux, col, tip, label);
                };

                // burned for energy in the harvest year: over the top to "with energy capture"
                {
                    PointF a = new PointF(harvest.R.Right - 30, harvest.R.Top), z = new PointF(air[0].R.X - 3, air[0].R.Y + BH / 2f);
                    string tip = string.Format("Burned with energy capture in the harvest year: {0} of the harvest\nbark {1}, fuelwood {2}, mill residue {3}{4}", Pct(f.AtHarvest), Pct(f.Bark), Pct(f.Fuelwood), Pct(f.MillResidue),
                        f.ExtraEnergy > 0 ? ", the extra share burned for energy " + Pct(f.ExtraEnergy) : "");
                    curve(a, new PointF(a.X, z.Y + 6), new PointF(a.X + 40, z.Y), z, f.AtHarvest, AirLine, tip, false);
                    string txt = "burned for energy in the harvest year " + Pct(f.AtHarvest) + (Math.Abs(f.AtHarvest - b.AtHarvest) >= 0.05 ? "  (default " + Pct(b.AtHarvest) + ")" : "");
                    labels.Add(Tuple.Create(new PointF(Cols[1][0] * m_scale + g.MeasureString(txt, small).Width / 2, air[0].R.Y + BH / 2f - 26), txt, AirLine));
                }
                for (int k = 0; k < 4; k++)
                {
                    link(harvest, BH / 2f + (k - 1.5f) * 9, cls[k], BH / 2f, f.Made[k], UseLine, string.Format("Made into {0}: {1} of the harvest (the loss when placed in use included)", WoodProductsFate.Classes[k].ToLower(), Pct(f.Made[k])), false);
                    link(cls[k], BH / 2f, disc[k == 3 ? 1 : 0], BH / 2f + (k == 3 ? 0 : (k - 1) * 10), f.Discarded[k], DisLine,
                         string.Format("{0}: {1} of the harvest discarded in {2} years ({3} made, {4} still in use)", WoodProductsFate.Classes[k], Pct(f.Discarded[k]), f.Years, Pct(f.Made[k]), Pct(f.InUse[k])), false);
                }
                string[] mat = { "wood", "paper" };
                for (int m = 0; m < 2; m++)
                {
                    for (int k = 0; k < 3; k++)
                        link(disc[m], BH / 2f + (k - 1) * 8, ends[k], BH / 2f + (m == 0 ? -7 : 7), f.To[m, k], k == 0 ? UseLine : DisLine,
                             k == 0 ? string.Format("Discarded {0} recovered and still in use: {1} of the harvest (recovered products last a few years and are then discarded again)", mat[m], Pct(f.To[m, 0]))
                                    : string.Format("Discarded {0} to {1}: {2} of the harvest in {3} years", mat[m], WoodProductsFate.Ends[k].ToLower(), Pct(f.To[m, k]), f.Years), true);
                    // burned: straight to the atmosphere, under (wood) or over (paper) the disposal boxes
                    for (int k = 3; k < 5; k++)
                    {
                        PointF a = new PointF(disc[m].R.Right, disc[m].R.Y + (m == 0 ? 6 : BH - 6)), z = new PointF(air[k - 3].R.X - 3, air[k - 3].R.Y + BH / 2f + (m == 0 ? -12 : 12));
                        float viaY = k == 3 ? TOPY - 14 : (m == 0 ? TOPY + 88 : TOPY + 188);   // between the disposal boxes
                        curve(a, new PointF(a.X + 50, viaY), new PointF(z.X - 70, viaY), z, f.To[m, k], AirLine,
                              string.Format("Discarded {0} {1}: {2} of the harvest in {3} years", mat[m], WoodProductsFate.Ends[k].ToLower(), Pct(f.To[m, k]), f.Years), false);
                    }
                }
                link(ends[1], BH / 2f, air[1], BH / 2f - 4, f.LandfillDecay, AirLine, string.Format("Landfill decay: {0} of the harvest in {1} years (the share of a landfill that never decays stays)", Pct(f.LandfillDecay), f.Years), true);
                link(ends[2], BH / 2f, air[1], BH / 2f + 8, f.DumpDecay, AirLine, string.Format("Dump decay: {0} of the harvest in {1} years", Pct(f.DumpDecay), f.Years), true);

                foreach (Box x in new[] { harvest }.Concat(cls).Concat(disc).Concat(ends).Concat(air))
                {
                    Color fill = x.Kind == 0 ? UseFill : x.Kind == 1 ? DisFill : AirFill, line = x.Kind == 0 ? UseLine : x.Kind == 1 ? DisLine : AirLine, text = x.Kind == 0 ? UseText : x.Kind == 1 ? DisText : AirText;
                    using (var path = Round(x.R, 6)) using (var fb = new SolidBrush(fill)) using (var lp = new Pen(line, 1)) { g.FillPath(fb, path); g.DrawPath(lp, path); }
                    using (var tb = new SolidBrush(text))
                    {
                        g.DrawString(x.Label, bold, tb, x.R.X + 6, x.R.Y + 3);
                        bool diff = Math.Abs(x.V - x.D) >= 0.05; string v = Pct(x.V);
                        g.DrawString(v, diff ? bold : small, tb, x.R.X + 6, x.R.Y + 19);
                        if (diff) g.DrawString("(default " + Pct(x.D) + ")", small, tb, x.R.X + 8 + g.MeasureString(v, bold).Width, x.R.Y + 19);
                        if (x.Extra != null) g.DrawString(x.Extra, small, tb, x.R.X + 6, x.R.Y + 34);
                    }
                }
                foreach (var l in labels)
                    using (var lb = new SolidBrush(Color.FromArgb(l.Item3.R / 2, l.Item3.G / 2, l.Item3.B / 2)))
                        g.DrawString(l.Item2, small, lb, l.Item1.X - g.MeasureString(l.Item2, small).Width / 2, l.Item1.Y);
            }
        }

        private static GraphicsPath Round(RectangleF r, float d)
        {
            var p = new GraphicsPath(); d *= 2;
            p.AddArc(r.X, r.Y, d, d, 180, 90); p.AddArc(r.Right - d, r.Y, d, d, 270, 90); p.AddArc(r.Right - d, r.Bottom - d, d, d, 0, 90); p.AddArc(r.X, r.Bottom - d, d, d, 90, 90);
            p.CloseFigure(); return p;
        }

        protected override void OnMouseMove(MouseEventArgs e)
        {
            base.OnMouseMove(e);
            string text = "";
            foreach (var h in m_hits) if (h.Key.Any(q => Math.Abs(q.X - e.X) < 6 && Math.Abs(q.Y - e.Y) < 6)) { text = h.Value; break; }
            if (text != m_tipText) { m_tipText = text; if (text.Length > 0) m_tip.Show(text, this, e.X + 14, e.Y + 14); else m_tip.Hide(this); }
        }
        protected override void OnMouseLeave(EventArgs e) { base.OnMouseLeave(e); m_tipText = ""; m_tip.Hide(this); }
    }
}
