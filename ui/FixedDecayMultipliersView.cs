// =============================================================================
// FixedDecayMultipliersView.cs - Carbon Assumptions > Fixed Decay Multipliers: the decay multipliers the Build calibrated, and fixed ones
// =============================================================================
// Sheet lucasCore_FixedDecayMultiplier (Ecodivision, Forest Type, Pool, Multiplier). Stage 3 calibrates a multiplier of CBM's decay rate
// for each dead pool, ecodivision and forest type: to FIA's measured dead wood (FIA measured dead wood), or leaves 1 (CBM defaults). So
// the values exist only once a Build has run: the page lists the newest Build result's (Build Results > Decay Calibration) and marks the
// ones a row of this sheet fixes. A row applies at the most specific level it names (ecodivision + forest type, ecodivision, forest
// type, all); Forest floor stands for fine woody debris, litter and duff where they are not fixed themselves. "Fix the selected value"
// adds a row at the calibrated value, to edit in the rows table.
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
    public class FixedDecayMultipliersView : LucasView
    {
        protected override string SheetName { get { return "lucasCore_FixedDecayMultiplier"; } }

        // output column, heading, the sheet's Pool value
        private static readonly object[][] Pools = {
            new object[] { "SnagDecayMultiplier", "Snags", 1 }, new object[] { "DownWoodDecayMultiplier", "Down logs", 2 },
            new object[] { "FineWoodyDecayMultiplier", "Fine woody debris", 3 }, new object[] { "LitterDecayMultiplier", "Litter", 4 },
            new object[] { "DuffDecayMultiplier", "Duff", 5 }, new object[] { "ForestFloorDecayMultiplier", "Forest floor", 6 },
            new object[] { "SoilDecayMultiplier", "Soil", 7 } };

        private readonly DataGridView m_grid = new DataGridView
        {
            Height = 360, Dock = DockStyle.Top, ReadOnly = true, AllowUserToAddRows = false, AllowUserToDeleteRows = false, AllowUserToResizeRows = false,
            RowHeadersVisible = false, SelectionMode = DataGridViewSelectionMode.CellSelect, MultiSelect = false, BackgroundColor = SystemColors.Window,
            BorderStyle = BorderStyle.FixedSingle, AutoSizeColumnsMode = DataGridViewAutoSizeColumnsMode.Fill, ShowCellToolTips = true
        };
        private readonly Label m_source = new Label { AutoSize = true, MaximumSize = new Size(640, 0), Margin = new Padding(3, 6, 3, 6), Font = new Font(SystemFonts.MessageBoxFont, FontStyle.Bold) };
        private readonly Button m_fix = new Button { Text = "Fix the selected value", AutoSize = true, Margin = new Padding(3, 3, 12, 3) };
        private readonly Label m_state = new Label { AutoSize = true, MaximumSize = new Size(640, 0), ForeColor = SystemColors.GrayText, Margin = new Padding(3, 8, 3, 3) };
        private readonly Panel m_rows = GridHost(220);
        private static readonly Color FixedColour = Color.FromArgb(255, 236, 200);
        private string m_note = "";

        public FixedDecayMultipliersView()
        {
            this.SuspendLayout();
            m_grid.Columns.Add(new DataGridViewTextBoxColumn { Name = "Eco", HeaderText = "Ecodivision", FillWeight = 90 });
            m_grid.Columns.Add(new DataGridViewTextBoxColumn { Name = "Type", HeaderText = "Forest type", FillWeight = 130 });
            m_grid.Columns.Add(new DataGridViewTextBoxColumn { Name = "Level", HeaderText = "Fitted at", FillWeight = 70 });
            m_grid.Columns.Add(new DataGridViewTextBoxColumn { Name = "Plots", HeaderText = "FIA plots", FillWeight = 40, DefaultCellStyle = { Alignment = DataGridViewContentAlignment.MiddleRight } });
            foreach (object[] p in Pools) m_grid.Columns.Add(new DataGridViewTextBoxColumn { Name = (string)p[0], HeaderText = (string)p[1], FillWeight = 50, DefaultCellStyle = { Alignment = DataGridViewContentAlignment.MiddleRight } });
            foreach (DataGridViewColumn c in m_grid.Columns) c.SortMode = DataGridViewColumnSortMode.NotSortable;
            var r = Row(); r.Controls.Add(m_fix); r.Controls.Add(m_state);
            AddGroup(Group("Decay multipliers (stage 3)", ProjectionTransitionsView.Stack(
                Note("Each dead pool decays at CBM-CFS3's rate for its temperature times a multiplier. The Build calibrates the multipliers (stage 3): with FIA measured dead wood, so that each ecodivision and forest type's snags, down logs, fine woody debris, litter and duff match FIA's measurements in mature stands, and soil matches gSSURGO; with CBM defaults they stay 1. So the values exist only once a Build has run."),
                Note("Empty page: every pool calibrated, as listed below. To fix a value instead, select it and press Fix the selected value, then edit the multiplier in the rows table. A fixed value is shaded; the pools fitted after it (snags, then down logs; fine woody debris, then litter, then duff; then soil) are fitted with it, so they change at the next Build."),
                m_source, m_grid, r)));
            var c2 = Column();
            c2.Controls.Add(Wrapped("Fixed multipliers. A row may leave the ecodivision or forest type blank to apply to all of them; the most specific row wins. Forest floor stands for fine woody debris, litter and duff together where they are not fixed themselves.", 720));
            c2.Controls.Add(m_rows);
            AddGroup(Group("Fixed values (rows)", c2));
            EndGroups();
            m_fix.Click += (s, e) => FixSelected();
            m_grid.SelectionChanged += (s, e) => { if (!Refreshing) m_fix.Enabled = CanFix(); };
            this.ResumeLayout(false);
        }

        public override void LoadDataFeed(DataFeed dataFeed)
        {
            base.LoadDataFeed(dataFeed);
            LoadGrid(m_rows, SheetName);
            RefreshControls();
        }

        private bool Editable { get { return !(this.Scenario != null && this.Scenario.IsResult) && this.ShouldEnableView(); } }

        private bool CanFix()
        {
            DataGridViewCell c = m_grid.CurrentCell;
            return Editable && c != null && c.RowIndex >= 0 && Pools.Any(p => (string)p[0] == m_grid.Columns[c.ColumnIndex].Name) && Convert.ToString(c.Value).Length > 0;
        }

        // the row of this sheet that fixes a pool for an ecodivision and forest type: the most specific match, or null
        private static DataRow FixedRow(List<DataRow> rows, int eco, int type, int pool)
        {
            return rows.Where(r => r["Pool"] != DBNull.Value && Convert.ToInt32(r["Pool"]) == pool &&
                                   (r["StratumId"] == DBNull.Value || Convert.ToInt32(r["StratumId"]) == eco) && (r["StateClassId"] == DBNull.Value || Convert.ToInt32(r["StateClassId"]) == type))
                       .OrderByDescending(r => 2 * (r["StratumId"] == DBNull.Value ? 0 : 1) + (r["StateClassId"] == DBNull.Value ? 0 : 1)).FirstOrDefault();
        }

        private void FixSelected()
        {
            if (!CanFix()) return;
            DataGridViewCell c = m_grid.CurrentCell; var key = (int[])m_grid.Rows[c.RowIndex].Tag;
            object[] pool = Pools.First(p => (string)p[0] == m_grid.Columns[c.ColumnIndex].Name);
            double? v = CarbonPages.Parse(Convert.ToString(c.Value));
            DataTable dt = Sheet.GetData();
            DataRow have = CarbonPages.Rows(Sheet).FirstOrDefault(r => r["Pool"] != DBNull.Value && Convert.ToInt32(r["Pool"]) == (int)pool[2] && r["StratumId"] != DBNull.Value && Convert.ToInt32(r["StratumId"]) == key[0]
                                                                        && r["StateClassId"] != DBNull.Value && Convert.ToInt32(r["StateClassId"]) == key[1]);
            if (have != null) { m_note = "This value already has its own row: edit it in the rows table. "; RefreshControls(); return; }
            Sheet.BeginAddRows();
            try { DataRow nr = dt.NewRow(); nr["StratumId"] = key[0]; nr["StateClassId"] = key[1]; nr["Pool"] = (int)pool[2]; nr["Multiplier"] = v.HasValue ? v.Value : 1.0; dt.Rows.Add(nr); }
            finally { Sheet.EndAddRows(); }
            m_note = string.Format("Added a row fixing {0} at {1}, the calibrated value: edit it in the rows table. ", ((string)pool[1]).ToLower(), CarbonPages.Format(v, "0.000"));
            LoadGrid(m_rows, SheetName);
            RefreshControls();
        }

        protected override void ShowData()
        {
            Scenario res = CarbonPages.BuildResult(this.Scenario);
            List<DataRow> fitted = CarbonPages.ResultRows(res, "lucasCore_OutputDecayCalibration");
            Dictionary<int, string> ecoNames = CarbonPages.Names(Sheet, "StratumId"), typeNames = CarbonPages.Names(Sheet, "StateClassId");
            List<DataRow> rows = CarbonPages.Rows(Sheet);
            bool cbm = CarbonPages.Method(this.DataFeed) == 3;
            m_source.Text = fitted.Count == 0 ? "No Build result yet: run the Build to see the calibrated multipliers." + (cbm ? " With CBM defaults every multiplier is 1 unless fixed here." : "")
                : "Calibrated multipliers from the Build result " + CarbonPages.ResultName(res) + (cbm ? " (CBM defaults: 1 unless fixed)" : "") + ". A fixed value shows the row's multiplier; the Build result shows what it ran with.";
            m_grid.Rows.Clear();
            string n;
            foreach (DataRow f in fitted.Where(x => x["StratumId"] != DBNull.Value && x["StateClassId"] != DBNull.Value)
                                        .OrderBy(x => ecoNames.TryGetValue(Convert.ToInt32(x["StratumId"]), out n) ? n : "").ThenBy(x => typeNames.TryGetValue(Convert.ToInt32(x["StateClassId"]), out n) ? n : ""))
            {
                int eco = Convert.ToInt32(f["StratumId"]), type = Convert.ToInt32(f["StateClassId"]);
                var cells = new List<object> { ecoNames.TryGetValue(eco, out n) ? n : eco.ToString(), typeNames.TryGetValue(type, out n) ? n.Replace("Forest: ", "") : type.ToString(),
                                               Convert.ToString(f["Level"]), f["Plots"] == DBNull.Value ? "" : Convert.ToString(f["Plots"]) };
                var fix = new Dictionary<string, DataRow>();
                foreach (object[] p in Pools)
                {
                    DataRow fr = FixedRow(rows, eco, type, (int)p[2]);
                    // forest floor stands for fine woody debris, litter and duff where they are not fixed themselves
                    if (fr == null && ((int)p[2] == 3 || (int)p[2] == 4 || (int)p[2] == 5)) fr = FixedRow(rows, eco, type, 6);
                    fix[(string)p[0]] = fr;
                    cells.Add(fr != null && fr["Multiplier"] != DBNull.Value ? CarbonPages.Format(CarbonPages.Num(fr["Multiplier"]), "0.000") : CarbonPages.Format(CarbonPages.Num(f[(string)p[0]]), "0.000"));
                }
                int i = m_grid.Rows.Add(cells.ToArray());
                m_grid.Rows[i].Tag = new[] { eco, type };
                foreach (var kv in fix.Where(x => x.Value != null))
                {
                    DataGridViewCell c = m_grid.Rows[i].Cells[kv.Key]; c.Style.BackColor = FixedColour; c.Style.Font = new Font(m_grid.Font, FontStyle.Bold);
                    c.ToolTipText = string.Format("Fixed at {0} by the row for {1}, {2} (calibrated: {3})", CarbonPages.Format(CarbonPages.Num(kv.Value["Multiplier"]), "0.000"),
                        kv.Value["StratumId"] == DBNull.Value ? "all ecodivisions" : (ecoNames.TryGetValue(Convert.ToInt32(kv.Value["StratumId"]), out n) ? n : "?"),
                        kv.Value["StateClassId"] == DBNull.Value ? "all forest types" : (typeNames.TryGetValue(Convert.ToInt32(kv.Value["StateClassId"]), out n) ? n.Replace("Forest: ", "") : "?"),
                        CarbonPages.Format(CarbonPages.Num(f[kv.Key]), "0.000"));
                }
            }
            m_fix.Enabled = CanFix();
            m_state.Text = m_note + (rows.Count == 0 ? "No fixed values: every pool is calibrated." : string.Format("{0} fixed value{1}.", rows.Count, rows.Count == 1 ? "" : "s"));
            m_note = "";
        }
    }
}
