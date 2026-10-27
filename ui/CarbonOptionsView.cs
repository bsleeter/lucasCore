// =============================================================================
// CarbonOptionsView.cs - the Carbon Options page: the dead organic matter decay choice as four described radio options
// =============================================================================
// Single-row sheet lucasCore_CarbonOptions, unchanged (DeadOrganicMatterModel 1-4, read by stage 3; 4 = measured, the default from
// 2026-10-27, to-do 19).
// =============================================================================
using System.Windows.Forms;

namespace lucasCoreUI
{
    public class CarbonOptionsView : LucasView
    {
        protected override string SheetName { get { return "lucasCore_CarbonOptions"; } }

        private readonly Choice m_dom = new Choice("DeadOrganicMatterModel", 4);

        public CarbonOptionsView()
        {
            this.SuspendLayout();
            var c = Column();
            c.Controls.Add(Option(m_dom, 4, "Measured dead wood (default)"));
            c.Controls.Add(Wrapped("Decay rates are calibrated to FIA's measured down woody material and standing dead trees in mature stands (age 60 and over): snag, down log and fine woody debris rates by ecodivision, litter and duff rates by ecodivision and forest type. Snag fall is set from remeasured dead trees, and soil is calibrated to gSSURGO soil organic carbon. Needs the FIA DataMart Folder (with the <ST>_COND_DWM_CALC tables) in Data Sources; without it stage 3 uses the next option.", 620));
            c.Controls.Add(Option(m_dom, 1, "Calibrated to FIA condition pools"));
            c.Controls.Add(Wrapped("Snag, down wood and forest floor decay rates are calibrated to FIA's condition-table dead wood and litter (down dead and litter are FIA model estimates) at every stand age, by ecodivision and forest type, and soil to gSSURGO soil organic carbon.", 620));
            c.Controls.Add(Option(m_dom, 2, "FIA condition pools, CBM-default soil"));
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
