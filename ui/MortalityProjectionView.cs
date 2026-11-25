// =============================================================================
// MortalityProjectionView.cs - the Mortality page of a projection: drought and insect mortality after the historical end (to-do 3, lucasCore 2.0.2)
// =============================================================================
// Sheet lucasCore_MortalityProjection (single row; stage 9 reads it, src/mortality.R): historical rates or off, the years drawn
// together, the event's own reference years, and how it is placed (clustered: a fitted surface, the record's patch sizes and spread
// from recent die-off; or random cells). Blank = historical rates, blocks of 5, the Run Settings reference period, clustered.
// Timing and Amount (2.0.3): as this setup draws them, or from a Projection Climate result that depends on this setup (its page
// Mortality and Climate, sheet lucasCore_MortalityClimate: the blocks placed in the run's dry periods, the rate raised in them).
// A sheet of its own, apart from the Build's Mortality page (lucasCore_MortalityOptions): a Projection Setup that set a value on the
// Build's sheet would hide the Build's own row, and a new table needs no library update.
// =============================================================================
using System;
using System.Collections.Generic;
using System.Globalization;
using System.Windows.Forms;
using SyncroSim.Core;

namespace lucasCoreUI
{
    public class MortalityProjectionView : LucasView
    {
        protected override string SheetName { get { return "lucasCore_MortalityProjection"; } }

        private readonly Choice m_proj = new Choice("Projection", 1), m_place = new Choice("ProjectionPlacement", 1), m_link = new Choice("ClimateLink", 1);
        private readonly TextBox m_block = Box(60), m_rs = Box(60), m_re = Box(60);
        private readonly List<Control> m_settings = new List<Control>();

        public MortalityProjectionView()
        {
            this.SuspendLayout();
            RadioButton rates = Option(m_proj, 1, "Historical rates"), off = Option(m_proj, 2, "Off");
            AddGroup(Group("Drought and insect mortality after the historical end (set on the Projection Setup scenario)", ProjectionTransitionsView.Stack(
                Note("The Build maps the event for the historical period (Build > Mortality). This page sets what a projection does with it. " +
                     "If the Build has the event off, or mapped none, the projection has none either."),
                rates,
                Wrapped("The event continues at the rates of the record. Each iteration fills the projection years with blocks of consecutive historical years, " +
                        "so an outbreak of several years stays together. A drawn year gives each softwood forest type of an ecodivision (pinyon/juniper apart) " +
                        "the share of its standing forest that had the event that year. It is a rate on what still stands and is old enough, " +
                        "so the area falls as forest is used up and comes back as it regrows. A forest type with under 250 km2 in the study area takes the rate of its ecodivision as a whole.", 640),
                off,
                Wrapped("No drought and insect mortality after the historical end.", 640))));

            m_settings.Add(m_block); m_settings.Add(m_rs); m_settings.Add(m_re);
            AddGroup(Group("How much: the years the rates come from", ManagementActionsView.Lines(
                ManagementActionsView.Line("Years drawn together:", m_block, Note("Blank = 5. Longer blocks keep long outbreaks whole; shorter blocks give more variety between iterations.")),
                ManagementActionsView.Line("Reference years, from:", m_rs, Note("Blank = the start of the reference period of Run Settings.")),
                ManagementActionsView.Line("Reference years, to:", m_re, Note("Blank = its end. The record is 1986 to 2023 and its rate has risen, so these years set the projected amount more than any other choice. " +
                                                                                 "The stage 9 log gives the mean rate of the years chosen beside that of the whole record.")))));

            RadioButton clustered = Option(m_place, 1, "Clustered"), random = Option(m_place, 2, "Random cells");
            m_settings.Add(clustered); m_settings.Add(random);
            AddGroup(Group("Where it falls", ProjectionTransitionsView.Stack(
                clustered,
                Wrapped("Three things read from the maps of the Build place the die-off, and none of them changes the amount: " +
                        "a surface fitted to where the events fell (tree canopy cover; the temperature, precipitation and vapour pressure deficit normals; elevation; slope); " +
                        "the sizes of the yearly patches of the record; and spread from the die-off of the three years before, within three cells. " +
                        "The stage 9 log reports each of them. A piece the record cannot support (too few events) is left out, and the log says so.", 640),
                random,
                Wrapped("Every eligible cell of a unit has the same chance, and the event falls as single scattered cells.", 640))));

            // (2.0.3) the timing and amount handed to a Projection Climate result: this setup stays free of climate and serves any number of futures
            RadioButton asDrawn = Option(m_link, 1, "As this setup draws them"), fromClimate = Option(m_link, 2, "From the Projection Climate result");
            m_settings.Add(asDrawn); m_settings.Add(fromClimate);
            AddGroup(Group("Timing and amount: with or without the climate", ProjectionTransitionsView.Stack(
                asDrawn,
                Wrapped("The blocks fall where they are drawn, with no regard to the climate of the projection, and every climate future gets the same event. " +
                        "A projection needs nothing more.", 640),
                fromClimate,
                Wrapped("For exploring a climate response. This setup still draws the blocks, and holds no climate. A Projection Climate scenario that depends on this setup " +
                        "(below its Build) then places the more severe blocks in the dry periods of its climate run and can raise the rate in them: " +
                        "its page Mortality and Climate has the two settings, and with both blank the blocks stay as drawn. " +
                        "Every projection from this setup then needs such a Projection Climate result; without one ST-Sim stops, because the drawn years are missing.", 640))));

            AddGroup(Group("Where to see the result", ProjectionTransitionsView.Stack(
                Note("The stage 9 log has lines beginning \"Drought and insect mortality\". Projection Results > Projection Rates lists the units and their mean yearly area, " +
                     "and Projection Schedule lists the years drawn (sampling set Mortality)."))));
            EndGroups();

            BindRange(m_block, "BlockYears", 1, 50); BindRange(m_rs, "ReferenceStartYear", 1900, 2200); BindRange(m_re, "ReferenceEndYear", 1900, 2200);
            this.ResumeLayout(false);
        }

        // a whole-number box with the sheet's own limits: blank = DBNull, anything outside the limits or not a whole number is put back
        private void BindRange(TextBox t, string column, int lo, int hi)
        {
            t.Validated += (s, e) =>
            {
                if (Refreshing) return;
                string v = t.Text.Trim(); int d;
                if (v.Length == 0) Write(column, DBNull.Value);
                else if (int.TryParse(v, NumberStyles.Integer, CultureInfo.CurrentCulture, out d) && d >= lo && d <= hi) Write(column, d);
                RefreshControls();
            };
        }

        protected override void ShowData()
        {
            ShowChoice(m_proj); ShowChoice(m_place); ShowChoice(m_link);
            m_block.Text = Show(Value("BlockYears")); m_rs.Text = Show(Value("ReferenceStartYear")); m_re.Text = Show(Value("ReferenceEndYear"));
            bool on = IntValue("Projection", 1) != 2;
            foreach (Control c in m_settings) c.Enabled = on;
        }
    }
}
