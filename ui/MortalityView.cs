// =============================================================================
// MortalityView.cs - the Mortality page of a Build: drought and insect mortality (to-do 3, lucasCore 2.0; page 2.0.1)
// =============================================================================
// User 2026-11-24: the settings were a plain grid in the Projection group; they belong with the Build's pages, "presented in a more
// friendly way in the UI with some detailed description around the parameters". Sheet lucasCore_MortalityOptions (single row): the
// event on or off, how it is placed on the grid, a canopy-loss line in place of the shipped ones (and pinyon/juniper's), the minimum
// stand age. Stage 6 reads it (src/mortality.R); blank = on, ranked selection, the shipped lines, 20 years.
// The table of shipped lines is read from defaults/transitions/mortality-lines.csv, so the page shows what the Build will use.
// =============================================================================
using System;
using System.Collections.Generic;
using System.Data;
using System.Drawing;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Windows.Forms;
using SyncroSim.Core;

namespace lucasCoreUI
{
    public class MortalityView : LucasView
    {
        protected override string SheetName { get { return "lucasCore_MortalityOptions"; } }

        private readonly CheckBox m_on = new CheckBox { Text = "Map drought and insect mortality", AutoSize = true, Margin = new Padding(3, 5, 12, 3) };
        private readonly Choice m_place = new Choice("Placement", 1);
        private readonly TextBox m_line = Box(60), m_pj = Box(60), m_age = Box(60);
        private readonly List<Control> m_settings = new List<Control>();

        public MortalityView()
        {
            this.SuspendLayout();
            AddGroup(Group("What this event is", ProjectionTransitionsView.Stack(
                Note("High-severity die-off from drought, insects or disease: a stand that loses most of its live trees within a few years, with no fire and no cutting. " +
                     "Partial mortality is not part of it; that is already in the yearly background rate of the growth curves and stem turnover."),
                Note("The Build maps it for the historical period, 1990 to 2023 (1986 to 1990 share the first year's area), in the western ecodivisions listed below. " +
                     "East of them it writes no events. A projection keeps the event off; projected rates are to follow."),
                Note("A cell that takes the event goes to its forest type's Disturbed class with its age reset, as after high-severity fire. " +
                     "How much live carbon moves to dead pools is set under Carbon Assumptions > Disturbance Flows (83% by default; nothing is emitted in the event year)."))));

            AddGroup(Group("The event (set on the Build scenario; needs a new Build)", ManagementActionsView.Lines(
                ManagementActionsView.Line("Event:", m_on, Note("Off writes no mortality events, and the Build is as it was before lucasCore 2.0.")))));

            RadioButton ranked = Option(m_place, 1, "Ranked selection"), prob = Option(m_place, 2, "Fraction as probability");
            m_settings.Add(ranked); m_settings.Add(prob);
            AddGroup(Group("How events are placed on the model grid", ProjectionTransitionsView.Stack(
                Note("The rule is applied to 30 m pixels, so a model cell is usually only partly marked. This sets how a cell's marked share becomes an event."),
                ranked,
                Wrapped("Each year the cells are ranked by their marked share and taken from the top until their area equals the year's marked area. " +
                        "A chosen cell takes the event whole. Every iteration of the historical run has the same die-off in the same cells, and the yearly area matches the map. " +
                        "Scattered mortality is gathered into the most affected cells, so this suits fine grids (300 m or less) best.", 640),
                prob,
                Wrapped("Each cell's marked share is its chance of taking the event that year, as fire and harvest are placed. " +
                        "The area is right on average and differs between iterations. Use it on coarse grids (about 1 km), where few cells are mostly marked.", 640))));

            m_settings.Add(m_line); m_settings.Add(m_pj);
            AddGroup(Group("Canopy loss that counts as high severity", ProjectionTransitionsView.Stack(
                Note("A pixel is marked when its tree canopy cover has fallen by at least this share of its value five years before, inside an area where LCMS maps insect, disease or drought stress. " +
                     "The package ships one line per ecodivision, set so the marked area matches the share of FIA stands that lost 70% or more of their live carbon between visits. " +
                     "A lower line marks more area; a higher line marks less."),
                ShippedLines(),
                ManagementActionsView.Lines(
                    ManagementActionsView.Line("Use one line instead:", m_line, Note("A share from 0.01 to 1 (0.30 = a 30% loss), used in every ecodivision listed above. Blank = each ecodivision's own line.")),
                    ManagementActionsView.Line("Pinyon/juniper line:", m_pj, Note("Pinyon/juniper woodland is judged on a line of its own, fitted apart from the other softwoods. Blank = the shipped line."))))));

            m_settings.Add(m_age);
            AddGroup(Group("Stands that can take the event", ManagementActionsView.Lines(
                ManagementActionsView.Line("Minimum stand age:", m_age, Note("Years (blank = 20). A younger stand is passed over, so regrowth after a fire, a cut or an earlier die-off does not die again at once.")))));

            AddGroup(Group("What the Build needs, and where to see the result", ProjectionTransitionsView.Stack(
                Note("Data: USFS Tree Canopy Cover, LCMS, Annual NLCD and the USFS forest type groups for the study area, 1985 on. Tick them on the Data Download page. A Build in the West stops and names what is missing."),
                Note("Result: the stage 6 log has a line beginning \"Drought and insect mortality\" with the area marked, placed and set aside. " +
                     "Build Results > Historical Transition Summary lists the area by year, and the Build's disturbance history figure shows it beside fire and harvest."))));
            EndGroups();

            m_on.CheckedChanged += (s, e) => { if (!Refreshing) { Write("Enabled", m_on.Checked ? -1 : 0); RefreshControls(); } };
            BindRange(m_line, "CanopyLossLine", 0.01, 1, false); BindRange(m_pj, "PinyonJuniperLine", 0.01, 1, false); BindRange(m_age, "MinimumAge", 0, 500, true);
            this.ResumeLayout(false);
        }

        // a number box with the sheet's own limits: blank = DBNull, anything outside the limits or not a number is put back
        private void BindRange(TextBox t, string column, double lo, double hi, bool integer)
        {
            t.Validated += (s, e) =>
            {
                if (Refreshing) return;
                string v = t.Text.Trim(); double d;
                if (v.Length == 0) Write(column, DBNull.Value);
                else if (double.TryParse(v, NumberStyles.Float, CultureInfo.CurrentCulture, out d) && d >= lo && d <= hi && (!integer || d == Math.Floor(d)))
                    Write(column, integer ? (object)Convert.ToInt32(d) : d);
                RefreshControls();
            };
        }

        // the lines the package ships (defaults/transitions/mortality-lines.csv) with each ecodivision's name, as a read-only table
        private static Control ShippedLines()
        {
            var t = new TableLayoutPanel { AutoSize = true, ColumnCount = 4, Margin = new Padding(3, 4, 3, 8), CellBorderStyle = TableLayoutPanelCellBorderStyle.Single };
            for (int i = 0; i < 4; i++) t.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));
            Action<int, string[], bool> add = (r, cells, head) =>
            {
                t.RowCount = r + 1; t.RowStyles.Add(new RowStyle(SizeType.AutoSize));
                for (int c = 0; c < cells.Length; c++)
                    t.Controls.Add(new Label { Text = cells[c], AutoSize = true, Margin = new Padding(6, 3, 10, 3), Tag = Fit.Fixed,
                                               Font = head ? new Font(SystemFonts.DefaultFont, FontStyle.Bold) : SystemFonts.DefaultFont,
                                               ForeColor = head ? SystemColors.ControlText : SystemColors.GrayText }, c, r);
            };
            try
            {
                var names = new Dictionary<string, string>();
                foreach (string[] r in Defaults.ReadCsv(Defaults.PackageFile("defaults", "stsim", "stsim_Stratum.csv")).Skip(1)) if (r.Length > 1) names[r[1].Trim()] = r[0].Trim();
                List<string[]> rows = Defaults.ReadCsv(Defaults.PackageFile("defaults", "transitions", "mortality-lines.csv"));
                string[] h = rows[0]; int ce = Array.IndexOf(h, "Ecodivision"), cg = Array.IndexOf(h, "ForestGroups"), cl = Array.IndexOf(h, "Line"), cb = Array.IndexOf(h, "Basis");
                var eco = new List<string>(); var soft = new Dictionary<string, string>(); var pj = new Dictionary<string, string>(); var basis = new Dictionary<string, string>();
                foreach (string[] r in rows.Skip(1))
                {
                    if (r.Length <= Math.Max(Math.Max(ce, cg), Math.Max(cl, cb))) continue;
                    string e = r[ce].Trim(); if (!eco.Contains(e)) eco.Add(e);
                    string line = double.Parse(r[cl], CultureInfo.InvariantCulture).ToString("0.00", CultureInfo.CurrentCulture);
                    if (r[cg].Trim() == "pinyon/juniper") pj[e] = line; else { soft[e] = line; basis[e] = r[cb].Trim().StartsWith("own") ? "its own FIA stands" : "the western ecodivisions pooled"; }
                }
                add(0, new[] { "Ecodivision", "Line", "Pinyon/juniper", "Fitted to" }, true);
                int n = 1;
                foreach (string e in eco.OrderBy(x => basis.ContainsKey(x) && basis[x].StartsWith("its own") ? 0 : 1).ThenBy(x => x))
                {
                    // the ecodivision's stratum Id: 260 -> 260, M260 -> 2601
                    string id = e.StartsWith("M") ? e.Substring(1) + "1" : e, name = names.ContainsKey(id) ? names[id] : e;
                    add(n++, new[] { name + " (" + e + ")", soft.ContainsKey(e) ? soft[e] : "", pj.ContainsKey(e) ? pj[e] : "", basis.ContainsKey(e) ? basis[e] : "" }, false);
                }
            }
            catch (Exception)
            {
                return Note("The table of shipped lines (defaults/transitions/mortality-lines.csv) could not be read.");
            }
            return t;
        }

        protected override void ShowData()
        {
            object on = Value("Enabled"); m_on.Checked = on == DBNull.Value || Convert.ToBoolean(on);
            ShowChoice(m_place);
            m_line.Text = ShowNumber(Value("CanopyLossLine")); m_pj.Text = ShowNumber(Value("PinyonJuniperLine")); m_age.Text = Show(Value("MinimumAge"));
            foreach (Control c in m_settings) c.Enabled = m_on.Checked;
        }

        private static string ShowNumber(object v) { return v == DBNull.Value || v == null ? "" : Convert.ToDouble(v).ToString("0.###", CultureInfo.CurrentCulture); }
    }
}
