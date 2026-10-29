// =============================================================================
// CarbonRatesView.cs - Build Results > Carbon Rates: the turnover and decay rates one forest cell runs with, and where each came from
// =============================================================================
// Output sheet lucasCore_OutputCarbonRate (stage 3, to-do 30), read only. Pick an ecodivision and a forest type from the drop-downs; the
// table lists every live turnover and dead organic matter flow of that cell in flow order: its yearly rate (exactly what the run uses),
// the pool's total loss, and for dead pools the base rate, the temperature effect at the cell's mean temperature and the decay
// multiplier, with the source of each. Stays enabled on result scenarios, where the rates are.
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
    public class CarbonRatesView : DataFeedView
    {
        private const string SHEET = "lucasCore_OutputCarbonRate";

        private class Item { public object Key; public string Name; public override string ToString() { return Name; } }

        private readonly ComboBox m_eco = new ComboBox { DropDownStyle = ComboBoxStyle.DropDownList, Width = 260, Margin = new Padding(3, 4, 14, 3) };
        private readonly ComboBox m_type = new ComboBox { DropDownStyle = ComboBoxStyle.DropDownList, Width = 340, Margin = new Padding(3, 4, 14, 3) };
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
            Text = "Rate: the yearly share of the From pool that moves to the To pool, exactly as the run uses it. Pool Total: all of that pool's yearly losses together. " +
                   "Dead pools: rate = base decay rate x temperature effect x decay multiplier x the share to that destination (decay to the next pool, the rest emitted); " +
                   "the temperature effect is Q10 ^ ((mean temperature - reference temperature) / 10), from Dead Organic Matter Parameters. A pool whose losses would pass its whole stock is capped at 1. " +
                   "Change the sources in Carbon Assumptions (CBM Crosswalk, Live Turnover, Dead Organic Matter Parameters, Fixed Decay Multipliers) and rerun the Build."
        };
        private DataTable m_rows;
        private Dictionary<string, Dictionary<object, string>> m_names = new Dictionary<string, Dictionary<object, string>>();

        public CarbonRatesView()
        {
            var bar = new FlowLayoutPanel { Dock = DockStyle.Fill, AutoSize = true, WrapContents = true, Padding = new Padding(4, 4, 4, 0) };
            bar.Controls.AddRange(new Control[] { Caption("Ecodivision"), m_eco, Caption("Forest type"), m_type, m_state });
            var t = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 1, RowCount = 3 };
            t.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
            t.RowStyles.Add(new RowStyle(SizeType.AutoSize)); t.RowStyles.Add(new RowStyle(SizeType.Percent, 100)); t.RowStyles.Add(new RowStyle(SizeType.Absolute, 78));
            t.Controls.Add(bar, 0, 0); t.Controls.Add(m_grid, 0, 1); t.Controls.Add(m_note, 0, 2);
            this.Controls.Add(t);
            m_eco.SelectedIndexChanged += (s, e) => ShowCell();
            m_type.SelectedIndexChanged += (s, e) => ShowCell();
        }

        private static Label Caption(string text) { return new Label { Text = text, AutoSize = true, Margin = new Padding(3, 8, 3, 3) }; }

        // SyncroSim disables a page on a result scenario; this one only reads, and the rates live in results
        public override bool ShouldEnableView() { return true; }
        public override void EnableView(bool enable) { base.EnableView(true); }

        public override void LoadDataFeed(DataFeed dataFeed)
        {
            base.LoadDataFeed(dataFeed);
            RefreshControls();
        }

        private static IEnumerable<DataRow> Live(DataTable dt) { return dt.Rows.Cast<DataRow>().Where(r => r.RowState != DataRowState.Deleted); }

        // id -> name of a lookup column (ecodivision, forest type, stock type)
        private static Dictionary<object, string> Names(DataSheet ds, string column)
        {
            var d = new Dictionary<object, string>();
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
            foreach (string c in new[] { "StratumId", "StateClassId", "FromStockTypeId", "ToStockTypeId" }) m_names[c] = Names(ds, c);
            object keepE = m_eco.SelectedItem is Item ? ((Item)m_eco.SelectedItem).Key : null, keepT = m_type.SelectedItem is Item ? ((Item)m_type.SelectedItem).Key : null;
            List<DataRow> rows = m_rows == null ? new List<DataRow>() : Live(m_rows).ToList();
            Fill(m_eco, rows.Select(r => r["StratumId"]).Distinct(), "StratumId", keepE);
            Fill(m_type, rows.Select(r => r["StateClassId"]).Distinct(), "StateClassId", keepT);
            m_eco.Enabled = m_type.Enabled = rows.Count > 0;
            if (rows.Count == 0) { m_state.Text = "No rates: run the Build (stage 3) first; the rates appear in its result."; m_grid.DataSource = null; }
            else ShowCell();
        }

        private void Fill(ComboBox cb, IEnumerable<object> ids, string column, object keep)
        {
            List<Item> items = ids.Where(i => i != DBNull.Value).Select(i => new Item { Key = i, Name = NameOf(column, i) }).OrderBy(i => i.Name).ToList();
            cb.BeginUpdate(); cb.Items.Clear(); foreach (Item i in items) cb.Items.Add(i); cb.EndUpdate();
            int k = keep == null ? -1 : items.FindIndex(i => Equals(Convert.ToString(i.Key), Convert.ToString(keep)));
            if (items.Count > 0) cb.SelectedIndex = k >= 0 ? k : 0;
        }

        private static object Num(object v, int digits) { return v == DBNull.Value ? (object)DBNull.Value : Math.Round(Convert.ToDouble(v), digits); }

        private void ShowCell()
        {
            if (m_rows == null || !(m_eco.SelectedItem is Item) || !(m_type.SelectedItem is Item)) return;
            string e = Convert.ToString(((Item)m_eco.SelectedItem).Key), s = Convert.ToString(((Item)m_type.SelectedItem).Key);
            List<DataRow> cell = Live(m_rows).Where(r => Convert.ToString(r["StratumId"]) == e && Convert.ToString(r["StateClassId"]) == s).ToList();
            var t = new DataTable();
            foreach (string c in new[] { "Process", "From Pool", "To Pool" }) t.Columns.Add(c, typeof(string));
            foreach (string c in new[] { "Rate (/yr)", "Pool Total (/yr)", "Base Rate (/yr)", "Temperature Effect", "Decay Multiplier" }) t.Columns.Add(c, typeof(double));
            t.Columns.Add("Source", typeof(string));
            var total = cell.GroupBy(r => Convert.ToString(r["FromStockTypeId"])).ToDictionary(g => g.Key, g => g.Sum(r => r["Rate"] == DBNull.Value ? 0 : Convert.ToDouble(r["Rate"])));
            foreach (DataRow r in cell)
                t.Rows.Add(Convert.ToString(r["Process"]), NameOf("FromStockTypeId", r["FromStockTypeId"]), NameOf("ToStockTypeId", r["ToStockTypeId"]), Num(r["Rate"], 5),
                           Math.Round(total[Convert.ToString(r["FromStockTypeId"])], 5), Num(r["BaseRate"], 4), Num(r["TemperatureEffect"], 3), Num(r["Multiplier"], 3), Convert.ToString(r["Source"]));
            m_grid.DataSource = t;
            foreach (DataGridViewColumn c in m_grid.Columns)
            {
                c.SortMode = DataGridViewColumnSortMode.NotSortable;
                if (c.ValueType == typeof(double)) { c.DefaultCellStyle.Alignment = DataGridViewContentAlignment.MiddleRight; c.DefaultCellStyle.Format = c.HeaderText.StartsWith("Rate") || c.HeaderText.StartsWith("Pool") ? "0.00000" : "0.000"; }
            }
            if (m_grid.Columns.Contains("Source")) m_grid.Columns["Source"].AutoSizeMode = DataGridViewAutoSizeColumnMode.Fill;
            object temp = cell.Count > 0 ? cell[0]["MeanTemperature"] : DBNull.Value;
            m_state.Text = cell.Count == 0 ? "No forest of this type in this ecodivision." :
                string.Format("{0} flows{1}", cell.Count, temp == DBNull.Value ? "" : string.Format("; mean annual temperature {0:0.0} C", Convert.ToDouble(temp)));
        }
    }
}
