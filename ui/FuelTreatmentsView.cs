// =============================================================================
// FuelTreatmentsView.cs - Fuel Treatments: mechanical thinning, prescribed burn, thin and burn on upland forest
// =============================================================================
// Sheet lucasCore_FuelTreatment (treatment, years, area a year or a budget, where: a unit at any of the three strata levels, stand
// ages, retreatment interval, priority, cost). Stage 9 turns each row into ST-Sim targets and, for a wildfire in a treated cell, the
// severity shift by years since the treatment (src/fuel-treatments.R).
// User 2026-11-13: "Next is Fuel Treatments"; "Lets go with the severity shift". Same layout as Management Actions: one line per
// parameter with its note to the right edge; Add writes a grid row.
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
    public class FuelTreatmentsView : LucasView
    {
        protected override string SheetName { get { return "lucasCore_FuelTreatment"; } }

        private readonly ComboBox m_treat = List(250), m_priority = List(330), m_range = List(280);
        private readonly TextBox m_start = Box(60), m_end = Box(60), m_area = Box(80), m_budget = Box(90), m_ageMin = Box(50), m_ageMax = Box(50), m_retreat = Box(50), m_costBox = Box(70);
        private readonly ManagementActionsView.WherePicker m_where = new ManagementActionsView.WherePicker();
        private readonly Button m_add = new Button { Text = "Add treatment", AutoSize = true, Margin = new Padding(3, 6, 6, 3) };
        private readonly Label m_said = new Label { AutoSize = true, MaximumSize = new Size(640, 0), ForeColor = SystemColors.GrayText, Margin = new Padding(3, 8, 3, 3) };
        private readonly Label m_costNote = Note(""), m_effectNote = Note("");
        private readonly Panel m_grid = GridHost(200);
        private readonly Button m_clear = new Button { Text = "Remove all rows", AutoSize = true, Margin = new Padding(3, 3, 12, 3) };
        private readonly Label m_state = new Label { AutoSize = true, MaximumSize = new Size(640, 0), ForeColor = SystemColors.GrayText, Margin = new Padding(3, 8, 3, 3) };
        private readonly Label m_rows = new Label { AutoSize = true, MaximumSize = new Size(760, 0), Margin = new Padding(3, 4, 3, 6) };
        private static readonly string[] KEYS = { "Mechanical thinning", "Prescribed burn", "Thin and burn" };
        private readonly Dictionary<string, string> m_settings = new Dictionary<string, string>();   // "treatment|MinAge" etc.
        private readonly Dictionary<string, double[]> m_cost = new Dictionary<string, double[]>();   // "region|treatment" -> central, low, high
        private readonly Dictionary<string, string> m_effects = new Dictionary<string, string>();   // treatment -> words

        private static FlowLayoutPanel Line(string c, Control x, Label n) { return ManagementActionsView.Line(c, x, n); }
        private static FlowLayoutPanel Pair(TextBox a, string mid, TextBox b, string after) { return ManagementActionsView.Pair(a, mid, b, after); }

        public FuelTreatmentsView()
        {
            this.SuspendLayout();
            AddGroup(Group("What fuel treatments do in a projection", ProjectionTransitionsView.Stack(
                Note("A treatment changes neither the forest type nor the stand age. Its carbon moves when it happens (thinning removes wood, burning consumes litter and debris). For some years after, a wildfire in the treated cell is less often high or medium severity and more often low: it still burns, less severely (fire methods 1 and 2). No rows = no treatments."))));
            var r = new FlowLayoutPanel { AutoSize = true, WrapContents = false, Margin = new Padding(150, 2, 0, 0) }; r.Controls.Add(m_add); r.Controls.Add(m_said);
            AddGroup(Group("A treatment", ManagementActionsView.Lines(
                Line("Treatment:", m_treat, m_effectNote),
                Line("Years:", Pair(m_start, "to", m_end, null), Note("Blank = from the projection start, or to its end.")),
                Line("Area per year:", m_area, Note("In the library's units (hectares) of upland forest. Less is treated when less land is eligible; the run reports what was done.")),
                Line("Or a budget:", m_budget, Note("USD a year instead of an area (leave the area blank): the area it pays for at the central cost per hectare.")),
                Line("Where:", m_where.Panel(), m_where.Info),
                Line("Stand ages:", Pair(m_ageMin, "to", m_ageMax, null), Note("Ages that may be treated. Blank = the treatment's default from, any to. One window per treatment.")),
                Line("Retreatment:", m_retreat, Note("Years before a treated cell can be treated again by the same treatment. Blank = the default.")),
                Line("Priority:", m_priority, Note("Random, or first where wildfire burned most often in the historical record. One priority per treatment.")),
                Line("Cost per hectare:", m_costBox, m_costNote),
                Line("Cost range:", m_range, Note("Default: the cost a Beta over its range, drawn once per iteration. Fixed: the value alone.")),
                r)));
            var rr = Row(); rr.Controls.Add(m_clear); rr.Controls.Add(m_state);
            AddGroup(Group("Treatments (what the Projection Setup uses)", ProjectionTransitionsView.Stack(m_rows, m_grid, rr,
                Wrapped("Edit here directly if you like. Projection Results > Fuel Treatments (as set up) lists what each row became.", 760))));
            EndGroups();
            m_treat.Items.AddRange(KEYS);
            m_priority.Items.AddRange(new object[] { "Random among eligible cells", "Fire likelihood (where wildfire burned more often)" });
            m_range.Items.AddRange(new object[] { "Default ranges (sampled per iteration)", "Fixed values" });
            LoadDefaults();
            m_treat.SelectedIndexChanged += (s, e) => ShowTreatment();
            m_treat.SelectedIndex = 2; m_priority.SelectedIndex = 0; m_range.SelectedIndex = 0; m_area.Text = "100";
            m_add.Click += (s, e) => AddRow();
            m_clear.Click += (s, e) => ClearAll();
            this.ResumeLayout(false);
        }

        private static string Key(string treatment) { return treatment.StartsWith("Thin and") ? "Thin and burn" : treatment; }
        private void LoadDefaults()
        {
            try
            {
                List<string[]> s = Defaults.ReadCsv(Defaults.PackageFile("defaults", "fuel-treatments", "settings.csv"));
                int it = Array.IndexOf(s[0], "Treatment"), ia = Array.IndexOf(s[0], "MinAge"), ir = Array.IndexOf(s[0], "RetreatmentYears");
                foreach (string[] x in s.Skip(1)) { if (x.Length <= Math.Max(ia, ir)) continue; m_settings[x[it] + "|MinAge"] = x[ia]; m_settings[x[it] + "|Retreat"] = x[ir]; }
                List<string[]> c = Defaults.ReadCsv(Defaults.PackageFile("defaults", "fuel-treatments", "costs.csv"));
                int cr = Array.IndexOf(c[0], "Region"), ct = Array.IndexOf(c[0], "Treatment"), cc = Array.IndexOf(c[0], "Central"), cl = Array.IndexOf(c[0], "Low"), ch = Array.IndexOf(c[0], "High");
                Func<string, double> d = v => { double z; return double.TryParse(v, System.Globalization.NumberStyles.Float, System.Globalization.CultureInfo.InvariantCulture, out z) ? z : double.NaN; };
                foreach (string[] x in c.Skip(1)) if (x.Length > ch) m_cost[x[cr] + "|" + x[ct]] = new[] { d(x[cc]), d(x[cl]), d(x[ch]) };
                List<string[]> e = Defaults.ReadCsv(Defaults.PackageFile("defaults", "fuel-treatments", "effects.csv"));
                int et = Array.IndexOf(e[0], "Treatment"), e0 = Array.IndexOf(e[0], "TSTMin"), e1 = Array.IndexOf(e[0], "TSTMax"), eh = Array.IndexOf(e[0], "High");
                foreach (string[] x in e.Skip(1))
                {
                    if (x.Length <= Math.Max(eh, e1)) continue; double h = d(x[eh]);
                    string w = string.Format("years {0}-{1}: high severity x{2:0.##}", x[e0], x[e1], h);
                    m_effects[x[et]] = m_effects.ContainsKey(x[et]) ? m_effects[x[et]] + "; " + w : w;
                }
            }
            catch (Exception) { }
        }
        private void ShowTreatment()
        {
            string k = m_treat.SelectedIndex >= 0 ? KEYS[m_treat.SelectedIndex] : KEYS[2]; string v;
            m_ageMin.Text = m_settings.TryGetValue(k + "|MinAge", out v) ? v : ""; m_retreat.Text = m_settings.TryGetValue(k + "|Retreat", out v) ? v : "";
            m_effectNote.Text = m_effects.ContainsKey(k) ? "After a treatment: " + m_effects[k] + " (low severity rises to keep the burned area). Provisional." : "";
            double[] c; m_costNote.Text = m_cost.TryGetValue("All|" + k, out c)
                ? string.Format("Blank = the regional default (national {0:#,0}, {1:#,0}-{2:#,0} USD/ha, 2024). Provisional.", c[0], c[1], c[2]) : "Blank = the regional default.";
        }

        public override void LoadDataFeed(DataFeed dataFeed)
        {
            base.LoadDataFeed(dataFeed);
            Project p = this.Scenario != null ? this.Scenario.Project : this.DataFeed.Project;
            if (p != null) { var ms = new ManagementActionsView.ModelStrata(); try { ms.Load(p, this.Scenario); } catch (Exception) { } m_where.Load(ms); }
            LoadGrid(m_grid, SheetName);
            RefreshControls();
        }

        private static IEnumerable<DataRow> Live(DataTable dt) { return dt.Rows.Cast<DataRow>().Where(x => x.RowState != DataRowState.Deleted); }
        private static string Read(TextBox t, string what, bool integer, double min, double max, out object value)
        {
            value = DBNull.Value; string v = t.Text.Trim(); double d;
            if (v.Length == 0) return null;
            if (!double.TryParse(v, out d) || (integer && d != Math.Floor(d)) || d < min || d > max) return string.Format("{0} must be {1} from {2} to {3}", what, integer ? "a whole number" : "a number", min, max);
            value = integer ? (object)Convert.ToInt32(d) : d; return null;
        }

        private void AddRow()
        {
            object start = DBNull.Value, end = DBNull.Value, area = DBNull.Value, budget = DBNull.Value, a0 = DBNull.Value, a1 = DBNull.Value, re = DBNull.Value, cost = DBNull.Value;
            string err = Read(m_start, "the start year", true, 1900, 2200, out start) ?? Read(m_end, "the end year", true, 1900, 2200, out end)
                      ?? Read(m_area, "the area per year", false, 0, 1e12, out area) ?? Read(m_budget, "the budget", false, 0, 1e13, out budget)
                      ?? Read(m_ageMin, "the first stand age", true, 0, 500, out a0) ?? Read(m_ageMax, "the last stand age", true, 0, 500, out a1)
                      ?? Read(m_retreat, "the retreatment interval", true, 0, 200, out re) ?? Read(m_costBox, "the cost", false, 0, 1e9, out cost);
            if (err == null && area == DBNull.Value && budget == DBNull.Value) err = "give an area per year or a budget";
            if (err == null && area != DBNull.Value && budget != DBNull.Value) err = "give an area or a budget, not both";
            if (err == null && start != DBNull.Value && end != DBNull.Value && (int)start > (int)end) err = "the start year is after the end year";
            if (err == null && a0 != DBNull.Value && a1 != DBNull.Value && (int)a0 > (int)a1) err = "the stand ages run backwards";
            DataTable dt = Sheet.GetData(); DataRow nr = dt.NewRow();
            if (err == null) err = m_where.Apply(nr);
            if (err != null) { m_said.ForeColor = Color.Firebrick; m_said.Text = "Not added: " + err + "."; return; }
            nr["TreatmentId"] = m_treat.SelectedIndex + 1; nr["StartYear"] = start; nr["EndYear"] = end; nr["Amount"] = area; nr["Budget"] = budget;
            nr["MinAge"] = a0; nr["MaxAge"] = a1; nr["Retreatment"] = re; nr["Priority"] = m_priority.SelectedIndex + 1; nr["Cost"] = cost; nr["CostRange"] = m_range.SelectedIndex == 1 ? 2 : 1;
            Sheet.BeginAddRows();
            try { dt.Rows.Add(nr); }
            finally { Sheet.EndAddRows(); }
            m_said.ForeColor = SystemColors.GrayText; m_said.Text = "Added as row " + Live(dt).Count() + ". Change any setting and add again for other years, places or treatments.";
            LoadGrid(m_grid, SheetName);
            RefreshControls();
        }

        private void ClearAll()
        {
            List<DataRow> rows = Live(Sheet.GetData()).ToList();
            if (rows.Count == 0) return;
            if (MessageBox.Show(this, "Remove every fuel treatment?", "Fuel Treatments", MessageBoxButtons.OKCancel, MessageBoxIcon.Question) != DialogResult.OK) return;
            Sheet.DeleteRows(rows);
            LoadGrid(m_grid, SheetName);
            RefreshControls();
        }

        private static string Num(object v, string blank) { return v == DBNull.Value || v == null ? blank : Convert.ToDouble(v).ToString("0.##"); }
        private string Lookup(string column, object v)
        {
            if (v == DBNull.Value || v == null) return null;
            DataSheetColumn col = Sheet.Columns.Cast<DataSheetColumn>().FirstOrDefault(x => x.Name == column);
            if (col == null || col.ValidationTable == null) return Convert.ToString(v);
            foreach (DataRow r in Live(col.ValidationTable.DataSource))
                if (Convert.ToString(r[col.ValidationTable.ValueMember]) == Convert.ToString(v)) return Convert.ToString(r[col.ValidationTable.DisplayMember]);
            return Convert.ToString(v);
        }

        private string Describe(DataRow r, int i)
        {
            int t = r["TreatmentId"] == DBNull.Value ? 0 : Convert.ToInt32(r["TreatmentId"]);
            if (t < 1 || t > 3) return string.Format("{0}. (no treatment chosen)", i);
            string[] cols = { "StratumId", "SecondaryStratumId", "TertiaryStratumId" };
            string where = string.Join(" / ", cols.Where(c => r.Table.Columns.Contains(c)).Select(c => Lookup(c, r[c])).Where(x => x != null));
            string years = r["StartYear"] == DBNull.Value && r["EndYear"] == DBNull.Value ? "every projection year"
                         : string.Format("{0} to {1}", Num(r["StartYear"], "the first projection year"), Num(r["EndYear"], "the end"));
            string amt = r["Amount"] == DBNull.Value && r["Budget"] != DBNull.Value ? Convert.ToDouble(r["Budget"]).ToString("#,0") + " USD" : Num(r["Amount"], "?");
            bool fire = r["Priority"] != DBNull.Value && Convert.ToInt32(r["Priority"]) == 2;
            return string.Format("{0}. {1} {2} a year, {3}, in {4}; stand ages {5}-{6}, retreatment {7}, {8}{9}.", i, KEYS[t - 1], amt, years, where.Length > 0 ? where : "the whole study area",
                Num(r["MinAge"], "default"), Num(r["MaxAge"], "any"), r["Retreatment"] == DBNull.Value ? "the default" : Num(r["Retreatment"], "") + " yr", fire ? "where fire burned most" : "at random",
                r["Cost"] != DBNull.Value ? "; " + Num(r["Cost"], "") + " USD per hectare" : "");
        }

        protected override void ShowData()
        {
            bool edit = !(this.Scenario != null && this.Scenario.IsResult) && this.ShouldEnableView();
            List<DataRow> rows = Sheet.HasData() ? Live(Sheet.GetData()).ToList() : new List<DataRow>();
            m_add.Enabled = edit; m_clear.Enabled = edit && rows.Count > 0;
            m_state.Text = rows.Count == 0 ? "No treatments." : string.Format("{0} treatment{1}.", rows.Count, rows.Count == 1 ? "" : "s");
            m_rows.Text = rows.Count == 0 ? "No treatments yet." : string.Join(Environment.NewLine, rows.Select((x, i) => Describe(x, i + 1)));
        }
    }
}
