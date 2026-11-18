// =============================================================================
// WetlandCarbonView.cs - Carbon Assumptions > Wetland Methane: the methane targets, their ranges, the wetland Q10s, the cap and the
// CO2 equivalent of methane (src/wetland-params.R)
// =============================================================================
// Feed WetlandCarbon: lucasCore_WetlandOptions (one row: MethaneQ10, SoilQ10, MethaneCapShare, MethaneCO2e, UncertaintyDraws),
// lucasCore_WetlandMethaneTarget (Class, Region, Target, Low, High) and lucasCore_MarshSalinityTarget (Region, Zone, Target, Low, High).
// Everything left blank or empty is the package value (defaults/stockflow/wetland-methane-targets.csv and marsh-salinity-ch4.csv;
// the option defaults below are WETLAND_OPTION_DEFAULTS of src/wetland-params.R). Fill writes the package targets as rows so they can
// be read and changed. A target with a low and a high is drawn within that range in the first Uncertainty Draws iterations of a run.
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
    public class WetlandCarbonView : LucasView
    {
        protected override string SheetName { get { return "lucasCore_WetlandOptions"; } }
        private const string TARGETS = "lucasCore_WetlandMethaneTarget", ZONES = "lucasCore_MarshSalinityTarget";
        // column, package value, integer
        private static readonly object[][] Options = {
            new object[] { "MethaneQ10", "3.83", false }, new object[] { "SoilQ10", "2", false }, new object[] { "MethaneCapShare", "0.3", false },
            new object[] { "MethaneCO2e", "33.5", false }, new object[] { "UncertaintyDraws", "0", true } };

        private readonly Dictionary<string, TextBox> m_box = new Dictionary<string, TextBox>();
        private readonly Panel m_targets = GridHost(300);
        private readonly Panel m_zones = GridHost(260);
        private readonly Button m_fill = new Button { Text = "Fill with the package targets", AutoSize = true, Margin = new Padding(3, 3, 12, 3) };
        private readonly Label m_state = new Label { AutoSize = true, MaximumSize = new Size(640, 0), ForeColor = SystemColors.GrayText, Margin = new Padding(3, 8, 3, 3) };

        public WetlandCarbonView()
        {
            this.SuspendLayout();
            foreach (object[] o in Options) { TextBox t = Box(70); m_box[(string)o[0]] = t; string col = (string)o[0]; BindNumber(t, () => Sheet, col, (bool)o[2]); }
            var f = Form();
            FormRow(f, "Methane Q10", m_box["MethaneQ10"], "How fast methane release rises with temperature, from wetland soil and root litter alike (blank = 3.83, the value of Yvon-Durocher et al. 2014 between 10 and 20 C).");
            FormRow(f, "Wetland soil CO2 Q10", m_box["SoilQ10"], "The same for the CO2 of wetland soil (blank = 2.0). The soil of every other class has no temperature response.");
            FormRow(f, "Methane cap", m_box["MethaneCapShare"], "The most of a wetland's belowground emission that may leave as methane, as a share (blank = 0.3). A target that asks for more is held here, and the Build log says how much is released.");
            FormRow(f, "CO2 equivalent of methane", m_box["MethaneCO2e"], "Mg CO2e per Mg of carbon emitted as methane, for every methane flow of the model, fire included (blank = 33.5, a 100-year warming potential of 25; 27 gives 36).");
            FormRow(f, "Uncertainty draws", m_box["UncertaintyDraws"], "The number of Monte Carlo iterations that draw their methane targets from the low-to-high ranges below (blank or 0 = none: every iteration runs at the targets). Later iterations run at the targets. The package targets have literature ranges of their own, so a number here is enough to turn the uncertainty on.");
            AddGroup(Group("Wetland methane (stages 0, 3, 7 and 8)", ProjectionTransitionsView.Stack(
                Note("Wetlands release part of the carbon their soil and root litter emit as methane. The targets below say how much, in Mg C per hectare per year as CH4, at the normal climate; the Build turns each into a share of the class's belowground emission, so the soil and litter lose what they always did. Leave a box blank and a table empty to use the package values."),
                f)));
            AddGroup(Group("Methane targets by class", ProjectionTransitionsView.Stack(
                Note("One row per wetland class, or per class and region (a row without a region sets every region of the class; a region's own row wins there). Low and high are optional: with both a target and a range, an uncertainty draw takes a value between them, most often near the target."),
                m_targets)));
            AddGroup(Group("Estuarine marsh by salinity zone", ProjectionTransitionsView.Stack(
                Note("An estuarine emergent cell takes the targets of the salinity zones LANDFIRE maps in it (fresh and oligohaline, salt and brackish; brackish and salt apart on the northern Atlantic coast), weighted by their share of the cell, in place of its class target."),
                m_zones)));
            var r = Row(); r.Controls.Add(m_fill); r.Controls.Add(m_state);
            AddGroup(Group("Package values", ProjectionTransitionsView.Stack(
                Note("Fill writes the package targets and their literature ranges into both tables, replacing their rows, so they can be read and changed. A row here replaces the package's target and range together: leave low and high blank for no range."), r)));
            EndGroups();
            m_fill.Click += (s, e) => Fill();
            this.ResumeLayout(false);
        }

        private DataSheet Ds(string name) { return this.DataFeed.GetDataSheet(name); }
        private static int Rows(DataSheet ds) { return ds != null && ds.HasData() ? ds.GetData().Rows.Cast<DataRow>().Count(x => x.RowState != DataRowState.Deleted) : 0; }

        public override void LoadDataFeed(DataFeed dataFeed)
        {
            base.LoadDataFeed(dataFeed);
            LoadGrid(m_targets, TARGETS);
            LoadGrid(m_zones, ZONES);
            RefreshControls();
        }

        private void Fill()
        {
            if ((Rows(Ds(TARGETS)) > 0 || Rows(Ds(ZONES)) > 0) && MessageBox.Show(this, "Replace every row of both tables with the package targets?", "Wetland Methane", MessageBoxButtons.OKCancel, MessageBoxIcon.Question) != DialogResult.OK) return;
            List<string> p = Defaults.Load(Ds(TARGETS), Defaults.PackageFile("defaults", "stockflow", "wetland-methane-targets.csv"), null);
            p.AddRange(Defaults.Load(Ds(ZONES), Defaults.PackageFile("defaults", "stockflow", "marsh-salinity-ch4.csv"), new Dictionary<string, string> { { "CH4", "Target" }, { "CH4Low", "TargetLow" }, { "CH4High", "TargetHigh" } }));
            LoadGrid(m_targets, TARGETS);
            LoadGrid(m_zones, ZONES);
            RefreshControls();
            if (p.Count > 0) { m_state.Text = "Loaded, except: " + string.Join("; ", p.Take(5)) + (p.Count > 5 ? string.Format(" (+{0} more)", p.Count - 5) : ""); m_state.ForeColor = Color.Firebrick; }
        }

        protected override void ShowData()
        {
            foreach (object[] o in Options) m_box[(string)o[0]].Text = Show(Value((string)o[0]));
            bool can = this.Scenario != null && !this.Scenario.IsResult && this.ShouldEnableView();
            m_fill.Enabled = can;
            int nt = Rows(Ds(TARGETS)), nz = Rows(Ds(ZONES));
            var blank = Options.Where(o => Value((string)o[0]) == DBNull.Value).Select(o => (string)o[0]).ToList();
            m_state.ForeColor = SystemColors.GrayText;
            m_state.Text = string.Format("{0}; {1}; {2}.",
                nt == 0 ? "class targets: the package values" : string.Format("class targets: {0} rows in this scenario", nt),
                nz == 0 ? "salinity zones: the package values" : string.Format("salinity zones: {0} rows in this scenario", nz),
                blank.Count == Options.Length ? "settings: the package values" : string.Format("settings: {0} of {1} set here", Options.Length - blank.Count, Options.Length));
        }
    }
}
