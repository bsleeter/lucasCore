// =============================================================================
// CarbonCapacityView.cs - the Carbon Capacity Options page (Carbon Assumptions): how natural non-forest land counts in the capacity
// =============================================================================
// User 2026-11-18: "can we make this a simple selection rather than a dropdown? This way there can be some explanation text
// provided." Single-row sheet lucasCore_CarbonCapacityOptions (NaturalNonForest: 1 or blank = its own class, 2 = LANDFIRE BpS
// potential), unchanged; stage 8 reads it (src/capacity.R, capacity_natural). Two radio buttons, each with what it means, under a
// short account of what the capacity is.
// =============================================================================
using System;
using System.Windows.Forms;
using SyncroSim.Core;

namespace lucasCoreUI
{
    public class CarbonCapacityView : LucasView
    {
        protected override string SheetName { get { return "lucasCore_CarbonCapacityOptions"; } }
        private readonly Choice m_natural = new Choice("NaturalNonForest", 1);

        public CarbonCapacityView()
        {
            this.SuspendLayout();
            var what = Column();
            what.Controls.Add(Note("What the land would hold in live biomass, dead wood and litter under its potential natural vegetation and natural fire regime. The Build (stage 8) maps it; Run Figures and Compare Runs show a run as a share of it, and the deficit by cause."));
            what.Controls.Add(Note("Forest: the mean stock of a landscape of the forest type burning at its natural stand-replacing fire return interval, not the old-growth maximum (kept as an upper bound). A cell that is forest today keeps its type. Developed and farmed land takes what LANDFIRE Biophysical Settings (BpS) say it would carry. Soil is not counted."));
            AddGroup(Group("The carbon carrying capacity", what));

            var c = Column();
            c.Controls.Add(Option(m_natural, 1, "Its own class (annual NLCD)"));
            c.Controls.Add(Indent(Note("Grassland, shrubland and barren land is counted as what it is. The annual NLCD maps these main groups from satellite observations with relatively high accuracy; BpS is a modeled product. Forest cleared or burned before the start year that NLCD now maps as grass or shrub is taken as natural, so its deficit is not counted.")));
            c.Controls.Add(Option(m_natural, 2, "LANDFIRE BpS potential"));
            c.Controls.Add(Indent(Note("Such land counts as forest on the share of its 30 m pixels that BpS maps as forest potential, and as its own class on the rest. This counts land that lost its forest before the start year, but trusts BpS over NLCD everywhere: where BpS maps forest under natural meadow, parkland or shrub steppe, that land shows as far below its capacity.")));
            c.Controls.Add(Note("Takes effect at the next Build, or when stage 8 is rerun on the Build result. Runs already made can then be drawn against the new capacity without rerunning them."));
            AddGroup(Group("Natural grassland, shrubland and barren land counts as", c));
            EndGroups();
            this.ResumeLayout(false);
        }

        private static Control Indent(Label l) { l.Margin = new Padding(22, 0, 3, 8); return l; }

        public override void LoadDataFeed(DataFeed dataFeed)
        {
            base.LoadDataFeed(dataFeed);
            RefreshControls();
        }

        protected override void ShowData() { ShowChoice(m_natural); }
    }
}
