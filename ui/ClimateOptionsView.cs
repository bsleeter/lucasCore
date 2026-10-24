// =============================================================================
// ClimateOptionsView.cs - the Climate Options page of a Build: the historical climate effects as radio choices
// =============================================================================
// Single-row sheet lucasCore_ClimateOptions. The LOCA2 run that drives projections is no longer chosen here (its columns are kept,
// hidden, for older libraries): a Projection Climate scenario (stage 11, ProjectionClimateView) chooses it on the Build's result, using
// the effects chosen on this page.
// =============================================================================
using System;
using System.Drawing;
using System.Windows.Forms;
using SyncroSim.Core;

namespace lucasCoreUI
{
    public class ClimateOptionsView : LucasView
    {
        protected override string SheetName { get { return "lucasCore_ClimateOptions"; } }

        private readonly Choice m_forest = new Choice("ForestGrowthModel", 3);
        private readonly Choice m_nonForest = new Choice("NonForestGrowthModel", 2);
        private readonly Choice m_decomp = new Choice("DecompositionModel", 2);

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
            proj.Controls.Add(Note("The same effects apply in projections. The climate that drives a projection, a LOCA2 scenario, climate model and replicate, is chosen in a Projection Climate scenario that depends on this Build's result (stage 11, Projection > Climate), so one Build serves any number of climate futures."));
            AddGroup(Group("Projection climate", proj));
            EndGroups();
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

        protected override void ShowData() { ShowChoice(m_forest); ShowChoice(m_nonForest); ShowChoice(m_decomp); }
    }
}
