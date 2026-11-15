// =============================================================================
// LandUseDemandCards.cs - the "How much" part of each card on the Land Use Change page
// =============================================================================
// User 2026-11-15: "It is unclear what the Land Use Demand Ratios page does. I want you to reimagine how these three pages can be
// presented to the user in a clean and clear way." The Land Use, Land Use Demand and Land Use Demand Ratios pages became one page with
// a card per kind of change (ProjectionTransitionsView). A card's head (here) asks how much: the choice shows only its own settings,
// the custom table is edited in the card that uses it, a sentence says what the choice does and a small chart shows the multiplier
// through time. The sheets are the same (lucasCore_LandUseDemand, one row; lucasCore_LandUseDemandRatio), so stage 9 is unchanged.
// The chart: the entered numbers for a custom table; for the other choices the multipliers stage 9 wrote to the newest result of
// this scenario (lucasCore_OutputLandUseDemand), when that result was made with the settings shown.
// =============================================================================
using System;
using System.Collections.Generic;
using System.Data;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Linq;
using System.Windows.Forms;
using SyncroSim.Core;

namespace lucasCoreUI
{
    // ---- the multiplier through time ----------------------------------------------------------------------------------------
    internal class MultiplierChart : Control
    {
        public class Line { public double[] X, Y; public bool Bold; }
        private List<Line> m_lines = new List<Line>();
        private double[] m_x, m_lo, m_hi;
        private string m_caption = "", m_message = "";

        public MultiplierChart()
        {
            this.Size = new Size(250, 108); this.Margin = new Padding(14, 2, 3, 3); this.Tag = Fit.Fixed;
            this.SetStyle(ControlStyles.OptimizedDoubleBuffer | ControlStyles.AllPaintingInWmPaint | ControlStyles.UserPaint | ControlStyles.ResizeRedraw, true);
        }

        public void Set(List<Line> lines, double[] x, double[] lo, double[] hi, string caption)
        { m_lines = lines ?? new List<Line>(); m_x = x; m_lo = lo; m_hi = hi; m_caption = caption ?? ""; m_message = ""; Invalidate(); }
        public void Say(string message) { m_lines = new List<Line>(); m_x = null; m_message = message ?? ""; m_caption = ""; Invalidate(); }

        protected override void OnPaint(PaintEventArgs e)
        {
            Graphics g = e.Graphics; g.Clear(this.Parent == null ? SystemColors.Control : this.Parent.BackColor);
            g.SmoothingMode = SmoothingMode.AntiAlias;
            var plot = new Rectangle(26, 5, this.Width - 32, 56);
            using (var small = new Font(this.Font.FontFamily, 7.5f))
            using (var grey = new SolidBrush(SystemColors.GrayText))
            using (var axis = new Pen(SystemColors.ControlDark))
            {
                var fmt = new StringFormat { Alignment = StringAlignment.Near, LineAlignment = StringAlignment.Near };
                var below = new RectangleF(0, plot.Bottom + 14, this.Width, this.Height - plot.Bottom - 14);
                if (m_lines.Count == 0)
                {
                    g.DrawRectangle(axis, plot);
                    g.DrawString(m_message, small, grey, new RectangleF(plot.Left + 6, plot.Top + 6, plot.Width - 12, plot.Height - 8), fmt);
                    return;
                }
                double x0 = m_lines.Min(l => l.X.Min()), x1 = m_lines.Max(l => l.X.Max()); if (x1 <= x0) x1 = x0 + 1;
                double top = Math.Max(m_lines.Max(l => l.Y.Max()), m_hi == null || m_hi.Length == 0 ? 0 : m_hi.Max());
                double ymax = Math.Max(2, Math.Ceiling(top * 1.05 * 2) / 2);
                Func<double, float> px = x => (float)(plot.Left + (x - x0) / (x1 - x0) * plot.Width);
                Func<double, float> py = y => (float)(plot.Bottom - Math.Min(y, ymax) / ymax * plot.Height);
                // the range across units
                if (m_x != null && m_lo != null && m_hi != null && m_x.Length > 1)
                {
                    var pts = new List<PointF>();
                    for (int i = 0; i < m_x.Length; i++) pts.Add(new PointF(px(m_x[i]), py(m_hi[i])));
                    for (int i = m_x.Length - 1; i >= 0; i--) pts.Add(new PointF(px(m_x[i]), py(m_lo[i])));
                    using (var band = new SolidBrush(Color.FromArgb(50, 29, 158, 117))) g.FillPolygon(band, pts.ToArray());
                }
                g.DrawLine(axis, plot.Left, plot.Bottom, plot.Right, plot.Bottom); g.DrawLine(axis, plot.Left, plot.Top, plot.Left, plot.Bottom);
                using (var one = new Pen(SystemColors.ControlDark) { DashStyle = DashStyle.Dash }) g.DrawLine(one, plot.Left, py(1), plot.Right, py(1));
                var right = new StringFormat { Alignment = StringAlignment.Far, LineAlignment = StringAlignment.Center };
                g.DrawString("1", small, grey, new RectangleF(0, py(1) - 7, plot.Left - 2, 14), right);
                g.DrawString(ymax.ToString("0.#"), small, grey, new RectangleF(0, plot.Top - 5, plot.Left - 2, 14), right);
                g.DrawString("0", small, grey, new RectangleF(0, plot.Bottom - 9, plot.Left - 2, 14), right);
                g.DrawString(x0.ToString("0"), small, grey, plot.Left - 2, plot.Bottom + 1);
                g.DrawString(x1.ToString("0"), small, grey, new RectangleF(plot.Right - 40, plot.Bottom + 1, 42, 12), new StringFormat { Alignment = StringAlignment.Far });
                foreach (Line l in m_lines.OrderBy(v => v.Bold))
                    using (var pen = new Pen(l.Bold ? Color.FromArgb(15, 110, 86) : Color.FromArgb(120, 29, 158, 117), l.Bold ? 2f : 1f))
                    {
                        var pts = new PointF[l.X.Length]; for (int i = 0; i < pts.Length; i++) pts[i] = new PointF(px(l.X[i]), py(l.Y[i]));
                        if (pts.Length > 1) g.DrawLines(pen, pts);
                    }
                g.DrawString(m_caption, small, grey, below, fmt);
            }
        }
    }

    // ---- the units a custom multiplier may name: every Stratum Source and its units (as UnitPicker) -----------------------------
    internal class UnitCatalog
    {
        public class Source { public int Number; public string Name; public override string ToString() { return Name; } }
        public class Unit { public int Key; public int Source; public string Name, Short; public override string ToString() { return Short; } }
        public readonly List<Source> Sources = new List<Source>();
        public readonly Dictionary<int, Unit> Units = new Dictionary<int, Unit>();

        public static UnitCatalog Load(Project p)
        {
            var c = new UnitCatalog();
            try
            {
                foreach (DataRow r in p.GetDataSheet("lucasCore_StratumSource").GetData().Rows.Cast<DataRow>().Where(x => x.RowState != DataRowState.Deleted))
                    if (r["Number"] != DBNull.Value) c.Sources.Add(new Source { Number = Convert.ToInt32(r["Number"]), Name = Convert.ToString(r["Name"]) });
                c.Sources.Sort((a, b) => a.Number.CompareTo(b.Number));
                foreach (DataRow r in p.GetDataSheet("stsim_SecondaryStratum").GetData().Rows.Cast<DataRow>().Where(x => x.RowState != DataRowState.Deleted))
                {
                    if (r["ID"] == DBNull.Value) continue;
                    var u = new Unit { Key = Convert.ToInt32(r["SecondaryStratumId"]), Source = (int)Math.Floor(Convert.ToInt64(r["ID"]) / 1e8), Name = Convert.ToString(r["Name"]) };
                    int colon = u.Name.IndexOf(": ", StringComparison.Ordinal); u.Short = colon >= 0 ? u.Name.Substring(colon + 2) : u.Name;
                    c.Units[u.Key] = u;
                }
            }
            catch (Exception) { }
            return c;
        }
    }

    // ---- the multipliers of the newest result of a scenario (or of the result itself) ---------------------------------------------
    internal class ResultRatios
    {
        public int Id = -1; public bool Self;
        private readonly Dictionary<string, string> m_set = new Dictionary<string, string>();
        private readonly List<object[]> m_rows = new List<object[]>();   // group, timestep, ratio

        public static int Newest(Scenario sc)
        {
            if (sc == null) return -1; if (sc.IsResult) return sc.Id;
            try { var ids = sc.Results.Cast<Scenario>().Select(x => x.Id).ToList(); return ids.Count == 0 ? -1 : ids.Max(); } catch (Exception) { return -1; }
        }

        public static ResultRatios Load(Scenario sc)
        {
            int id = Newest(sc); if (id < 0) return null;
            var r = new ResultRatios { Id = id, Self = sc.IsResult };
            try
            {
                Scenario res = sc.IsResult ? sc : sc.Results.Cast<Scenario>().First(x => x.Id == id);
                DataSheet st = res.GetDataSheet("lucasCore_LandUseDemand");
                DataRow row = st != null && st.HasData() ? st.GetDataRow() : null;
                if (row != null) foreach (DataColumn c in row.Table.Columns) r.m_set[c.ColumnName] = Txt(row[c]);
                DataSheet o = res.GetDataSheet("lucasCore_OutputLandUseDemand");
                if (o != null && o.HasData())
                    foreach (DataRow x in o.GetData().Rows.Cast<DataRow>().Where(v => v.RowState != DataRowState.Deleted))
                        if (x["Timestep"] != DBNull.Value && x["Ratio"] != DBNull.Value) r.m_rows.Add(new object[] { Convert.ToString(x["TransitionGroup"]), Convert.ToInt32(x["Timestep"]), Convert.ToDouble(x["Ratio"]) });
            }
            catch (Exception) { }
            return r;
        }

        private static string Txt(object v) { return v == null || v == DBNull.Value ? "" : Convert.ToString(v); }

        // made with the settings shown now (the named columns of the Land Use Demand row)?
        public bool Same(Func<string, object> get, IEnumerable<string> columns)
        {
            foreach (string c in columns) { string was; if (!m_set.TryGetValue(c, out was)) was = ""; if (was != Txt(get(c))) return false; }
            return true;
        }

        public int FirstYear { get { return m_rows.Count == 0 ? -1 : m_rows.Min(x => (int)x[1]); } }

        // per year: the mean, lowest and highest multiplier of the groups whose name starts with the prefix
        public bool Series(string prefix, out double[] x, out double[] mean, out double[] lo, out double[] hi)
        {
            var by = m_rows.Where(v => ((string)v[0]).StartsWith(prefix)).GroupBy(v => (int)v[1]).OrderBy(v => v.Key).ToList();
            x = by.Select(v => (double)v.Key).ToArray(); mean = by.Select(v => v.Average(k => (double)k[2])).ToArray();
            lo = by.Select(v => v.Min(k => (double)k[2])).ToArray(); hi = by.Select(v => v.Max(k => (double)k[2])).ToArray();
            return x.Length > 1;
        }
    }

    // ---- one card's head ------------------------------------------------------------------------------------------------------------
    internal class DemandCard
    {
        public const int SAME = 0, HIGH = 1, LOW = 2, RPA = 3, ICLUS = 4, POP = 5, CUSTOM = 6, FOLLOW = 7;
        private static readonly string[] LABEL = { "Same as the reference period", "High years (each unit's highest third)", "Low years (each unit's lowest third)",
            "RPA 2020 Assessment", "ICLUS v2.1.1 (EPA)", "Population growth (SSP)", "Custom multipliers", "Follows urbanization" };
        private static readonly string[] RPA_SCENARIO = { "RCP4.5-SSP1 (lower emissions, medium growth)", "RCP8.5-SSP2 (high emissions, medium growth)", "RCP8.5-SSP3 (high emissions, low growth)", "RCP8.5-SSP5 (high emissions, high growth)" };
        private static readonly string[] ICLUS_SCENARIO = { "SSP2-RCP4.5", "SSP5-RCP8.5" };
        private static readonly string[] SSP = { "SSP1", "SSP2", "SSP3", "SSP4", "SSP5" };
        private static readonly string[] POOL = { "Default (metropolitan area; population: county)", "County", "Metropolitan area (other counties by state)", "State" };
        private static readonly string[] URBAN = { "UrbanMethod", "UrbanIclus", "UrbanScenario", "UrbanSsp", "LandPerNewResident", "NewResidentWeight", "UrbanPooling", "UrbanMaxRatio" };
        public const string DEMAND = "lucasCore_LandUseDemand", RATIOS = "lucasCore_LandUseDemandRatio";
        private const int TRUE = -1;

        public class Spec
        {
            public string Title, Prefix, MethodCol, ScenarioCol, Fixed; public int AppliesTo; public int[] Means, Stored; public string[] Columns;
        }
        public static readonly Spec[] SPECS = {
            new Spec { Title = "Urbanization", Prefix = "Urbanization", MethodCol = "UrbanMethod", ScenarioCol = "UrbanScenario", AppliesTo = 1,
                       Means = new[] { SAME, HIGH, LOW, RPA, ICLUS, POP, CUSTOM }, Stored = new[] { 1, 2, 3, 4, 7, 5, 6 }, Columns = URBAN },
            new Spec { Title = "Intensification", Prefix = "Intensification", MethodCol = "IntensificationFollows",
                       Means = new[] { SAME, FOLLOW }, Stored = new[] { 0, TRUE }, Columns = URBAN.Concat(new[] { "IntensificationFollows" }).ToArray() },
            new Spec { Title = "Agricultural expansion", Prefix = "Ag Expansion", MethodCol = "AgExpansionMethod", AppliesTo = 2,
                       Means = new[] { SAME, HIGH, LOW, CUSTOM }, Stored = new[] { 1, 2, 3, 4 }, Columns = new[] { "AgExpansionMethod", "UrbanMaxRatio" } },
            new Spec { Title = "Agricultural contraction", Prefix = "Ag Contraction", MethodCol = "AgContractionMethod", AppliesTo = 3,
                       Means = new[] { SAME, HIGH, LOW, CUSTOM }, Stored = new[] { 1, 2, 3, 4 }, Columns = new[] { "AgContractionMethod", "UrbanMaxRatio" } },
            new Spec { Title = "Cropland and pasture exchange", Prefix = "Ag Change", Fixed = "Same as the reference period: the drawn year's area of cropland becoming pasture and pasture becoming cropland. There are no alternatives for this kind." },
            new Spec { Title = "Forest harvest", Prefix = "Forest Harvest", MethodCol = "HarvestMethod", ScenarioCol = "HarvestScenario", AppliesTo = 4,
                       Means = new[] { SAME, HIGH, LOW, RPA, CUSTOM }, Stored = new[] { 1, 2, 3, 5, 4 }, Columns = new[] { "HarvestMethod", "HarvestScenario", "UrbanMaxRatio" } } };

        // what the page supplies
        public class Host
        {
            public Func<string, object> Get; public Action<string, object> Put; public Func<DataSheet> Ratios;
            public Func<bool> Refreshing; public Action Refresh; public Func<ResultRatios> Result; public Func<int> EndYear;
        }

        public readonly Spec S; public readonly TableLayoutPanel Head = new TableLayoutPanel { AutoSize = true, ColumnCount = 2, Margin = new Padding(0) };
        private readonly Host H;
        private readonly ComboBox m_how = List(270), m_rpa = List(300), m_iclus = List(140), m_ssp = List(80), m_pool = List(300), m_kind = List(150);
        private readonly ComboBox m_unit = new ComboBox { DropDownStyle = ComboBoxStyle.DropDown, Width = 190, AutoCompleteMode = AutoCompleteMode.SuggestAppend, AutoCompleteSource = AutoCompleteSource.ListItems, MaxDropDownItems = 20, Margin = new Padding(3, 3, 8, 3) };
        private readonly TrackBar m_track = new TrackBar { Minimum = 5, Maximum = 40, TickFrequency = 5, SmallChange = 1, LargeChange = 5, AutoSize = false, Size = new Size(170, 28), Margin = new Padding(0, 2, 0, 0) };
        private readonly TextBox m_land = Box(48), m_weight = Box(52), m_year = Box(52), m_mult = Box(52);
        private readonly Button m_add = new Button { Text = "Add", AutoSize = true, Margin = new Padding(3, 2, 6, 3) };
        private readonly Label m_words = new Label { AutoSize = true, MaximumSize = new Size(600, 0), ForeColor = SystemColors.GrayText, Margin = new Padding(3, 6, 3, 3), Tag = Fit.Fixed };
        private readonly Label m_addSaid = Small(""), m_landNote = Small("x land per new resident");
        private readonly MultiplierChart m_chart = new MultiplierChart();
        private readonly FlowLayoutPanel m_rows = ManagementActionsView.Lines();
        private Control m_rpaLine, m_iclusLine, m_sspLine, m_styleLine, m_poolLine, m_weightPart, m_custom;
        private UnitCatalog m_units = new UnitCatalog();
        private string m_shape;
        private class RowLine { public DataRow Row; public TextBox Year, Mult; }
        private readonly List<RowLine> m_lines = new List<RowLine>();

        private static ComboBox List(int width) { return new ComboBox { DropDownStyle = ComboBoxStyle.DropDownList, Width = width, Anchor = AnchorStyles.Left, Margin = new Padding(3, 3, 8, 3) }; }
        private static TextBox Box(int width) { return new TextBox { Width = width, TextAlign = HorizontalAlignment.Right, Margin = new Padding(3, 3, 6, 3) }; }
        private static Label Small(string text) { return new Label { Text = text, AutoSize = true, Margin = new Padding(3, 7, 3, 3), Tag = Fit.Fixed }; }
        private static FlowLayoutPanel Flow(params Control[] cs) { var f = new FlowLayoutPanel { AutoSize = true, WrapContents = false, Margin = new Padding(0) }; foreach (Control c in cs) f.Controls.Add(c); return f; }
        private static string Txt(object v) { return v == null || v == DBNull.Value ? "" : Convert.ToString(v); }
        private static IEnumerable<DataRow> Live(DataTable dt) { return dt.Rows.Cast<DataRow>().Where(x => x.RowState != DataRowState.Deleted); }

        public DemandCard(Spec spec, Host host)
        {
            S = spec; H = host;
            Head.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize)); Head.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));
            if (S.MethodCol == null)
            {
                m_words.Text = S.Fixed; m_words.MaximumSize = new Size(760, 0);
                Head.Controls.Add(ManagementActionsView.Line("How much:", m_words, null), 0, 0); m_words.Margin = new Padding(3, 6, 3, 3);
                return;
            }
            foreach (int m in S.Means) m_how.Items.Add(LABEL[m]);
            m_rpa.Items.AddRange(RPA_SCENARIO); m_iclus.Items.AddRange(ICLUS_SCENARIO); m_ssp.Items.AddRange(SSP); m_pool.Items.AddRange(POOL);
            var left = ManagementActionsView.Lines(ManagementActionsView.Line("How much:", m_how, null));
            left.MinimumSize = new Size(650, 0);
            if (S.ScenarioCol != null) left.Controls.Add(m_rpaLine = ManagementActionsView.Line("RPA scenario:", m_rpa, null));
            if (S.Means.Contains(ICLUS)) left.Controls.Add(m_iclusLine = ManagementActionsView.Line("ICLUS scenario:", m_iclus, null));
            if (S.Means.Contains(POP))
            {
                left.Controls.Add(m_sspLine = ManagementActionsView.Line("Population:", m_ssp, TransitionWalk.Note("County projections by SSP (Hauer 2019).")));
                left.Controls.Add(m_styleLine = ManagementActionsView.Line("Growth style:", Flow(Small("compact"), m_track, Small("sprawl"), m_land, m_landNote), null));
                left.Controls.Add(m_poolLine = ManagementActionsView.Line("Advanced:", Flow(Small("pooled by"), m_pool), null));
                left.Controls.Add(m_weightPart = ManagementActionsView.Line("", Flow(Small("new resident weight, years (blank = 176)"), m_weight), null));
            }
            left.Controls.Add(m_words);
            Head.Controls.Add(left, 0, 0); Head.Controls.Add(m_chart, 1, 0);
            if (S.AppliesTo > 0)
            {
                m_kind.Margin = new Padding(3, 3, 4, 3);
                var add = Flow(Small("Add:"), m_kind, m_unit, Small("year"), m_year, Small("multiplier"), m_mult, m_add, m_addSaid);
                m_custom = ManagementActionsView.Line("Multipliers:", ManagementActionsView.Lines(m_rows, add), null);
                Head.Controls.Add(m_custom, 0, 1); Head.SetColumnSpan(m_custom, 2);
            }
            m_words.MaximumSize = new Size(480, 0); m_words.Margin = new Padding(159, 2, 3, 3);

            m_how.SelectionChangeCommitted += (s, e) => { int i = m_how.SelectedIndex; if (i >= 0) H.Put(S.MethodCol, S.Stored[i]); };
            m_rpa.SelectionChangeCommitted += (s, e) => H.Put(S.ScenarioCol, m_rpa.SelectedIndex + 1);
            m_iclus.SelectionChangeCommitted += (s, e) => H.Put("UrbanIclus", m_iclus.SelectedIndex + 1);
            m_ssp.SelectionChangeCommitted += (s, e) => H.Put("UrbanSsp", m_ssp.SelectedIndex + 1);
            m_pool.SelectionChangeCommitted += (s, e) => H.Put("UrbanPooling", m_pool.SelectedIndex <= 0 ? null : (object)m_pool.SelectedIndex);
            m_track.Scroll += (s, e) => { if (!H.Refreshing()) m_land.Text = (m_track.Value * 0.05).ToString("0.00"); };
            m_track.MouseUp += (s, e) => H.Put("LandPerNewResident", Math.Round(m_track.Value * 0.05, 2));
            m_track.KeyUp += (s, e) => H.Put("LandPerNewResident", Math.Round(m_track.Value * 0.05, 2));
            Number(m_land, "LandPerNewResident"); Number(m_weight, "NewResidentWeight");
            m_kind.SelectionChangeCommitted += (s, e) => FillUnits();
            m_add.Click += (s, e) => AddRow();
        }

        // a number box of the Land Use Demand row: blank = the default; a bad or negative entry is put back
        private void Number(TextBox t, string column)
        {
            t.Validated += (s, e) =>
            {
                if (H.Refreshing()) return;
                string v = t.Text.Trim(); double d;
                if (v.Length == 0) H.Put(column, null); else if (double.TryParse(v, out d) && d >= 0) H.Put(column, d); else H.Refresh();
            };
        }

        public void LoadLists(UnitCatalog units)
        {
            m_units = units; m_shape = null;
            m_kind.Items.Clear(); m_kind.Items.Add("Everywhere"); foreach (UnitCatalog.Source s in units.Sources) m_kind.Items.Add(s);
            m_kind.SelectedIndex = 0; FillUnits();
        }

        private void FillUnits()
        {
            var src = m_kind.SelectedItem as UnitCatalog.Source;
            m_unit.BeginUpdate(); m_unit.Items.Clear();
            if (src != null) foreach (UnitCatalog.Unit u in m_units.Units.Values.Where(x => x.Source == src.Number).OrderBy(x => x.Short, StringComparer.CurrentCultureIgnoreCase)) m_unit.Items.Add(u);
            m_unit.EndUpdate(); m_unit.Text = ""; m_unit.Enabled = src != null;
        }

        // ---- the values ---------------------------------------------------------------------------------------------------------
        private int Stored()
        {
            object v = H.Get(S.MethodCol);
            if (S.MethodCol == "IntensificationFollows") return v != DBNull.Value && v != null && Convert.ToBoolean(v) ? TRUE : 0;
            return v == DBNull.Value || v == null ? S.Stored[0] : Convert.ToInt32(v);
        }
        public int Meaning { get { if (S.MethodCol == null) return SAME; int i = Array.IndexOf(S.Stored, Stored()); return S.Means[Math.Max(0, i)]; } }
        private int Pick(string column, int blank, int n) { object v = H.Get(column); int k = v == DBNull.Value || v == null ? blank : Convert.ToInt32(v); return Math.Max(1, Math.Min(n, k)) - 1; }
        private double Land() { object v = H.Get("LandPerNewResident"); return v == DBNull.Value || v == null ? 1 : Convert.ToDouble(v); }

        // the rows of the custom table that belong to this kind (Applies To blank = Urbanization)
        private List<DataRow> Rows()
        {
            DataSheet ds = H.Ratios(); if (ds == null || !ds.HasData()) return new List<DataRow>();
            return Live(ds.GetData()).Where(r => (r["AppliesTo"] == DBNull.Value ? 1 : Convert.ToInt32(r["AppliesTo"])) == S.AppliesTo).ToList();
        }
        private string Where(DataRow r)
        {
            if (r["UnitId"] == DBNull.Value) return "Everywhere";
            UnitCatalog.Unit u; return m_units.Units.TryGetValue(Convert.ToInt32(r["UnitId"]), out u) ? u.Name : "(unit " + Txt(r["UnitId"]) + ")";
        }

        // urban: the Urbanization card's meaning (for a card that follows it)
        public void Show(DemandCard urban)
        {
            if (S.MethodCol == null) return;
            int m = Meaning; m_how.SelectedIndex = Math.Max(0, Array.IndexOf(S.Means, m));
            if (m_rpaLine != null) { m_rpaLine.Visible = m == RPA; m_rpa.SelectedIndex = Pick(S.ScenarioCol, 2, 4); }
            if (m_iclusLine != null) { m_iclusLine.Visible = m == ICLUS; m_iclus.SelectedIndex = Pick("UrbanIclus", 1, 2); }
            if (m_sspLine != null)
            {
                m_sspLine.Visible = m_styleLine.Visible = m == POP; m_ssp.SelectedIndex = Pick("UrbanSsp", 2, 5);
                double f = Land(); m_track.Value = Math.Max(m_track.Minimum, Math.Min(m_track.Maximum, (int)Math.Round(f / 0.05)));
                if (!m_land.Focused) m_land.Text = f.ToString("0.00");
                m_poolLine.Visible = m == RPA || m == ICLUS || m == POP; m_weightPart.Visible = m == POP;
                object p = H.Get("UrbanPooling"); m_pool.SelectedIndex = p == DBNull.Value || p == null ? 0 : Math.Max(0, Math.Min(3, Convert.ToInt32(p)));
                if (!m_weight.Focused) m_weight.Text = Txt(H.Get("NewResidentWeight"));
            }
            List<DataRow> rows = m == CUSTOM ? Rows() : new List<DataRow>();
            if (m_custom != null) { m_custom.Visible = m == CUSTOM; if (m == CUSTOM) ShowRows(rows); }
            m_words.Text = Words(m, rows, urban); m_words.ForeColor = m == CUSTOM && rows.Count == 0 ? Color.Firebrick : SystemColors.GrayText;
            Chart(m, rows, urban);
        }

        private string Words(int m, List<DataRow> rows, DemandCard urban)
        {
            string what = S.Title.ToLowerInvariant();
            switch (m)
            {
                case HIGH: return "Each target unit changes at the pace of its highest third of reference years (their mean area over the mean of all years), every year.";
                case LOW: return "Each target unit changes at the pace of its lowest third of reference years (their mean area over the mean of all years), every year.";
                case RPA: return S.AppliesTo == 4
                    ? "The drawn area follows the 2020 RPA Assessment's forest products projection for the region (" + RPA_SCENARIO[m_rpa.SelectedIndex].Split(' ')[0] + "), relative to 2020. Needs the RPA forest products folder (Data Sources)."
                    : "The drawn area follows the 2020 RPA Assessment's projected urbanization (" + RPA_SCENARIO[m_rpa.SelectedIndex].Split(' ')[0] + ", the mean of its climate models), relative to its 2012-2020 step; the 2060-2070 value is kept after 2065. Needs the RPA county file (Data Sources).";
                case ICLUS: return "The drawn area follows EPA ICLUS v2.1.1 new developed land (" + ICLUS_SCENARIO[m_iclus.SelectedIndex] + "), relative to 2010-2020. Needs the ICLUS county table (Data Sources).";
                case POP: return string.Format("The drawn area scales with county population growth ({0}); each new resident takes {1:0.00} times the land of 2010-2020. Below 1 is compact growth, above 1 is sprawl. Needs the population and Census files (Data Sources).", SSP[m_ssp.SelectedIndex], Land());
                case CUSTOM: return rows.Count == 0 ? "Add at least one row: stage 9 stops when custom multipliers are chosen and none are entered."
                    : "The drawn area is multiplied by the numbers below: 1 is the reference-period rate, 2 doubles it. Linear between a unit's years, from 1 at the historical end, the last value kept. Where units overlap the smaller one decides; land with no row keeps 1.";
                case FOLLOW:
                    int u = urban == null ? SAME : urban.Meaning;
                    return u == SAME ? "Intensification takes urbanization's multiplier, which is 1 now (urbanization is the same as the reference period)."
                         : u == POP ? "Intensification follows urbanization's population growth, divided by the land per new resident: compact growth intensifies more."
                         : "Intensification takes urbanization's multiplier, unit by unit and year by year.";
                default: return "Each year repeats a year drawn from the reference period, unchanged (" + what + " at the historical rate).";
            }
        }

        // ---- the chart ----------------------------------------------------------------------------------------------------------
        private static MultiplierChart.Line Flat(int x0, int x1) { return new MultiplierChart.Line { X = new double[] { x0, x1 }, Y = new double[] { 1, 1 }, Bold = true }; }

        private void Chart(int m, List<DataRow> rows, DemandCard urban)
        {
            ResultRatios res = H.Result(); int end = H.EndYear();
            int start = res != null && res.FirstYear > 0 ? res.FirstYear - 1 : 2020;
            if (m == SAME || (m == FOLLOW && (urban == null || urban.Meaning == SAME)))
            { m_chart.Set(new List<MultiplierChart.Line> { Flat(start, Math.Max(end, start + 1)) }, null, null, null, "Multiplier 1 throughout."); return; }
            if (m == CUSTOM)
            {
                var lines = new List<MultiplierChart.Line>();
                foreach (var g in rows.Where(r => r["Year"] != DBNull.Value && r["Ratio"] != DBNull.Value).GroupBy(r => Txt(r["UnitId"])))
                {
                    var pts = g.Select(r => new KeyValuePair<double, double>(Convert.ToDouble(r["Year"]), Convert.ToDouble(r["Ratio"]))).OrderBy(p => p.Key).ToList();
                    if (pts[0].Key > start) pts.Insert(0, new KeyValuePair<double, double>(start, 1));
                    if (pts[pts.Count - 1].Key < end) pts.Add(new KeyValuePair<double, double>(end, pts[pts.Count - 1].Value));
                    lines.Add(new MultiplierChart.Line { X = pts.Select(p => p.Key).ToArray(), Y = pts.Select(p => p.Value).ToArray(), Bold = g.Key.Length == 0 });
                }
                if (lines.Count == 0) m_chart.Say("No multipliers entered yet.");
                else m_chart.Set(lines, null, null, null, lines.Count == 1 ? "As entered." : string.Format("As entered: {0} lines, one per unit{1}.", lines.Count, lines.Any(l => l.Bold) ? " (bold: everywhere)" : ""));
                return;
            }
            if (res == null) { m_chart.Say("The multipliers come from the data when stage 9 runs. Run this scenario to see them here."); return; }
            if (!res.Self && !res.Same(H.Get, S.Columns)) { m_chart.Say(string.Format("These settings differ from result [{0}]. Run this scenario to see the new multipliers.", res.Id)); return; }
            double[] x, mean, lo, hi;
            if (!res.Series(S.Prefix, out x, out mean, out lo, out hi)) { m_chart.Say(string.Format("Result [{0}] has no multipliers for this kind.", res.Id)); return; }
            int n = x.Length - 1;
            m_chart.Set(new List<MultiplierChart.Line> { new MultiplierChart.Line { X = x, Y = mean, Bold = true } }, x, lo, hi,
                string.Format("{0}: mean x{1:0.00} by {2:0}; units x{3:0.00} to x{4:0.00}.", res.Self ? "This result" : "Result [" + res.Id + "]", mean[n], x[n], lo[n], hi[n]));
        }

        // ---- the custom table, in the card ---------------------------------------------------------------------------------------
        private void ShowRows(List<DataRow> rows)
        {
            string shape = string.Join(",", rows.Select(r => System.Runtime.CompilerServices.RuntimeHelpers.GetHashCode(r).ToString()));
            if (shape != m_shape)
            {
                m_shape = shape; m_rows.SuspendLayout();
                foreach (Control c in m_rows.Controls.Cast<Control>().ToList()) c.Dispose();
                m_rows.Controls.Clear(); m_lines.Clear();
                foreach (DataRow r in rows.OrderBy(v => v["UnitId"] == DBNull.Value ? "" : Where(v), StringComparer.CurrentCultureIgnoreCase).ThenBy(v => v["Year"] == DBNull.Value ? 0 : Convert.ToInt32(v["Year"])))
                {
                    var l = new RowLine { Row = r, Year = Box(52), Mult = Box(52) }; DataRow row = r;
                    var where = new Label { Text = Where(r), AutoSize = false, AutoEllipsis = true, Size = new Size(250, 22), Margin = new Padding(3, 6, 6, 0), Tag = Fit.Fixed };
                    var remove = new Button { Text = "Remove", AutoSize = true, Margin = new Padding(3, 2, 3, 3) };
                    remove.Click += (s, e) => { if (H.Refreshing()) return; H.Ratios().DeleteRows(new List<DataRow> { row }); H.Refresh(); };
                    l.Year.Validated += (s, e) => Edit(row, "Year", l.Year.Text, true);
                    l.Mult.Validated += (s, e) => Edit(row, "Ratio", l.Mult.Text, false);
                    m_rows.Controls.Add(Flow(where, Small("year"), l.Year, Small("multiplier"), l.Mult, remove)); m_lines.Add(l);
                }
                if (rows.Count == 0) m_rows.Controls.Add(Small("(none yet)"));
                m_rows.ResumeLayout(true);
            }
            foreach (RowLine l in m_lines)
            {
                if (!l.Year.Focused) l.Year.Text = Txt(l.Row["Year"]);
                if (!l.Mult.Focused) l.Mult.Text = Txt(l.Row["Ratio"]);
            }
        }

        private void Edit(DataRow row, string column, string text, bool year)
        {
            if (H.Refreshing() || row.RowState == DataRowState.Deleted || row.RowState == DataRowState.Detached) return;
            double d; string v = text.Trim();
            bool ok = double.TryParse(v, out d) && (year ? d > 0 && d == Math.Floor(d) : d >= 0);
            if (ok && Txt(row[column]) != Txt(year ? (object)Convert.ToInt32(d) : d))
            {
                DataSheet ds = H.Ratios(); ds.BeginModifyRows(); try { row[column] = year ? (object)Convert.ToInt32(d) : d; } finally { ds.EndModifyRows(); }
            }
            H.Refresh();
        }

        private void AddRow()
        {
            if (H.Refreshing()) return;
            double y, r; m_addSaid.ForeColor = Color.Firebrick;
            if (!double.TryParse(m_year.Text.Trim(), out y) || y <= 0 || y != Math.Floor(y)) { m_addSaid.Text = "Enter a year."; return; }
            if (!double.TryParse(m_mult.Text.Trim(), out r) || r < 0) { m_addSaid.Text = "Enter a multiplier (1 = the reference rate)."; return; }
            object unit = DBNull.Value;
            if (m_kind.SelectedItem is UnitCatalog.Source)
            {
                var u = m_unit.SelectedItem as UnitCatalog.Unit;
                if (u == null) { string t = m_unit.Text.Trim(); u = m_unit.Items.Cast<UnitCatalog.Unit>().FirstOrDefault(x => string.Equals(x.Short, t, StringComparison.CurrentCultureIgnoreCase)); }
                if (u == null) { m_addSaid.Text = "Pick a unit, or choose Everywhere."; return; }
                unit = u.Key;
            }
            if (Rows().Any(x => Txt(x["UnitId"]) == Txt(unit) && Txt(x["Year"]) == Convert.ToInt32(y).ToString())) { m_addSaid.Text = "That unit already has a row for " + Convert.ToInt32(y) + "."; return; }
            DataSheet ds = H.Ratios(); DataTable dt = ds.GetData();
            ds.BeginAddRows();
            DataRow row = dt.NewRow(); row["AppliesTo"] = S.AppliesTo; row["UnitId"] = unit; row["Year"] = Convert.ToInt32(y); row["Ratio"] = r;
            dt.Rows.Add(row);
            ds.EndAddRows();
            m_addSaid.Text = ""; m_year.Text = ""; m_mult.Text = "";
            H.Refresh(); m_year.Focus();
        }
    }
}
