// =============================================================================
// SpinupView.cs - Carbon Assumptions > Spin-up: the history each forest cell's starting carbon is spun up with, and its overrides
// =============================================================================
// Sheet lucasCore_Spinup (Ecodivision, Forest Type, Return Interval, Historical Clearcut Share, Last Disturbance Where No Fire Perimeter).
// The defaults come from the study area, so the Build works them out: stage 5 reads the LANDFIRE fire regime of every ecodivision and
// forest type (Build Results > Spin-up Return Intervals); every past cycle ends in high-severity fire; stage 8 starts a cell outside fire
// perimeters from a clearcut. The page lists the newest Build result's intervals (before any Build, the package's provisional ones) with
// this sheet's values beside them: an ecodivision row's value, else the forest type's all-ecodivisions row's, else the default.
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
    public class SpinupView : LucasView
    {
        protected override string SheetName { get { return "lucasCore_Spinup"; } }
        private static readonly string[] Values = { "ReturnInterval", "HistoricalClearcutShare", "LastDisturbanceUnburned" };
        private const string NONE = "(default)", CLEARCUT = "Clearcut", FIRE = "High-severity fire";

        private readonly DataGridView m_grid = new DataGridView
        {
            Height = 360, Dock = DockStyle.Top, AllowUserToAddRows = false, AllowUserToDeleteRows = false, AllowUserToResizeRows = false, RowHeadersVisible = false,
            SelectionMode = DataGridViewSelectionMode.CellSelect, BackgroundColor = SystemColors.Window, BorderStyle = BorderStyle.FixedSingle,
            AutoSizeColumnsMode = DataGridViewAutoSizeColumnsMode.Fill, EditMode = DataGridViewEditMode.EditOnEnter
        };
        private readonly Label m_source = new Label { AutoSize = true, MaximumSize = new Size(640, 0), Margin = new Padding(3, 6, 3, 6), Font = new Font(SystemFonts.MessageBoxFont, FontStyle.Bold) };
        private readonly Label m_state = new Label { AutoSize = true, MaximumSize = new Size(640, 0), ForeColor = SystemColors.GrayText, Margin = new Padding(3, 6, 3, 3) };
        private readonly Panel m_all = GridHost(200);
        private string m_note = "";

        public SpinupView()
        {
            this.SuspendLayout();
            Color edit = Color.FromArgb(255, 252, 230);
            m_grid.Columns.Add(new DataGridViewTextBoxColumn { Name = "Eco", HeaderText = "Ecodivision", ReadOnly = true, FillWeight = 90 });
            m_grid.Columns.Add(new DataGridViewTextBoxColumn { Name = "Type", HeaderText = "Forest type", ReadOnly = true, FillWeight = 130 });
            m_grid.Columns.Add(new DataGridViewTextBoxColumn { Name = "Cells", HeaderText = "Cells", ReadOnly = true, FillWeight = 40, DefaultCellStyle = { Alignment = DataGridViewContentAlignment.MiddleRight } });
            m_grid.Columns.Add(new DataGridViewTextBoxColumn { Name = "Landfire", HeaderText = "LANDFIRE interval (yr)", ReadOnly = true, FillWeight = 55, DefaultCellStyle = { Alignment = DataGridViewContentAlignment.MiddleRight } });
            m_grid.Columns.Add(new DataGridViewTextBoxColumn { Name = "ReturnInterval", HeaderText = "Your interval (yr)", FillWeight = 50, DefaultCellStyle = { Alignment = DataGridViewContentAlignment.MiddleRight, BackColor = edit } });
            m_grid.Columns.Add(new DataGridViewTextBoxColumn { Name = "Used", HeaderText = "Interval used (yr)", ReadOnly = true, FillWeight = 50, DefaultCellStyle = { Alignment = DataGridViewContentAlignment.MiddleRight } });
            m_grid.Columns.Add(new DataGridViewTextBoxColumn { Name = "HistoricalClearcutShare", HeaderText = "Share of cycles ended by clearcut (blank = 0)", FillWeight = 70, DefaultCellStyle = { Alignment = DataGridViewContentAlignment.MiddleRight, BackColor = edit } });
            var last = new DataGridViewComboBoxColumn { Name = "LastDisturbanceUnburned", HeaderText = "Last disturbance outside fire perimeters", FillWeight = 80, FlatStyle = FlatStyle.Flat, DefaultCellStyle = { BackColor = edit } };
            last.Items.AddRange(NONE, CLEARCUT, FIRE);
            m_grid.Columns.Add(last);
            foreach (DataGridViewColumn c in m_grid.Columns) c.SortMode = DataGridViewColumnSortMode.NotSortable;
            AddGroup(Group("Spin-up (stages 3, 4 and 8)", ProjectionTransitionsView.Stack(
                Note("The starting carbon of every forest cell comes from a spin-up: the stand grows, dies and regrows through repeated cycles until its dead wood and soil settle. The cycle length is the return interval of stand-replacing fire, which the Build reads from LANDFIRE's fire regime maps of the study area (stage 5), so the defaults exist only once a Build has run. Every past cycle ends in high-severity fire, and a cell outside the fire perimeters of 1900 to the start year starts from a clearcut (stage 8)."),
                Note("Empty page: every ecodivision and forest type uses those defaults, as listed below. Type a value in a shaded column to replace it for that ecodivision and forest type; clear it to go back."),
                m_source, m_grid, m_state)));
            var c2 = Column();
            c2.Controls.Add(Wrapped("Every row of the sheet. A row with a blank ecodivision sets a forest type in all ecodivisions; an ecodivision row wins over it, value by value. The Interval used column above shows how they combine.", 720));
            c2.Controls.Add(m_all);
            AddGroup(Group("All rows", c2));
            EndGroups();
            m_grid.CellEndEdit += (s, e) => { if (!Refreshing) Pending(e.RowIndex, e.ColumnIndex); };
            m_grid.CurrentCellDirtyStateChanged += (s, e) => { if (m_grid.CurrentCell is DataGridViewComboBoxCell) m_grid.CommitEdit(DataGridViewDataErrorContexts.Commit); };
            m_grid.CellValueChanged += (s, e) => { if (!Refreshing && e.RowIndex >= 0 && m_grid.Columns[e.ColumnIndex].Name == "LastDisturbanceUnburned") Pending(e.RowIndex, e.ColumnIndex); };
            this.ResumeLayout(false);
        }

        public override void LoadDataFeed(DataFeed dataFeed)
        {
            base.LoadDataFeed(dataFeed);
            LoadGrid(m_all, SheetName);
            RefreshControls();
        }

        // the default intervals: (ecodivision id, type id, interval, cells) from the newest Build result, else the package's provisional table
        private class Line { public int Eco, Type; public int? Interval, Cells; }
        private List<Line> Defaults_(out string source)
        {
            Scenario r = CarbonPages.BuildResult(this.Scenario);
            List<DataRow> rows = CarbonPages.ResultRows(r, "lucasCore_OutputReturnInterval");
            if (rows.Count > 0)
            {
                source = "LANDFIRE intervals from the Build result " + CarbonPages.ResultName(r) + ". Run the Build again after changing the study area or Build Options.";
                return rows.Where(x => x["StratumId"] != DBNull.Value && x["StateClassId"] != DBNull.Value).Select(x => new Line { Eco = Convert.ToInt32(x["StratumId"]), Type = Convert.ToInt32(x["StateClassId"]),
                    Interval = x["ReturnInterval"] == DBNull.Value ? (int?)null : Convert.ToInt32(x["ReturnInterval"]), Cells = x["Cells"] == DBNull.Value ? (int?)null : Convert.ToInt32(x["Cells"]) }).ToList();
            }
            source = "No Build result yet: the intervals below are the package's provisional ones. Run the Build to see this study area's LANDFIRE intervals.";
            Dictionary<string, int> eco = CarbonPages.Ids(Sheet, "StratumId"), type = CarbonPages.Ids(Sheet, "StateClassId");
            var list = new List<Line>();
            foreach (string[] x in Defaults.ReadCsv(Defaults.PackageFile("defaults", "spinup", "return-interval.csv")).Skip(1))
            {
                int e, t, ri;
                if (eco.TryGetValue(x[0].Trim(), out e) && type.TryGetValue(x[1].Trim(), out t)) list.Add(new Line { Eco = e, Type = t, Interval = int.TryParse(x[2], out ri) ? ri : (int?)null });
            }
            return list;
        }

        private void Pending(int row, int col)
        {
            if (row < 0) return;
            string name = m_grid.Columns[col].Name;
            if (!Values.Contains(name)) return;
            var key = (int[])m_grid.Rows[row].Tag; object cell = m_grid.Rows[row].Cells[col].Value;
            this.BeginInvoke(new Action(() => Edit(key, name, Convert.ToString(cell))));
        }

        private void Edit(int[] key, string column, string text)
        {
            object v; text = (text ?? "").Trim();
            if (column == "LastDisturbanceUnburned") v = text == CLEARCUT ? (object)1 : text == FIRE ? (object)2 : DBNull.Value;
            else if (text.Length == 0) v = DBNull.Value;
            else
            {
                double? d = CarbonPages.Parse(text);
                bool ok = d.HasValue && (column == "ReturnInterval" ? d >= 1 && d <= 5000 && d == Math.Floor(d.Value) : d >= 0 && d <= 1);
                if (!ok) { m_note = column == "ReturnInterval" ? "Not a whole number of years between 1 and 5000: " + text + ". " : "Not a share between 0 and 1: " + text + ". "; RefreshControls(); return; }
                v = column == "ReturnInterval" ? (object)Convert.ToInt32(d.Value) : d.Value;
            }
            CarbonPages.SetValue(Sheet, key[0], key[1], column, v, Values);
            LoadGrid(m_all, SheetName);
            RefreshControls();
        }

        protected override void ShowData()
        {
            string source; List<Line> lines = Defaults_(out source);
            m_source.Text = source;
            Dictionary<int, string> ecoNames = CarbonPages.Names(Sheet, "StratumId"), typeNames = CarbonPages.Names(Sheet, "StateClassId");
            List<DataRow> rows = CarbonPages.Rows(Sheet);
            Func<int?, int, DataRow> row = (e, t) => rows.FirstOrDefault(x => x["StateClassId"] != DBNull.Value && Convert.ToInt32(x["StateClassId"]) == t &&
                (e.HasValue ? x["StratumId"] != DBNull.Value && Convert.ToInt32(x["StratumId"]) == e.Value : x["StratumId"] == DBNull.Value));
            m_grid.Rows.Clear();
            string n;
            foreach (Line l in lines.OrderBy(x => ecoNames.TryGetValue(x.Eco, out n) ? n : "").ThenBy(x => typeNames.TryGetValue(x.Type, out n) ? n : ""))
            {
                DataRow own = row(l.Eco, l.Type), all = row(null, l.Type);
                Func<string, object> pick = c => own != null && own[c] != DBNull.Value ? own[c] : all != null && all[c] != DBNull.Value ? all[c] : DBNull.Value;
                object ri = pick("ReturnInterval");
                string last = own == null || own["LastDisturbanceUnburned"] == DBNull.Value ? NONE : Convert.ToInt32(own["LastDisturbanceUnburned"]) == 2 ? FIRE : CLEARCUT;
                int i = m_grid.Rows.Add(ecoNames.TryGetValue(l.Eco, out n) ? n : l.Eco.ToString(), typeNames.TryGetValue(l.Type, out n) ? n.Replace("Forest: ", "") : l.Type.ToString(),
                    l.Cells.HasValue ? l.Cells.Value.ToString("N0") : "", l.Interval.HasValue ? l.Interval.Value.ToString() : "",
                    own == null || own["ReturnInterval"] == DBNull.Value ? "" : Convert.ToString(own["ReturnInterval"]),
                    ri != DBNull.Value ? Convert.ToString(ri) : l.Interval.HasValue ? l.Interval.Value.ToString() : "",
                    own == null || own["HistoricalClearcutShare"] == DBNull.Value ? "" : CarbonPages.Format(CarbonPages.Num(own["HistoricalClearcutShare"]), "0.00"), last);
                m_grid.Rows[i].Tag = new[] { l.Eco, l.Type };
                if (ri != DBNull.Value) m_grid.Rows[i].Cells["Used"].Style.Font = new Font(m_grid.Font, FontStyle.Bold);
            }
            bool edit = !(this.Scenario != null && this.Scenario.IsResult) && this.ShouldEnableView();
            foreach (string c in Values) m_grid.Columns[c].ReadOnly = !edit;
            m_state.Text = m_note + (rows.Count == 0 ? "The sheet is empty: every forest cell uses the defaults listed." : string.Format("{0} row{1} in the sheet; a bold interval is one the sheet sets.", rows.Count, rows.Count == 1 ? "" : "s"));
            m_note = "";
        }
    }
}
