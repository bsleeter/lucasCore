// =============================================================================
// CarbonOptionsView.cs - the Carbon Options page: the dead organic matter decay choice as three described radio options
// =============================================================================
// Single-row sheet lucasCore_CarbonOptions, unchanged (DeadOrganicMatterModel 1-3, read by stage 3).
// =============================================================================
using System.Windows.Forms;

namespace lucasCoreUI
{
    public class CarbonOptionsView : LucasView
    {
        protected override string SheetName { get { return "lucasCore_CarbonOptions"; } }

        private readonly Choice m_dom = new Choice("DeadOrganicMatterModel", 1);

        public CarbonOptionsView()
        {
            this.SuspendLayout();
            var c = Column();
            c.Controls.Add(Option(m_dom, 1, "Calibrated (default)"));
            c.Controls.Add(Wrapped("Snag, down wood and forest floor decay rates are calibrated to FIA dead wood and litter by ecodivision and forest type, and soil to gSSURGO soil organic carbon.", 620));
            c.Controls.Add(Option(m_dom, 2, "FIA dead pools, CBM-default soil"));
            c.Controls.Add(Wrapped("Snags, down wood and forest floor are calibrated to FIA as above; soil keeps the CBM-CFS3 default decay rates, so soil carbon comes from the spin-up alone.", 620));
            c.Controls.Add(Option(m_dom, 3, "CBM defaults (no calibration)"));
            c.Controls.Add(Wrapped("Every pool uses the CBM-CFS3 default decay rates, as the CONUS 1 km model did.", 620));
            AddGroup(Group("Dead organic matter decay", c));
            EndGroups();
            this.ResumeLayout(false);
        }

        public override void LoadDataFeed(SyncroSim.Core.DataFeed dataFeed) { base.LoadDataFeed(dataFeed); RefreshControls(); }

        protected override void ShowData() { ShowChoice(m_dom); }
    }
}
