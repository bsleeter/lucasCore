// =============================================================================
// SiteProductivityView.cs - Build Results > Site Productivity: the growth multiplier of every forest type by FIA site class, per ecodivision
// =============================================================================
// Output sheet lucasCore_OutputSiteProductivity (stage 2 when Build Options: Site Productivity = TreeMap site class; to-do 35), read
// only. Pick an ecodivision and what to show (multiplier, plots or raw ratio); the table has a row per forest type and a column per site
// class, with the type's plots and where its values came from (Basis). Multipliers are tinted: green above 1, orange below. Stays
// enabled on result scenarios, where the values are.
// =============================================================================
using System;
using System.Collections.Generic;
using System.Data;
using System.Drawing;
using System.Linq;
using System.Windows.Forms;
using SyncroSim.Core;
using SyncroSim.Core.Forms;

namespace lucasCoreUI
{
    public class SiteProductivityView : DataFeedView
    {
        private const string SHEET = "lucasCore_OutputSiteProductivity";
        private static readonly string[] CLASSES = { "1: 225+", "2: 165-224", "3: 120-164", "4: 85-119", "5: 50-84", "6: 20-49", "7: 0-19" };

        private class Item { public object Key; public string Name; public override string ToString() { return Name; } }

        private readonly ComboBox m_eco = new ComboBox { DropDownStyle = ComboBoxStyle.DropDownList, Width = 260, Margin = new Padding(3, 4, 14, 3) };
        private readonly ComboBox m_show = new ComboBox { DropDownStyle = ComboBoxStyle.DropDownList, Width = 200, Margin = new Padding(3, 4, 14, 3) };
        private readonly Label m_state = new Label { AutoSize = true, ForeColor = SystemColors.GrayText, Margin = new Padding(6, 8, 3, 3) };
        private readonly DataGridView m_grid = new DataGridView
        {
            Dock = DockStyle.Fill, ReadOnly = true, AllowUserToAddRows = false, AllowUserToDeleteRows = false, AllowUserToResizeRows = false,
            RowHeadersVisible = false, SelectionMode = DataGridViewSelectionMode.FullRowSelect, BackgroundColor = SystemColors.Window,
            AutoSizeColumnsMode = DataGridViewAutoSizeColumnsMode.DisplayedCells, BorderStyle = BorderStyle.None
        };
        private readonly Label m_note = new Label
        {
            Dock = DockStyle.Fill, AutoSize = false, ForeColor = SystemColors.GrayText, Padding = new Padding(4, 4, 4, 0),
            Text = "Site class: FIA's potential growth in cubic feet per acre per year (1 = most productive). Multiplier: how much faster that class's forest grows than the type's growth curve, " +
                   "from the plots' live carbon over the curve at their age, scaled so the type's plots average 1 and capped at 0.3-2.5. A class with few plots leans on the type's trend across classes; " +
                   "a forest type x ecodivision with under 30 plots uses the type's values from all ecodivisions (Basis). Raw Ratio: the plots' own mean before that. " +
                   "Stage 8 gives each forest cell the mix of its TreeMap site classes (Site Class Shares) and writes the result as the Site Productivity flow multiplier."
        };
        private DataTable m_rows;
        private Dictionary<string, Dictionary<int, string>> m_names = new Dictionary<string, Dictionary<int, string>>();

        public SiteProductivityView()
        {
            m_show.Items.AddRange(new object[] { "Multiplier", "Plots", "Raw Ratio" }); m_show.SelectedIndex = 0;
            var bar = new FlowLayoutPanel { Dock = DockStyle.Fill, AutoSize = true, WrapContents = true, Padding = new Padding(4, 4, 4, 0) };
            bar.Controls.AddRange(new Control[] { Caption("Ecodivision"), m_eco, Caption("Show"), m_show, m_state });
            var t = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 1, RowCount = 3 };
            t.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
            t.RowStyles.Add(new RowStyle(SizeType.AutoSize)); t.RowStyles.Add(new RowStyle(SizeType.Percent, 100)); t.RowStyles.Add(new RowStyle(SizeType.Absolute, 78));
            t.Controls.Add(bar, 0, 0); t.Controls.Add(m_grid, 0, 1); t.Controls.Add(m_note, 0, 2);
            this.Controls.Add(t);
            m_eco.SelectedIndexChanged += (s, e) => ShowEco();
            m_show.SelectedIndexChanged += (s, e) => ShowEco();
            m_grid.CellFormatting += Tint;
        }

        private static Label Caption(string text) { return new Label { Text = text, AutoSize = true, Margin = new Padding(3, 8, 3, 3) }; }

        // SyncroSim disables a page on a result scenario; this one only reads, and the values live in results
        public override bool ShouldEnableView() { return true; }
        public override void EnableView(bool enable) { base.EnableView(true); }

        public override void LoadDataFeed(DataFeed dataFeed)
        {
            base.LoadDataFeed(dataFeed);
            RefreshControls();
        }

        private static IEnumerable<DataRow> Live(DataTable dt) { return dt.Rows.Cast<DataRow>().Where(r => r.RowState != DataRowState.Deleted); }

        // id -> name of a lookup column (ecodivision, forest type)
        private static Dictionary<int, string> Names(DataSheet ds, string column)
        {
            var d = new Dictionary<int, string>();
            DataSheetColumn c = ds.Columns.Cast<DataSheetColumn>().FirstOrDefault(x => x.Name == column);
            if (c == null || c.ValidationTable == null) return d;
            foreach (DataRow r in Live(c.ValidationTable.DataSource)) { object k = r[c.ValidationTable.ValueMember]; if (k != DBNull.Value && !d.ContainsKey(Convert.ToInt32(k))) d[Convert.ToInt32(k)] = Convert.ToString(r[c.ValidationTable.DisplayMember]); }
            return d;
        }
        private string NameOf(string column, object id)
        {
            if (id == DBNull.Value) return "";
            string n; return m_names.ContainsKey(column) && m_names[column].TryGetValue(Convert.ToInt32(id), out n) ? n : Convert.ToString(id);
        }

        public override void RefreshControls()
        {
            base.RefreshControls();
            if (this.DataFeed == null) return;
            DataSheet ds = this.DataFeed.GetDataSheet(SHEET);
            m_rows = null;
            try { m_rows = ds.GetData(); } catch (Exception) { }
            foreach (string c in new[] { "StratumId", "StateClassId" }) m_names[c] = Names(ds, c);
            object keep = m_eco.SelectedItem is Item ? ((Item)m_eco.SelectedItem).Key : null;
            List<DataRow> rows = m_rows == null ? new List<DataRow>() : Live(m_rows).ToList();
            List<Item> items = rows.Select(r => r["StratumId"]).Where(i => i != DBNull.Value).Distinct().Select(i => new Item { Key = i, Name = NameOf("StratumId", i) }).OrderBy(i => i.Name).ToList();
            m_eco.BeginUpdate(); m_eco.Items.Clear(); foreach (Item i in items) m_eco.Items.Add(i); m_eco.EndUpdate();
            int k = keep == null ? -1 : items.FindIndex(i => Convert.ToString(i.Key) == Convert.ToString(keep));
            m_eco.Enabled = m_show.Enabled = rows.Count > 0;
            if (rows.Count == 0) { m_state.Text = "No site productivity: set Build Options > Site productivity to TreeMap site class and run the Build (stage 2)."; m_grid.DataSource = null; }
            else m_eco.SelectedIndex = k >= 0 ? k : 0;
        }

        private void ShowEco()
        {
            if (m_rows == null || !(m_eco.SelectedItem is Item)) return;
            string e = Convert.ToString(((Item)m_eco.SelectedItem).Key);
            string col = m_show.SelectedIndex == 1 ? "Plots" : m_show.SelectedIndex == 2 ? "RawRatio" : "Multiplier";
            var t = new DataTable();
            t.Columns.Add("Forest Type", typeof(string));
            foreach (string c in CLASSES) t.Columns.Add(c, col == "Plots" ? typeof(int) : typeof(double));
            t.Columns.Add("Plots", typeof(int)); t.Columns.Add("Basis", typeof(string));
            var types = Live(m_rows).Where(r => Convert.ToString(r["StratumId"]) == e).GroupBy(r => Convert.ToString(r["StateClassId"]))
                .Select(g => new { Name = NameOf("StateClassId", g.First()["StateClassId"]), Rows = g.ToList() }).OrderBy(g => g.Name);
            foreach (var g in types)
            {
                DataRow o = t.NewRow(); o["Forest Type"] = g.Name.Replace("Forest: ", "");
                foreach (DataRow r in g.Rows)
                {
                    int sc = r["SiteClass"] == DBNull.Value ? 0 : Convert.ToInt32(r["SiteClass"]);
                    if (sc >= 1 && sc <= 7 && r[col] != DBNull.Value) o[CLASSES[sc - 1]] = col == "Plots" ? (object)Convert.ToInt32(r[col]) : Math.Round(Convert.ToDouble(r[col]), 3);
                }
                o["Plots"] = g.Rows.Sum(r => r["Plots"] == DBNull.Value ? 0 : Convert.ToInt32(r["Plots"]));
                o["Basis"] = Convert.ToString(g.Rows[0]["Basis"]);
                t.Rows.Add(o);
            }
            m_grid.DataSource = t;
            foreach (DataGridViewColumn c in m_grid.Columns)
            {
                c.SortMode = DataGridViewColumnSortMode.NotSortable;
                if (c.ValueType == typeof(double) || c.ValueType == typeof(int)) { c.DefaultCellStyle.Alignment = DataGridViewContentAlignment.MiddleRight; if (c.ValueType == typeof(double)) c.DefaultCellStyle.Format = "0.000"; }
            }
            if (m_grid.Columns.Contains("Basis")) m_grid.Columns["Basis"].AutoSizeMode = DataGridViewAutoSizeColumnMode.Fill;
            m_state.Text = t.Rows.Count == 0 ? "No forest in this ecodivision." : string.Format("{0} forest types; site class columns in cubic feet per acre per year", t.Rows.Count);
        }

        // multipliers: green above 1, orange below, stronger the further from 1 (full at 0.5 and 1.5)
        private void Tint(object sender, DataGridViewCellFormattingEventArgs e)
        {
            if (m_show.SelectedIndex == 1 || e.ColumnIndex < 1 || e.ColumnIndex > 7 || e.Value == null || e.Value == DBNull.Value) return;
            double v = Convert.ToDouble(e.Value), a = Math.Min(1, Math.Abs(v - 1) / 0.5);
            Color to = v >= 1 ? Color.FromArgb(150, 210, 150) : Color.FromArgb(240, 180, 120);
            e.CellStyle.BackColor = Color.FromArgb((int)(255 + (to.R - 255) * a), (int)(255 + (to.G - 255) * a), (int)(255 + (to.B - 255) * a));
        }
    }
}
