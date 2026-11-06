// =============================================================================
// ProjectionClimateView.cs - the Climate page of a Projection Climate scenario: the LOCA2 run whose climate drives projections
// =============================================================================
// Single-row sheet lucasCore_ProjectionClimate, read by stage 11. The model list keeps the models that have a run for the chosen
// scenario, and the replicate list the ensemble members of that model and scenario (from the Runs column of Climate Models:
// "SSP2-4.5: r1i1p1f1, r2i1p1f1; SSP3-7.0: ..."). The lists come from Data Sources: LOCA2 Folder; Rescan updates them
// after runs are added or removed there (Loca2Lists.cs). The climate effects (which flows respond, and how) come from the Build's
// Climate Options through the scenario's dependency on the Build result.
// =============================================================================
using System;
using System.Collections.Generic;
using System.Data;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Windows.Forms;
using SyncroSim.Core;

namespace lucasCoreUI
{
    public class ProjectionClimateView : LucasView
    {
        protected override string SheetName { get { return "lucasCore_ProjectionClimate"; } }

        private class Item { public object Key; public string Name; public string Runs; public override string ToString() { return Name; } }

        private readonly ComboBox m_scenario = List(180);
        private readonly ComboBox m_model = List(220);
        private readonly ComboBox m_replicate = List(220);
        private readonly TextBox m_last = Box(60);
        private readonly Label m_runs = new Label { AutoSize = true, MaximumSize = new Size(640, 0), ForeColor = SystemColors.GrayText, Margin = new Padding(3, 6, 3, 3) };
        private readonly Button m_rescan = new Button { Text = "Rescan LOCA2 folder", AutoSize = true, Margin = new Padding(3, 6, 12, 3) };
        private readonly Label m_scan = new Label { AutoSize = true, MaximumSize = new Size(560, 0), ForeColor = SystemColors.GrayText, Margin = new Padding(3, 10, 3, 3) };
        private List<Item> m_scenarios = new List<Item>(), m_models = new List<Item>(), m_replicates = new List<Item>();
        // CO2 fertilization (to-do 46, src/co2.R)
        private readonly ComboBox m_co2 = List(180);
        private readonly TextBox m_ceiling = Box(70);
        private readonly TextBox m_reference = Box(70);
        private readonly Panel m_adjust = GridHost(320);
        private readonly Button m_defaults = new Button { Text = "Load the defaults", AutoSize = true, Margin = new Padding(3, 3, 12, 3) };
        private const string BetaSheet = "lucasCore_Co2Adjustment";
        private string m_loaded = "";
        private readonly Label m_co2note = new Label { AutoSize = true, MaximumSize = new Size(640, 0), ForeColor = SystemColors.GrayText, Margin = new Padding(3, 6, 3, 3) };
        private static readonly string[] Co2Names = { "None", "Low", "Central (default)", "High" };

        public ProjectionClimateView()
        {
            this.SuspendLayout();
            var how = Column();
            how.Controls.Add(Note("A Projection Climate scenario depends on a Build result and runs stage 11 alone. It writes the climate flow multipliers of the projection years (the Build's historical end + 1 to the last year), using the climate effects chosen in the Build's Climate Options, and the CO2 fertilization multipliers of the same years. Projections then depend on the Projection Setup, then this result, then the Build."));
            AddGroup(Group("How this works", how));

            var run = Column();
            var f = Form();
            FormRow(f, "Scenario (SSP):", m_scenario, null);
            FormRow(f, "Climate model:", m_model, null);
            FormRow(f, "Replicate:", m_replicate, null);
            FormRow(f, "Last year:", m_last, "blank = 2100");
            run.Controls.Add(f);
            run.Controls.Add(m_runs);
            var scan = Row(); scan.Controls.Add(m_rescan); scan.Controls.Add(m_scan); run.Controls.Add(scan);
            AddGroup(Group("LOCA2 run", run));

            var co2 = Column();
            co2.Controls.Add(Note("Growth of forest, shrubland, grassland, wetland and agriculture is multiplied by 1 + beta x ln(CO2 / reference CO2), with CO2 from the chosen scenario (SSP) and beta by vegetation type, from the literature review (to-do 46). Forest betas mix the ectomycorrhizal (ECM) and arbuscular values by the forest type's ECM share of FIA basal area, and taper with stand age from young (0-25 years) to mature (76 and older). The reference is the CO2 of the Build's historical end year, because the growth curves already carry the CO2 of the FIA years. A projection that does not depend on this result (No Climate) has no CO2 effect."));
            var cf = Form();
            FormRow(cf, "CO2 fertilization:", m_co2, "Central: forest 0.25 (0.45 young ECM to 0.15 mature AM), shrub 0.15, grassland 0.30, emergent wetland 0.20. Low and High: the review's range. None: no CO2 effect.");
            FormRow(cf, "CO2 ceiling (ppm):", m_ceiling, "blank = none; e.g. 600 holds the effect at 600 ppm (no forest experiment went above about 600)");
            FormRow(cf, "Reference CO2 (ppm):", m_reference, "blank = the SSP's CO2 in the historical end year");
            co2.Controls.Add(cf);
            co2.Controls.Add(Note("CO2 betas (per ln CO2): the chosen series' values, loaded from the package defaults for the strata of the Build this scenario depends on. Edit a row to change it; blank stratum = every stratum, blank age band = every age. A row for one stratum or age band wins over a blank one. A class with no row takes the series' default. Switching the series reloads the table (asking first if it was edited). A beta of 0.1 is about 2% more growth per 100 ppm from 425 ppm."));
            var dr = Row(); dr.Controls.Add(m_defaults); dr.Controls.Add(m_co2note); co2.Controls.Add(dr);
            co2.Controls.Add(m_adjust);
            AddGroup(Group("CO2 fertilization", co2));
            EndGroups();
            foreach (string n in Co2Names) m_co2.Items.Add(n);
            m_co2.SelectionChangeCommitted += (s, e) => ChangeSeries(m_co2.SelectedIndex + 1);
            m_defaults.Click += (s, e) => { int cur = IntValue("Co2Series", 3); if (cur != 1 && (!Edited(cur) || Confirm(cur))) LoadBetas(cur); RefreshControls(); };
            BindNumber(m_ceiling, () => Sheet, "Co2Ceiling", false);
            BindNumber(m_reference, () => Sheet, "Co2Reference", false);
            m_scenario.SelectionChangeCommitted += (s, e) => { Write("ClimateScenarioId", Key(m_scenario)); RefreshControls(); };
            m_model.SelectionChangeCommitted += (s, e) => { Write("ClimateModelId", Key(m_model)); RefreshControls(); };
            m_replicate.SelectionChangeCommitted += (s, e) => { Write("ClimateReplicateId", Key(m_replicate)); RefreshControls(); };
            m_rescan.Click += (s, e) => Rescan();
            BindNumber(m_last, () => Sheet, "EndYear", true);
            this.ResumeLayout(false);
        }

        private static object Key(ComboBox c) { var i = c.SelectedItem as Item; return i == null ? DBNull.Value : i.Key; }

        // ---- CO2 betas (defaults/climate/co2-default-betas.csv, tools/make_co2_default_betas.R) ---------------------------------
        private bool CanEdit { get { return this.Scenario != null && !this.Scenario.IsResult && this.ShouldEnableView(); } }
        private static readonly string[] SeriesColumn = { null, null, "Low", "Central", "High" };   // by Co2Series value (1 = None)

        // the study area's primary strata (ecodivisions), from the Build result this scenario depends on; empty when there is none yet
        private List<string> StudyStrata()
        {
            var s = new List<string>();
            try
            {
                if (this.Scenario == null) return s;
                foreach (Scenario d in this.Scenario.Dependencies)
                {
                    DataSheet ds = d.GetDataSheet("lucasCore_OutputStrataSummary"); if (ds == null) continue;
                    foreach (DataRow r in ds.GetData().Rows)
                        if (r.RowState != DataRowState.Deleted && Convert.ToString(r["Level"]) == "Primary") s.Add(Convert.ToString(r["Name"]));
                    if (s.Count > 0) break;
                }
            }
            catch (Exception) { s.Clear(); }
            return s.Distinct().ToList();
        }

        // the rows the page loads for a series: StateClassId, StratumId, AgeBand, Beta (as text). A forest class with ecodivision ECM shares
        // gets a row per study-area stratum and band, unless every stratum has the same values (then one blank-stratum set)
        private List<string[]> Expected(int series)
        {
            var rows = new List<string[]>();
            string file = Defaults.PackageFile("defaults", "climate", "co2-default-betas.csv");
            if (series < 2 || series > 4 || !File.Exists(file)) return rows;
            List<string[]> csv = Defaults.ReadCsv(file);
            int c = Array.IndexOf(csv[0], SeriesColumn[series]);
            var data = csv.Skip(1).Select(r => new { Cls = r[0], Str = r[1], Band = r[2], Beta = r[c] }).ToList();
            List<string> strata = StudyStrata();
            foreach (var cls in data.Select(x => x.Cls).Distinct())
            {
                var us = data.Where(x => x.Cls == cls && x.Str.Length == 0).ToList();
                var loc = data.Where(x => x.Cls == cls && strata.Contains(x.Str)).ToList();
                Func<string, string, string> beta = (st, band) => { var l = loc.FirstOrDefault(x => x.Str == st && x.Band == band); return l != null ? l.Beta : us.First(x => x.Band == band).Beta; };
                bool same = loc.Count == 0 || us.All(u => strata.Select(st => beta(st, u.Band)).Distinct().Count() == 1);
                if (same) foreach (var u in us) rows.Add(new[] { cls, "", u.Band, loc.Count == 0 ? u.Beta : beta(strata[0], u.Band) });
                else foreach (string st in strata) foreach (var u in us) rows.Add(new[] { cls, st, u.Band, beta(st, u.Band) });
            }
            return rows;
        }

        private static string Num(string s) { double v; return double.TryParse(s, System.Globalization.NumberStyles.Float, System.Globalization.CultureInfo.InvariantCulture, out v) ? Math.Round(v, 4).ToString("R", System.Globalization.CultureInfo.InvariantCulture) : s; }

        // whether the table holds anything other than the series' defaults (empty = not edited)
        private bool Edited(int series)
        {
            DataSheet ds = this.DataFeed.GetDataSheet(BetaSheet); if (ds == null || !ds.HasData()) return false;
            if (series < 2) return true;
            DataSheetColumn[] cols = new[] { "StateClassId", "StratumId", "AgeBand", "Beta" }.Select(n => ds.Columns.Cast<DataSheetColumn>().First(x => x.Name == n)).ToArray();
            var have = ds.GetData().Rows.Cast<DataRow>().Where(r => r.RowState != DataRowState.Deleted)
                .Select(r => string.Join("|", cols.Select((col, i) => i == 3 ? Num(Defaults.Display(col, r[col.Name])) : Defaults.Display(col, r[col.Name])))).OrderBy(x => x, StringComparer.Ordinal).ToList();
            var want = Expected(series).Select(r => string.Join("|", r[0], r[1], r[2], Num(r[3]))).OrderBy(x => x, StringComparer.Ordinal).ToList();
            return !have.SequenceEqual(want);
        }

        private bool Confirm(int series)
        {
            return MessageBox.Show(this, string.Format("The CO2 betas table has been edited. Replace it with the {0} defaults?", SeriesColumn[series]), "CO2 betas",
                                   MessageBoxButtons.YesNo, MessageBoxIcon.Question) == DialogResult.Yes;
        }

        private void LoadBetas(int series)
        {
            DataSheet ds = this.DataFeed.GetDataSheet(BetaSheet); if (ds == null) return;
            var rows = new List<string[]> { new[] { "StateClassId", "StratumId", "AgeBand", "Beta" } };
            rows.AddRange(Expected(series));
            List<string> problems = Defaults.LoadRows(ds, rows, null);
            m_loaded = problems.Count == 0 ? string.Format("Loaded the {0} defaults ({1} rows).", SeriesColumn[series], rows.Count - 1)
                                                 : string.Format("Loaded the {0} defaults; {1} rows did not match this library (first: {2}).", SeriesColumn[series], problems.Count, problems[0]);
        }

        // a new series: reload the table from its defaults when it holds the old series' defaults (or nothing), else ask
        private void ChangeSeries(int series)
        {
            int old = IntValue("Co2Series", 3);
            if (series == old) return;
            bool load = series != 1 && (!Edited(old) || Confirm(series));
            Write("Co2Series", series);
            if (load) LoadBetas(series);
            RefreshControls();
        }

        private static List<Item> Read(Project p, string sheet, string key, bool runs)
        {
            DataTable dt = p.GetDataSheet(sheet).GetData();
            return dt.Rows.Cast<DataRow>().Where(r => r.RowState != DataRowState.Deleted)
                .Select(r => new Item { Key = Convert.ToInt32(r[key]), Name = Convert.ToString(r["Name"]), Runs = runs && r["Runs"] != DBNull.Value ? Convert.ToString(r["Runs"]) : null })
                .OrderBy(i => i.Name, StringComparer.OrdinalIgnoreCase).ToList();
        }

        public override void LoadDataFeed(DataFeed dataFeed)
        {
            base.LoadDataFeed(dataFeed);
            LoadLists();
            int cur = IntValue("Co2Series", 3);
            DataSheet bs = this.DataFeed.GetDataSheet(BetaSheet);
            if (CanEdit && cur != 1 && bs != null && !bs.HasData()) LoadBetas(cur);
            LoadGrid(m_adjust, BetaSheet);
            m_scan.Text = "The lists show the runs in Data Sources: LOCA2 Folder when the library was made. After adding or removing runs there, rescan.";
            RefreshControls();
        }

        private void LoadLists()
        {
            Project p = this.DataFeed.Project;
            m_scenarios = Read(p, "lucasCore_ClimateScenario", "ClimateScenarioId", false);
            m_models = Read(p, "lucasCore_ClimateModel", "ClimateModelId", true);
            m_replicates = Read(p, "lucasCore_ClimateReplicate", "ClimateReplicateId", false);
        }

        // the project's three LOCA2 lists from the runs now in the LOCA2 folder (Loca2Lists.cs); rows are kept, so chosen runs stay valid
        private void Rescan()
        {
            string folder = Loca2Lists.FolderOf(this.DataFeed.Project, null);
            Loca2Lists L;
            try { L = Loca2Lists.Scan(folder); }
            catch (Exception ex) { m_scan.Text = "Scan failed: " + ex.Message; m_scan.ForeColor = Color.Firebrick; return; }
            if (L == null) { m_scan.Text = string.Format("No complete LOCA2 runs in \"{0}\" (expected <model>/<member>/historical and <ssp> folders, each with pr, tasmax and tasmin *.monthly.nc). Lists unchanged; check Data Sources: LOCA2 Folder.", folder); m_scan.ForeColor = Color.Firebrick; return; }
            m_scan.Text = L.Apply(this.DataFeed.Project); m_scan.ForeColor = SystemColors.GrayText;
            LoadLists(); RefreshControls();
        }

        // a model's runs by scenario name: "SSP2-4.5: r1i1p1f1, r2i1p1f1; SSP3-7.0: r1i1p1f1"
        private static Dictionary<string, List<string>> Runs(Item model)
        {
            var d = new Dictionary<string, List<string>>(StringComparer.OrdinalIgnoreCase);
            if (model == null || string.IsNullOrEmpty(model.Runs)) return d;
            foreach (string part in model.Runs.Split(';'))
            {
                int c = part.IndexOf(':'); if (c < 0) continue;
                d[part.Substring(0, c).Trim()] = part.Substring(c + 1).Split(',').Select(x => x.Trim()).Where(x => x.Length > 0).ToList();
            }
            return d;
        }

        private static void Fill(ComboBox c, string blank, IEnumerable<Item> items, object selected)
        {
            c.BeginUpdate(); c.Items.Clear();
            c.Items.Add(new Item { Key = DBNull.Value, Name = blank });
            foreach (Item i in items) c.Items.Add(i);
            int idx = 0;
            for (int k = 1; k < c.Items.Count; k++) if (selected != DBNull.Value && Convert.ToInt32(((Item)c.Items[k]).Key) == Convert.ToInt32(selected)) { idx = k; break; }
            c.SelectedIndex = idx; c.EndUpdate();
        }

        protected override void ShowData()
        {
            object sid = Value("ClimateScenarioId"), mid = Value("ClimateModelId"), rid = Value("ClimateReplicateId");
            Item scen = m_scenarios.FirstOrDefault(i => sid != DBNull.Value && Convert.ToInt32(i.Key) == Convert.ToInt32(sid));
            Fill(m_scenario, "(choose a scenario)", m_scenarios, sid);
            // models with a run for the scenario; a chosen model without one stays listed so the problem is visible
            IEnumerable<Item> models = scen == null ? m_models : m_models.Where(m => Runs(m).ContainsKey(scen.Name) || (mid != DBNull.Value && Convert.ToInt32(m.Key) == Convert.ToInt32(mid)));
            Fill(m_model, "(choose a model)", models, mid);
            Item model = m_models.FirstOrDefault(i => mid != DBNull.Value && Convert.ToInt32(i.Key) == Convert.ToInt32(mid));
            List<string> members = scen != null && model != null && Runs(model).ContainsKey(scen.Name) ? Runs(model)[scen.Name] : null;
            IEnumerable<Item> reps = members == null ? m_replicates : m_replicates.Where(r => members.Contains(r.Name, StringComparer.OrdinalIgnoreCase) || (rid != DBNull.Value && Convert.ToInt32(r.Key) == Convert.ToInt32(rid)));
            Fill(m_replicate, members != null && members.Count > 0 ? string.Format("Lowest-numbered ({0})", members.OrderBy(x => x, StringComparer.Ordinal).First()) : "Lowest-numbered (default)", reps, rid);
            m_last.Text = Show(Value("EndYear"));
            int co2 = IntValue("Co2Series", 3);
            m_co2.SelectedIndex = co2 >= 1 && co2 <= 4 ? co2 - 1 : 2;
            m_ceiling.Text = Show(Value("Co2Ceiling"));
            m_reference.Text = Show(Value("Co2Reference"));
            m_ceiling.Enabled = m_reference.Enabled = m_adjust.Enabled = co2 != 1;
            m_defaults.Enabled = co2 != 1 && CanEdit;
            m_co2note.Text = co2 == 1 ? "CO2 fertilization is off: the projection's growth does not respond to CO2."
                           : (m_loaded.Length > 0 ? m_loaded + " " : "") + "Stage 11 writes the betas it used to Build Results > CO2 Fertilization Betas.";
            m_rescan.Enabled = !(this.Scenario != null && this.Scenario.IsResult) && this.ShouldEnableView();

            if (model == null) m_runs.Text = m_models.Count == 0 ? "No LOCA2 runs are listed in this library (Climate Models is empty)." : "";
            else if (scen != null && members == null) m_runs.Text = string.Format("{0} has no {1} run. It has: {2}.", model.Name, scen.Name, model.Runs);
            else m_runs.Text = string.Format("{0} runs: {1}.", model.Name, model.Runs);
            m_runs.ForeColor = scen != null && model != null && members == null ? Color.Firebrick : SystemColors.GrayText;
        }
    }
}
