// =============================================================================
// StudyAreaView.cs - the Study Area page: pick the kind of unit first (radio buttons), then the units of that kind (drop-down)
// =============================================================================
// Replaces the default grid of lucasCore_StudyArea, whose single drop-down listed all 6,221 units of every source. The sheet itself
// is unchanged (one row per unit, UnitId = a stsim_SecondaryStratum row), so stage 1 reads it as before. The kinds of unit are the
// rows of Stratum Sources (project sheet); a unit's source is its universal Id / 100,000,000 (src/strata.R, UNIT_OFFSET).
// Built by tools/build_ui.ps1 into lucasCoreUI.dll (C# 5, .NET Framework 4.8, against SyncroSim's own assemblies).
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
    public class StudyAreaView : DataFeedView
    {
        private const string SHEET = "lucasCore_StudyArea";
        private const string OPTIONS = "lucasCore_StudyAreaOptions";   // single row: SourceId, the kind chosen (blank = all of CONUS)
        private const string UNITS = "stsim_SecondaryStratum";
        private const string SOURCES = "lucasCore_StratumSource";
        private const double OFFSET = 1e8;

        private class Source { public int Key; public int Number; public string Name; public string Prefix; }
        private class Unit
        {
            public int Key; public long Id; public string Name; public string Short;
            public override string ToString() { return Short; }
        }

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
        private int m_current = -1;          // Number of the chosen source; 0 = all of CONUS, -1 = not chosen
        private bool m_refreshing;

        public StudyAreaView() { BuildUi(); }

        private void BuildUi()
        {
            this.SuspendLayout();
            var root = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 1, RowCount = 3, Padding = new Padding(8), AutoScroll = true };
            root.RowStyles.Add(new RowStyle(SizeType.AutoSize));
            root.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
            root.RowStyles.Add(new RowStyle(SizeType.AutoSize));

            var gbKind = new GroupBox { Text = "Define the study area by", Dock = DockStyle.Top, AutoSize = true, Padding = new Padding(10, 6, 10, 8) };
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
            m_list.Dock = DockStyle.Fill; m_list.IntegralHeight = false; m_list.SelectionMode = SelectionMode.MultiExtended; m_list.MinimumSize = new Size(0, 120);
            m_list.KeyDown += (s, e) => { if (e.KeyCode == Keys.Delete) RemoveSelected(); };
            m_remove.Text = "Remove"; m_remove.AutoSize = true; m_remove.Anchor = AnchorStyles.Top; m_remove.Click += (s, e) => RemoveSelected();
            grid.Controls.Add(m_list, 0, 2); grid.Controls.Add(m_remove, 1, 2);
            m_gbUnits.Controls.Add(grid);

            m_summary.AutoSize = true; m_summary.ForeColor = SystemColors.GrayText; m_summary.Margin = new Padding(3, 6, 3, 3);

            root.Controls.Add(gbKind, 0, 0); root.Controls.Add(m_gbUnits, 0, 1); root.Controls.Add(m_summary, 0, 2);
            this.Controls.Add(root);
            this.ResumeLayout(false);
        }

        public override void LoadDataFeed(DataFeed dataFeed)
        {
            base.LoadDataFeed(dataFeed);
            // the lists are read when the page opens: SyncroSim's sheet monitors read a single row, so they cannot watch multi-row lists
            LoadLists();
            RefreshControls();
        }

        private DataSheet Sheet { get { return this.DataFeed.GetDataSheet(SHEET); } }
        private DataSheet Options { get { return this.DataFeed.GetDataSheet(OPTIONS); } }

        // the kind saved in Study Area Type (its Stratum Sources Number), 0 when blank
        private int SavedKind()
        {
            DataSheet o = Options;
            if (!o.HasData()) return 0;
            DataRow r = o.GetDataRow();
            if (r == null || r["SourceId"] == DBNull.Value) return 0;
            int key = Convert.ToInt32(r["SourceId"]);
            Source s = m_sources.FirstOrDefault(x => x.Key == key);
            return s == null ? 0 : s.Number;
        }

        private void SaveKind(int number)
        {
            Source s = m_sources.FirstOrDefault(x => x.Number == number);
            object v = s == null ? (object)DBNull.Value : s.Key;
            if (SavedKind() == number) return;
            Options.SetSingleRowData("SourceId", v);
        }

        private static IEnumerable<DataRow> Live(DataTable dt) { return dt.Rows.Cast<DataRow>().Where(r => r.RowState != DataRowState.Deleted); }

        // the kinds of unit (Stratum Sources, by Number) and every unit with its source taken from its universal Id
        private void LoadLists()
        {
            m_sources = new List<Source>();
            m_unitsByKey = new Dictionary<int, Unit>();
            Project p = this.DataFeed.Project;
            DataTable src = p.GetDataSheet(SOURCES).GetData();
            foreach (DataRow r in Live(src))
            {
                if (r["Number"] == DBNull.Value) continue;
                m_sources.Add(new Source { Key = Convert.ToInt32(r["StratumSourceId"]), Number = Convert.ToInt32(r["Number"]), Name = Convert.ToString(r["Name"]),
                    Prefix = r["Prefix"] == DBNull.Value ? null : Convert.ToString(r["Prefix"]) });
            }
            m_sources = m_sources.OrderBy(s => s.Number).ToList();
            DataTable u = p.GetDataSheet(UNITS).GetData();
            foreach (DataRow r in Live(u))
            {
                if (r["ID"] == DBNull.Value) continue;
                var unit = new Unit { Key = Convert.ToInt32(r["SecondaryStratumId"]), Id = Convert.ToInt64(r["ID"]), Name = Convert.ToString(r["Name"]) };
                int colon = unit.Name.IndexOf(": ", StringComparison.Ordinal);
                unit.Short = colon >= 0 ? unit.Name.Substring(colon + 2) : unit.Name;
                m_unitsByKey[unit.Key] = unit;
            }
            m_refreshing = true;
            m_radios.Controls.Clear();
            m_radios.Controls.Add(MakeRadio("All of CONUS", 0));
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

        private List<Unit> SelectedUnits()
        {
            var res = new List<Unit>();
            foreach (DataRow r in Live(Sheet.GetData()))
            {
                if (r["UnitId"] == DBNull.Value) continue;
                Unit u; if (m_unitsByKey.TryGetValue(Convert.ToInt32(r["UnitId"]), out u)) res.Add(u);
            }
            return res;
        }

        public override void RefreshControls()
        {
            base.RefreshControls();
            if (this.DataFeed == null) return;
            m_refreshing = true;
            try
            {
                List<Unit> sel = SelectedUnits();
                List<int> kinds = sel.Select(SourceOf).Distinct().ToList();
                // the chosen kind follows the units when there are any, else the saved Study Area Type
                m_current = sel.Count > 0 ? kinds[0] : SavedKind();
                foreach (RadioButton rb in m_radios.Controls.OfType<RadioButton>()) rb.Checked = (int)rb.Tag == m_current;

                Source s = m_sources.FirstOrDefault(x => x.Number == m_current);
                bool all = m_current == 0 || s == null;
                m_gbUnits.Enabled = !all;
                m_gbUnits.Text = all ? "Units" : s.Name;
                m_unitsLabel.Text = all ? "The study area is all of CONUS. Choose a kind of unit above to limit it."
                                        : "Type or pick a unit and press Add. The study area is all the units listed here.";
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
                m_summary.Text = sel.Count == 0 ? "Study area: all of CONUS."
                    : kinds.Count > 1 ? string.Format("Study area: {0} units of {1} kinds (made before this page; choose one kind to tidy it up).", sel.Count, kinds.Count)
                    : string.Format("Study area: {0} {1}.", sel.Count, sel.Count == 1 ? "unit" : "units");
                bool editable = !(this.Scenario != null && this.Scenario.IsResult);
                m_radios.Enabled = editable; m_add.Enabled = editable; m_remove.Enabled = editable; m_unitBox.Enabled = editable;
            }
            finally { m_refreshing = false; }
        }

        private class ListItem
        {
            public readonly Unit Unit; private readonly bool m_full;
            public ListItem(Unit u, bool full) { Unit = u; m_full = full; }
            public override string ToString() { return m_full ? Unit.Name : Unit.Short; }
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
                if (MessageBox.Show(this, msg, "Study Area", MessageBoxButtons.OKCancel, MessageBoxIcon.Question) != DialogResult.OK)
                {
                    RefreshControls();
                    return;
                }
                DeleteAll();
            }
            m_current = number;
            SaveKind(number);
            RefreshControls();
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
            DataSheet ds = Sheet; DataTable dt = ds.GetData();
            if (Live(dt).Any(r => r["UnitId"] != DBNull.Value && Convert.ToInt32(r["UnitId"]) == u.Key)) return;
            ds.BeginAddRows();
            DataRow row = dt.NewRow();
            row["UnitId"] = u.Key;
            dt.Rows.Add(row);
            ds.EndAddRows();
            RefreshControls();
            m_unitBox.Focus();
        }

        private void RemoveSelected()
        {
            var keys = new HashSet<int>(m_list.SelectedItems.Cast<ListItem>().Select(x => x.Unit.Key));
            if (keys.Count == 0) return;
            DataSheet ds = Sheet;
            List<DataRow> rows = Live(ds.GetData()).Where(r => r["UnitId"] != DBNull.Value && keys.Contains(Convert.ToInt32(r["UnitId"]))).ToList();
            ds.DeleteRows(rows);
            RefreshControls();
        }

        private void DeleteAll()
        {
            DataSheet ds = Sheet;
            List<DataRow> rows = Live(ds.GetData()).ToList();
            if (rows.Count > 0) ds.DeleteRows(rows);
        }

        protected override void OnRowsAdded(object sender, DataSheetRowEventArgs e) { base.OnRowsAdded(sender, e); if (!m_refreshing) RefreshControls(); }
        protected override void OnRowsDeleted(object sender, DataSheetRowEventArgs e) { base.OnRowsDeleted(sender, e); if (!m_refreshing) RefreshControls(); }
        protected override void OnRowsModified(object sender, DataSheetRowEventArgs e) { base.OnRowsModified(sender, e); if (!m_refreshing) RefreshControls(); }
    }
}
