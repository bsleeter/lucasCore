// =============================================================================
// ClimateOptionsView.cs - the Climate Options page: historical climate effects as radio choices, and the LOCA2 projection run
// =============================================================================
// Single-row sheet lucasCore_ClimateOptions, unchanged. The projection group is on only when Build Options has a projection (a
// ProjectionEndYear); its model list keeps the models that have a run for the chosen scenario, and the replicate list the ensemble
// members of that model and scenario (from the Runs column new-library.R writes: "SSP2-4.5: r1i1p1f1, r2i1p1f1; SSP3-7.0: ...").
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
    public class ClimateOptionsView : LucasView
    {
        protected override string SheetName { get { return "lucasCore_ClimateOptions"; } }

        private class Item { public object Key; public string Name; public string Runs; public override string ToString() { return Name; } }

        private readonly Choice m_forest = new Choice("ForestGrowthModel", 3);
        private readonly Choice m_nonForest = new Choice("NonForestGrowthModel", 2);
        private readonly Choice m_decomp = new Choice("DecompositionModel", 2);
        private readonly ComboBox m_scenario = List(160);
        private readonly ComboBox m_model = List(200);
        private readonly ComboBox m_replicate = List(200);
        private readonly Label m_projState = new Label { AutoSize = true, Margin = new Padding(3, 3, 3, 8) };
        private readonly Label m_runs = new Label { AutoSize = true, MaximumSize = new Size(640, 0), ForeColor = SystemColors.GrayText, Margin = new Padding(3, 6, 3, 3) };
        private GroupBox m_gProj;
        private List<Item> m_scenarios = new List<Item>(), m_models = new List<Item>(), m_replicates = new List<Item>();

        public ClimateOptionsView()
        {
            this.SuspendLayout();
            var hist = Column();
            hist.Controls.Add(Note("Year-to-year multipliers from PRISM, relative to each cell's 1991-2020 normal (1 = the climate the curves were fitted to)."));
            hist.Controls.Add(ChoiceRow("Forest growth:", m_forest, new[] { 1, 2, 3 }, new[] { "None", "Miami NPP", "Tree ring (default)" }));
            hist.Controls.Add(Wrapped("Tree ring: growth responds to this year's and last year's precipitation and to temperature, fitted to 1,288 ITRDB chronologies by ecodivision. Miami NPP swings about twice as much from year to year.", 640));
            hist.Controls.Add(ChoiceRow("Non-forest growth:", m_nonForest, new[] { 1, 2 }, new[] { "None", "Miami NPP (default)" }));
            hist.Controls.Add(ChoiceRow("Decomposition:", m_decomp, new[] { 1, 2 }, new[] { "None", "Q10 (default)" }));
            AddGroup(Group("Climate effects", hist));

            var proj = Column();
            proj.Controls.Add(m_projState);
            var f = Form();
            FormRow(f, "Scenario:", m_scenario, null);
            FormRow(f, "Climate model:", m_model, null);
            FormRow(f, "Replicate:", m_replicate, null);
            proj.Controls.Add(f);
            proj.Controls.Add(m_runs);
            m_gProj = Group("Projection climate (LOCA2)", proj);
            AddGroup(m_gProj);
            EndGroups();
            m_scenario.SelectionChangeCommitted += (s, e) => { Write("ClimateScenarioId", Key(m_scenario)); RefreshControls(); };
            m_model.SelectionChangeCommitted += (s, e) => { Write("ClimateModelId", Key(m_model)); RefreshControls(); };
            m_replicate.SelectionChangeCommitted += (s, e) => { Write("ClimateReplicateId", Key(m_replicate)); RefreshControls(); };
            this.ResumeLayout(false);
        }

        private FlowLayoutPanel ChoiceRow(string caption, Choice c, int[] values, string[] names)
        {
            var r = Row();
            var cap = Caption(caption); cap.Width = 120; cap.AutoSize = false; cap.Height = 22;
            r.Controls.Add(cap);
            for (int i = 0; i < values.Length; i++) r.Controls.Add(Option(c, values[i], names[i]));
            return r;
        }

        private static object Key(ComboBox c) { var i = c.SelectedItem as Item; return i == null ? DBNull.Value : i.Key; }

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
            Project p = this.DataFeed.Project;
            m_scenarios = Read(p, "lucasCore_ClimateScenario", "ClimateScenarioId", false);
            m_models = Read(p, "lucasCore_ClimateModel", "ClimateModelId", true);
            m_replicates = Read(p, "lucasCore_ClimateReplicate", "ClimateReplicateId", false);
            RefreshControls();
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
            ShowChoice(m_forest); ShowChoice(m_nonForest); ShowChoice(m_decomp);

            DataSheet bo = this.DataFeed.Scenario == null ? null : this.DataFeed.Scenario.GetDataSheet("lucasCore_BuildOptions");
            object pend = Value(bo, "ProjectionEndYear");
            bool projecting = pend != DBNull.Value;
            m_projState.Text = projecting
                ? string.Format("Build Options projects to {0}. Choose the LOCA2 run whose climate drives it.", pend)
                : "No projection: Run a projection is off in Build Options, so these settings are not used.";
            m_projState.ForeColor = projecting ? SystemColors.ControlText : SystemColors.GrayText;
            m_scenario.Enabled = m_model.Enabled = m_replicate.Enabled = projecting;

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

            if (model == null) m_runs.Text = m_models.Count == 0 ? "No LOCA2 runs are listed in this library (Climate Models is empty)." : "";
            else if (scen != null && members == null) m_runs.Text = string.Format("{0} has no {1} run. It has: {2}.", model.Name, scen.Name, model.Runs);
            else m_runs.Text = string.Format("{0} runs: {1}.", model.Name, model.Runs);
            m_runs.ForeColor = scen != null && model != null && members == null ? Color.Firebrick : SystemColors.GrayText;
        }
    }
}
