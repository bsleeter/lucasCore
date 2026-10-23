// =============================================================================
// UnitPicker.cs - pick a kind of unit (radio buttons from Stratum Sources), then units of that kind (type-ahead drop-down + list)
// =============================================================================
// Shared by the Study Area page and the Suitability Fitting Region on the Spatial Allocation page. The host gives the multi-row
// sheet of units (UnitId = a stsim_SecondaryStratum row) and where the chosen kind is saved (a StratumSource key in a single-row
// sheet column), loads the lists when its feed loads and calls ShowData from its RefreshControls. A unit's source is its universal
// Id / 100,000,000 (src/strata.R, UNIT_OFFSET).
// =============================================================================
using System;
using System.Collections.Generic;
using System.Data;
using System.Drawing;
using System.Linq;
using System.Windows.Forms;
using SyncroSim.Core;

namespace lucasCoreUI
{
    public class UnitPicker : UserControl
    {
        private const string UNITS = "stsim_SecondaryStratum";
        private const string SOURCES = "lucasCore_StratumSource";
        private const double OFFSET = 1e8;

        private class Source { public int Key; public int Number; public string Name; }
        private class Unit
        {
            public int Key; public long Id; public string Name; public string Short;
            public override string ToString() { return Short; }
        }
        private class ListItem
        {
            public readonly Unit Unit; private readonly bool m_full;
            public ListItem(Unit u, bool full) { Unit = u; m_full = full; }
            public override string ToString() { return m_full ? Unit.Name : Unit.Short; }
        }

        // what the host supplies
        public Func<DataSheet> UnitSheet;            // the multi-row sheet of chosen units
        public Func<DataSheet> KindSheet;            // the single-row sheet that keeps the chosen kind
        public string KindColumn = "SourceId";
        public string AllText = "All of CONUS";      // the radio for "no units" (the whole of something)
        public string AllNote = "Choose a kind of unit above to limit it.";
        public string Subject = "Study area";        // for the summary line: "<Subject>: 3 units."
        public string AllSummary = "all of CONUS";   // ... and with no units: "<Subject>: all of CONUS."
        public string Confirm = "Study Area";        // message box title
        public Action Changed;                       // after the host's sheets change
        public Func<DataRow, bool> RowFilter = r => true;   // the rows this picker shows and edits (e.g. one surface's)
        public Action<DataRow> NewRow = r => { };           // fills the other columns of a row it adds

        private readonly FlowLayoutPanel m_radios = new FlowLayoutPanel();
        private readonly ComboBox m_unitBox = new ComboBox();
        private readonly Button m_add = new Button();
        private readonly ListBox m_list = new ListBox();
        private readonly Button m_remove = new Button();
        private readonly Label m_unitsLabel = new Label();
        private readonly Label m_summary = new Label();
        private readonly GroupBox m_gbUnits = new GroupBox();

        private List<Source> m_sources = new List<Source>();
        private Dictionary<int, Unit> m_unitsByKey = new Dictionary<int, Unit>();
        private int m_current = -1;
        private bool m_refreshing;

        public UnitPicker(string kindTitle, int listHeight)
        {
            var root = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 1, RowCount = 3 };
            root.RowStyles.Add(new RowStyle(SizeType.AutoSize));
            root.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
            root.RowStyles.Add(new RowStyle(SizeType.AutoSize));

            var gbKind = new GroupBox { Text = kindTitle, Dock = DockStyle.Top, AutoSize = true, Padding = new Padding(10, 6, 10, 8) };
            m_radios.Dock = DockStyle.Fill; m_radios.AutoSize = true; m_radios.WrapContents = true; m_radios.FlowDirection = FlowDirection.LeftToRight;
            gbKind.Controls.Add(m_radios);

            m_gbUnits.Text = "Units"; m_gbUnits.Dock = DockStyle.Fill; m_gbUnits.Padding = new Padding(10, 6, 10, 8);
            var grid = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 2, RowCount = 3 };
            grid.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
            grid.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));
            grid.RowStyles.Add(new RowStyle(SizeType.AutoSize));
            grid.RowStyles.Add(new RowStyle(SizeType.AutoSize));
            grid.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
            m_unitsLabel.AutoSize = true; m_unitsLabel.Margin = new Padding(3, 3, 3, 6);
            grid.Controls.Add(m_unitsLabel, 0, 0); grid.SetColumnSpan(m_unitsLabel, 2);
            m_unitBox.Dock = DockStyle.Fill; m_unitBox.DropDownStyle = ComboBoxStyle.DropDown;
            m_unitBox.AutoCompleteMode = AutoCompleteMode.SuggestAppend; m_unitBox.AutoCompleteSource = AutoCompleteSource.ListItems;
            m_unitBox.MaxDropDownItems = 20;
            m_unitBox.KeyDown += (s, e) => { if (e.KeyCode == Keys.Enter) { AddSelected(); e.SuppressKeyPress = true; } };
            m_add.Text = "Add"; m_add.AutoSize = true; m_add.Click += (s, e) => AddSelected();
            grid.Controls.Add(m_unitBox, 0, 1); grid.Controls.Add(m_add, 1, 1);
            m_list.Dock = DockStyle.Fill; m_list.IntegralHeight = false; m_list.SelectionMode = SelectionMode.MultiExtended; m_list.MinimumSize = new Size(0, listHeight);
            m_list.KeyDown += (s, e) => { if (e.KeyCode == Keys.Delete) RemoveSelected(); };
            m_remove.Text = "Remove"; m_remove.AutoSize = true; m_remove.Anchor = AnchorStyles.Top; m_remove.Click += (s, e) => RemoveSelected();
            grid.Controls.Add(m_list, 0, 2); grid.Controls.Add(m_remove, 1, 2);
            m_gbUnits.Controls.Add(grid);

            m_summary.AutoSize = true; m_summary.ForeColor = SystemColors.GrayText; m_summary.Margin = new Padding(3, 6, 3, 3);
            root.Controls.Add(gbKind, 0, 0); root.Controls.Add(m_gbUnits, 0, 1); root.Controls.Add(m_summary, 0, 2);
            this.Controls.Add(root);
        }

        public bool IsRefreshing { get { return m_refreshing; } }

        private static IEnumerable<DataRow> Live(DataTable dt) { return dt.Rows.Cast<DataRow>().Where(r => r.RowState != DataRowState.Deleted); }

        // the kinds of unit (Stratum Sources, by Number) and every unit with its source taken from its universal Id
        public void LoadLists(Project p)
        {
            m_sources = new List<Source>();
            m_unitsByKey = new Dictionary<int, Unit>();
            foreach (DataRow r in Live(p.GetDataSheet(SOURCES).GetData()))
            {
                if (r["Number"] == DBNull.Value) continue;
                m_sources.Add(new Source { Key = Convert.ToInt32(r["StratumSourceId"]), Number = Convert.ToInt32(r["Number"]), Name = Convert.ToString(r["Name"]) });
            }
            m_sources = m_sources.OrderBy(s => s.Number).ToList();
            foreach (DataRow r in Live(p.GetDataSheet(UNITS).GetData()))
            {
                if (r["ID"] == DBNull.Value) continue;
                var unit = new Unit { Key = Convert.ToInt32(r["SecondaryStratumId"]), Id = Convert.ToInt64(r["ID"]), Name = Convert.ToString(r["Name"]) };
                int colon = unit.Name.IndexOf(": ", StringComparison.Ordinal);
                unit.Short = colon >= 0 ? unit.Name.Substring(colon + 2) : unit.Name;
                m_unitsByKey[unit.Key] = unit;
            }
            m_refreshing = true;
            m_radios.Controls.Clear();
            m_radios.Controls.Add(MakeRadio(AllText, 0));
            foreach (Source s in m_sources) m_radios.Controls.Add(MakeRadio(s.Name, s.Number));
            m_refreshing = false;
        }

        private RadioButton MakeRadio(string text, int number)
        {
            var rb = new RadioButton { Text = text, Tag = number, AutoSize = true, Margin = new Padding(3, 3, 18, 3) };
            rb.CheckedChanged += OnRadioChanged;
            return rb;
        }

        private static int SourceOf(Unit u) { return (int)Math.Floor(u.Id / OFFSET); }

        private int SavedKind()
        {
            DataSheet o = KindSheet();
            if (!o.HasData()) return 0;
            DataRow r = o.GetDataRow();
            if (r == null || r[KindColumn] == DBNull.Value) return 0;
            int key = Convert.ToInt32(r[KindColumn]);
            Source s = m_sources.FirstOrDefault(x => x.Key == key);
            return s == null ? 0 : s.Number;
        }

        private void SaveKind(int number)
        {
            if (SavedKind() == number) return;
            Source s = m_sources.FirstOrDefault(x => x.Number == number);
            KindSheet().SetSingleRowData(KindColumn, s == null ? (object)DBNull.Value : s.Key);
        }

        private List<Unit> SelectedUnits()
        {
            var res = new List<Unit>();
            foreach (DataRow r in Live(UnitSheet().GetData()).Where(RowFilter))
            {
                if (r["UnitId"] == DBNull.Value) continue;
                Unit u; if (m_unitsByKey.TryGetValue(Convert.ToInt32(r["UnitId"]), out u)) res.Add(u);
            }
            return res;
        }

        public void ShowData(bool editable)
        {
            m_refreshing = true;
            try
            {
                List<Unit> sel = SelectedUnits();
                List<int> kinds = sel.Select(SourceOf).Distinct().ToList();
                // the chosen kind follows the units when there are any, else the saved kind
                m_current = sel.Count > 0 ? kinds[0] : SavedKind();
                foreach (RadioButton rb in m_radios.Controls.OfType<RadioButton>()) rb.Checked = (int)rb.Tag == m_current;

                Source s = m_sources.FirstOrDefault(x => x.Number == m_current);
                bool all = m_current == 0 || s == null;
                m_gbUnits.Enabled = !all;
                m_gbUnits.Text = all ? "Units" : s.Name;
                m_unitsLabel.Text = all ? AllText + ". " + AllNote : "Type or pick a unit and press Add.";
                m_unitBox.BeginUpdate();
                m_unitBox.Items.Clear();
                if (!all)
                {
                    HashSet<int> have = new HashSet<int>(sel.Select(x => x.Key));
                    foreach (Unit u in m_unitsByKey.Values.Where(x => SourceOf(x) == m_current && !have.Contains(x.Key)).OrderBy(x => x.Short, StringComparer.CurrentCultureIgnoreCase))
                        m_unitBox.Items.Add(u);
                }
                m_unitBox.EndUpdate();
                m_unitBox.Text = "";
                m_list.BeginUpdate();
                m_list.Items.Clear();
                foreach (Unit u in sel.OrderBy(x => x.Name, StringComparer.CurrentCultureIgnoreCase)) m_list.Items.Add(new ListItem(u, kinds.Count > 1));
                m_list.EndUpdate();
                m_summary.Text = sel.Count == 0 ? Subject + ": " + AllSummary + "."
                    : kinds.Count > 1 ? string.Format("{0}: {1} units of {2} kinds (choose one kind to tidy it up).", Subject, sel.Count, kinds.Count)
                    : string.Format("{0}: {1} {2}.", Subject, sel.Count, sel.Count == 1 ? "unit" : "units");
                m_radios.Enabled = editable; m_add.Enabled = editable; m_remove.Enabled = editable; m_unitBox.Enabled = editable;
            }
            finally { m_refreshing = false; }
        }

        private void OnRadioChanged(object sender, EventArgs e)
        {
            var rb = (RadioButton)sender;
            if (m_refreshing || !rb.Checked) return;
            int number = (int)rb.Tag;
            if (number == m_current) return;
            List<Unit> sel = SelectedUnits();
            if (sel.Count > 0)
            {
                string msg = string.Format("Changing the kind of unit removes the {0} unit{1} already chosen. Continue?", sel.Count, sel.Count == 1 ? "" : "s");
                if (MessageBox.Show(this, msg, Confirm, MessageBoxButtons.OKCancel, MessageBoxIcon.Question) != DialogResult.OK) { Changed(); return; }
                DataSheet ds = UnitSheet(); ds.DeleteRows(Live(ds.GetData()).Where(RowFilter).ToList());
            }
            m_current = number;
            SaveKind(number);
            Changed();
        }

        private void AddSelected()
        {
            Unit u = m_unitBox.SelectedItem as Unit;
            if (u == null)
            {
                string t = m_unitBox.Text.Trim();
                u = m_unitBox.Items.Cast<Unit>().FirstOrDefault(x => string.Equals(x.Short, t, StringComparison.CurrentCultureIgnoreCase));
            }
            if (u == null) return;
            DataSheet ds = UnitSheet(); DataTable dt = ds.GetData();
            if (Live(dt).Where(RowFilter).Any(r => r["UnitId"] != DBNull.Value && Convert.ToInt32(r["UnitId"]) == u.Key)) return;
            ds.BeginAddRows();
            DataRow row = dt.NewRow();
            row["UnitId"] = u.Key; NewRow(row);
            dt.Rows.Add(row);
            ds.EndAddRows();
            Changed();
            m_unitBox.Focus();
        }

        private void RemoveSelected()
        {
            var keys = new HashSet<int>(m_list.SelectedItems.Cast<ListItem>().Select(x => x.Unit.Key));
            if (keys.Count == 0) return;
            DataSheet ds = UnitSheet();
            ds.DeleteRows(Live(ds.GetData()).Where(RowFilter).Where(r => r["UnitId"] != DBNull.Value && keys.Contains(Convert.ToInt32(r["UnitId"]))).ToList());
            Changed();
        }
    }
}
