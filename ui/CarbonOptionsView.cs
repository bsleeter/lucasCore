// =============================================================================
// CarbonOptionsView.cs - the Carbon Method page (first page of Carbon Assumptions): the dead organic matter method, the soil organic
// carbon source, and a Fill button that writes the method's rows into the other Carbon Assumptions sheets
// =============================================================================
// Single-row sheet lucasCore_CarbonOptions: DeadOrganicMatterModel 4 = FIA measured dead wood (default), 3 = CBM defaults (1 and 2, the
// FIA condition-pool options, are no longer offered, user 2026-10-28; stage 3 still reads them); SoilCarbonModel 1 = gSSURGO, 2 = CBM
// defaults, blank = gSSURGO with FIA measured dead wood and CBM with CBM defaults (the page shows the one that applies). Fill loads
// defaults/carbon-assumptions/<method>/<sheet>.csv (tools/make_carbon_presets.R) into each sheet of this scenario, replacing its rows -
// the same rows stage 3 uses when the sheets were never filled.
// =============================================================================
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Linq;
using System.Windows.Forms;
using SyncroSim.Core;

namespace lucasCoreUI
{
    public class CarbonOptionsView : LucasView
    {
        protected override string SheetName { get { return "lucasCore_CarbonOptions"; } }

        private readonly Choice m_dom = new Choice("DeadOrganicMatterModel", 4);
        private readonly Choice m_soil = new Choice("SoilCarbonModel", 1);
        private readonly Button m_fill = new Button { AutoSize = true, Margin = new Padding(3, 3, 12, 3) };
        private readonly Label m_state = new Label { AutoSize = true, MaximumSize = new Size(640, 0), Margin = new Padding(3, 8, 3, 3) };
        private bool m_filled, m_done;

        // sheet, preset file (defaults/carbon-assumptions/<method>/<file>.csv), page name
        private static readonly string[][] Sheets = {
            new[] { "lucasCore_GrowthInput", "growth-inputs", "Growth Inputs" },
            new[] { "lucasCore_CbmCrosswalk", "cbm-crosswalk", "CBM Crosswalk" },
            new[] { "lucasCore_DomParameter", "dom-parameters", "Dead Organic Matter Parameters" },
            new[] { "lucasCore_LiveTurnover", "live-turnover", "Live Turnover" },
            new[] { "lucasCore_Spinup", "spin-up", "Spin-up" },
            new[] { "lucasCore_DisturbanceFlow", "disturbance-flows", "Disturbance Flows" },
            new[] { "lucasCore_FireSnagShare", "fire-snag-share", "Fire Snag Share" },
            new[] { "lucasCore_DecayCalibrationSetting", "decay-calibration-settings", "Decay Calibration Settings" },
            new[] { "lucasCore_MatureAge", "mature-age", "Mature Age by Forest Type" },
            new[] { "lucasCore_FixedDecayMultiplier", "fixed-decay-multipliers", "Fixed Decay Multipliers" },
            new[] { "lucasCore_NonForestGrowth", "nonforest-growth", "Non-Forest Growth" },
            new[] { "lucasCore_NonForestRate", "nonforest-rates", "Non-Forest Rates" } };
        // a scenario counts as filled when any of these has rows (stage 3's rule)
        private static readonly string[] Key = { "lucasCore_CbmCrosswalk", "lucasCore_DomParameter", "lucasCore_DisturbanceFlow" };

        public CarbonOptionsView()
        {
            this.SuspendLayout();
            var d = Column();
            d.Controls.Add(Option(m_dom, 4, "FIA measured dead wood (default)"));
            d.Controls.Add(Wrapped("Decay rates are calibrated to FIA's measured down woody material and standing dead trees in mature stands: snag, down log and fine woody debris rates by ecodivision, litter and duff rates by ecodivision and forest type. Snag fall comes from remeasured dead trees; fire and clearcut flows are fitted to FIA plots after those events. Needs the FIA DataMart Folder (with the <ST>_COND_DWM_CALC tables) in Data Sources.", 620));
            d.Controls.Add(Option(m_dom, 3, "CBM defaults (no calibration)"));
            d.Controls.Add(Wrapped("Every dead pool uses the CBM-CFS3 default decay and snag fall rates, with the LUCAS fire and clearcut flows, as the CONUS 1 km model did.", 620));
            AddGroup(Group("Dead organic matter", d));
            var s = Column();
            s.Controls.Add(Option(m_soil, 1, "gSSURGO"));
            s.Controls.Add(Wrapped("Soil decay is calibrated so the spin-up's soil carbon matches each ecodivision and forest type's mean gSSURGO soil organic carbon (Data Sources: Soil Carbon).", 620));
            s.Controls.Add(Option(m_soil, 2, "CBM defaults"));
            s.Controls.Add(Wrapped("Soil keeps the CBM-CFS3 default decay rates, so soil carbon comes from the spin-up alone. (SoilGrids is planned as a further source.)", 620));
            AddGroup(Group("Soil organic carbon", s));
            var f = Column();
            f.Controls.Add(Note("The other Carbon Assumptions pages hold the rates and settings the method uses. Fill writes the chosen method's rows into all of them, replacing what is there; edit any row afterwards. A scenario never filled runs with the same rows."));
            var r = Row(); r.Controls.Add(m_fill); r.Controls.Add(m_state); f.Controls.Add(r);
            AddGroup(Group("Carbon Assumptions sheets", f));
            EndGroups();
            m_fill.Click += (o, e) => Fill();
            this.ResumeLayout(false);
        }

        private int Method { get { return IntValue(m_dom.Column, m_dom.Default); } }
        private string Folder { get { return Method == 3 ? "cbm-defaults" : "fia-measured"; } }
        private string MethodName { get { return Method == 3 ? "CBM defaults" : "FIA measured dead wood"; } }

        public override void LoadDataFeed(DataFeed dataFeed)
        {
            base.LoadDataFeed(dataFeed);
            m_filled = Key.Any(k => { DataSheet ds = this.Scenario == null ? null : this.Scenario.GetDataSheet(k); return ds != null && ds.HasData(); });
            RefreshControls();
        }

        private void Fill()
        {
            if (MessageBox.Show(this, string.Format("Replace the rows of {0} with the {1} rows?", string.Join(", ", Sheets.Select(x => x[2])), MethodName),
                                "Carbon Method", MessageBoxButtons.OKCancel, MessageBoxIcon.Question) != DialogResult.OK) return;
            var problems = new List<string>();
            foreach (string[] x in Sheets)
            {
                DataSheet ds = this.Scenario.GetDataSheet(x[0]);
                if (ds == null) { problems.Add(x[2] + ": not in this library (run tools/sync-library.R)"); continue; }
                foreach (string p in Defaults.Load(ds, Defaults.PackageFile("defaults", "carbon-assumptions", Folder, x[1] + ".csv"), null)) problems.Add(x[2] + ": " + p);
            }
            if (Value(m_soil.Column) == DBNull.Value) Write(m_soil.Column, Method == 3 ? 2 : 1);   // the soil source the method implies, written out
            m_filled = true; m_done = true;
            m_state.Text = problems.Count == 0 ? string.Format("Filled with the {0} rows. Edit any page; Fill again to start over.", MethodName)
                                               : "Filled, except: " + string.Join("; ", problems.Take(5)) + (problems.Count > 5 ? string.Format(" (+{0} more)", problems.Count - 5) : "");
            m_state.ForeColor = problems.Count == 0 ? SystemColors.GrayText : Color.Firebrick;
            RefreshControls();
        }

        protected override void ShowData()
        {
            ShowChoice(m_dom);
            int soil = IntValue(m_soil.Column, Method == 3 ? 2 : 1);   // blank: the source the method implies
            foreach (RadioButton rb in m_soil.Buttons) rb.Checked = (int)rb.Tag == soil;
            m_fill.Text = string.Format("Fill with the {0} rows", MethodName);
            m_fill.Enabled = !(this.Scenario != null && this.Scenario.IsResult) && this.ShouldEnableView();
            if (m_done) return;
            m_state.Text = m_filled ? "The sheets have rows: a run uses them as they are."
                                    : string.Format("The sheets are empty: a run uses the {0} rows. Fill to see and edit them.", MethodName);
            m_state.ForeColor = m_filled ? SystemColors.GrayText : Color.DarkGoldenrod;
        }
    }
}
