// =============================================================================
// MortalityClimateView.cs - the Mortality and Climate page of a Projection Climate scenario (lucasCore 2.0.3)
// =============================================================================
// Sheet lucasCore_MortalityClimate (single row; stage 11 reads it, src/mortality.R): two settings for exploring a climate response of
// drought and insect mortality. Each is a slider in steps of 5 (timing strength 0 to 1 in steps of 0.05, the increase in dry periods
// 0 to 200 percent in steps of 5) beside a box that takes any value in the range, and a sentence under it that says what the value
// now set does. Blank = 0 = off. The sentences' figures are those of the record and of the trials in dev/mortality/29 (three
// pyromes): the driest third of years against the wettest by timing strength, and the change in the total by percentage.
// =============================================================================
using System;
using System.Drawing;
using System.Globalization;
using System.Windows.Forms;
using SyncroSim.Core;

namespace lucasCoreUI
{
    public class MortalityClimateView : LucasView
    {
        protected override string SheetName { get { return "lucasCore_MortalityClimate"; } }

        private const double TIMING_STEP = 0.05, AMOUNT_STEP = 5, AMOUNT_MAX = 200, DEPTH_CAP = 2;
        private readonly TrackBar m_timing = Slider(20, 2), m_amount = Slider(40, 4);
        private readonly TextBox m_timingBox = Box(60), m_amountBox = Box(60);
        private readonly Label m_timingSays = Says(), m_amountSays = Says();

        private static TrackBar Slider(int steps, int tick) { return new TrackBar { Minimum = 0, Maximum = steps, TickFrequency = tick, SmallChange = 1, LargeChange = tick, AutoSize = false, Size = new Size(300, 30), Margin = new Padding(0, 2, 0, 0) }; }
        private static Label Says() { return new Label { AutoSize = true, MaximumSize = new Size(640, 0), Margin = new Padding(22, 2, 3, 8) }; }
        private static Label End(string text) { return new Label { Text = text, AutoSize = true, Margin = new Padding(3, 7, 3, 3), Tag = Fit.Fixed }; }
        private static FlowLayoutPanel SliderLine(string low, TrackBar t, string high, TextBox box, string unit)
        {
            var f = new FlowLayoutPanel { AutoSize = true, WrapContents = false, Margin = new Padding(19, 0, 0, 0) };
            f.Controls.Add(End(low)); f.Controls.Add(t); f.Controls.Add(End(high)); box.Margin = new Padding(18, 3, 3, 3); f.Controls.Add(box); f.Controls.Add(End(unit));
            return f;
        }

        public MortalityClimateView()
        {
            this.SuspendLayout();
            AddGroup(Group("Drought and insect mortality and the climate of this run (for exploring; both off unless set)", ProjectionTransitionsView.Stack(
                Note("A projection draws the event from the historical record: blocks of consecutive historical years, placed with no regard to the climate. " +
                     "The record shows only a weak tie between the event and dry periods, too weak to fit a response, so these two controls are for asking \"what if\": " +
                     "one moves the bad outbreaks into the dry periods of this climate run, the other makes the event larger in them. " +
                     "A dry period here is several years drier than the years around it in this climate run (its water deficit over 7 years against the 30 years around them)."),
                Note("They act only when this scenario also depends on a Projection Setup result (below its Build) whose Mortality page has Timing and Amount set to " +
                     "\"From the Projection Climate result\". The result made here then serves that setup."))));

            AddGroup(Group("When: outbreaks placed in dry periods", ProjectionTransitionsView.Stack(
                SliderLine("As drawn", m_timing, "Always in the driest", m_timingBox, "0 to 1"),
                m_timingSays,
                Wrapped("This changes when the event falls, not how much: each iteration keeps exactly the historical years it drew, so its total over the projection is the same at any setting.", 640))));

            AddGroup(Group("How much: the event raised in dry periods", ProjectionTransitionsView.Stack(
                SliderLine("No increase", m_amount, "200%", m_amountBox, "percent, 0 to 200"),
                m_amountSays,
                Wrapped("The percentage is the increase at a dry period as deep as the deepest of this climate run's historical years (1991 on). A shallower one gets a share of it, " +
                        "a deeper one more, up to twice. Years that are not dry are unchanged, and nothing is lowered. It is an assumption to explore, not a fitted response.", 640))));

            AddGroup(Group("Where to see the result", ProjectionTransitionsView.Stack(
                Note("The Projection Climate log has lines beginning \"Mortality and climate\": the share of dry years, the deepest dry periods, the rate of the driest third of years against the wettest, " +
                     "and the change in the mean rate. Projection Results > Mortality and Climate by Year lists each year's dryness, depth, multiplier and rate."))));
            EndGroups();

            m_timing.ValueChanged += (s, e) => { if (!Refreshing) Write("TimingStrength", Math.Round(m_timing.Value * TIMING_STEP, 2)); };
            m_amount.ValueChanged += (s, e) => { if (!Refreshing) Write("AmountPercent", m_amount.Value * AMOUNT_STEP); };
            BindRange(m_timingBox, "TimingStrength", 0, 1); BindRange(m_amountBox, "AmountPercent", 0, AMOUNT_MAX);
            this.ResumeLayout(false);
        }

        // a number box with the sheet's own limits: blank = DBNull (off), anything outside the limits or not a number is put back
        private void BindRange(TextBox t, string column, double lo, double hi)
        {
            t.Validated += (s, e) =>
            {
                if (Refreshing) return;
                string v = t.Text.Trim(); double d;
                if (v.Length == 0) Write(column, DBNull.Value);
                else if (double.TryParse(v, NumberStyles.Float, CultureInfo.CurrentCulture, out d) && d >= lo && d <= hi) Write(column, d);
                RefreshControls();
            };
        }

        private double Number(string column) { object v = Value(column); return v == DBNull.Value || v == null ? 0 : Convert.ToDouble(v); }
        private static string F(double v, string format) { return v.ToString(format, CultureInfo.CurrentCulture); }

        protected override void ShowData()
        {
            double s = Math.Min(1, Math.Max(0, Number("TimingStrength"))), a = Math.Min(AMOUNT_MAX, Math.Max(0, Number("AmountPercent")));
            m_timing.Value = (int)Math.Round(s / TIMING_STEP); m_amount.Value = (int)Math.Round(a / AMOUNT_STEP);
            if (!m_timingBox.Focused) m_timingBox.Text = Show(Value("TimingStrength"));
            if (!m_amountBox.Focused) m_amountBox.Text = Show(Value("AmountPercent"));
            m_timingSays.Text = TimingSays(s); m_amountSays.Text = AmountSays(a);
        }

        // the driest third of years against the wettest, from placing the record's blocks on LOCA2 runs in three pyromes: 1.3 to 1.6 times
        // at 0.3 (as the record), 1.8 to 2.6 at 0.6, 3.0 to 5.7 at 1
        private static string TimingSays(double s)
        {
            string at = "At " + F(s, "0.##") + ": ";
            if (s <= 0) return "Off. Outbreaks fall where the setup drew them, with no regard to the climate.";
            if (s < 0.25) return at + "a slight lean. Severe outbreaks are a little more likely in dry periods than elsewhere, less than the historical record shows.";
            if (s <= 0.35) return at + "about what the historical record shows. Severe outbreaks lean towards dry periods, and many still fall elsewhere: " +
                                        "the driest third of years has roughly 1.3 to 1.6 times the mortality of the wettest third.";
            if (s < 0.75) return at + "a stronger tie than the record shows. Most severe outbreaks fall in dry periods: " +
                                      "the driest third of years has roughly 2 to 2.5 times the mortality of the wettest third.";
            if (s < 1) return at + "a strong tie, well beyond the record. Severe outbreaks nearly always fall in the driest periods: " +
                                   "the driest third of years has roughly 3 to 4 times the mortality of the wettest third.";
            return at + "the worst outbreak always falls in the driest period, the next worst in the next driest, and so on: " +
                        "the driest third of years has roughly 3 to 6 times the mortality of the wettest third.";
        }

        // multiplier = 1 + percent x depth, depth held at 2; the total over a projection rose by 0.2 to 0.4 of the percentage in the trials
        // (timing 0.3, three pyromes: +6 to 10% at 25, +11 to 21% at 50, +22 to 40% at 100)
        private static string AmountSays(double a)
        {
            if (a <= 0) return "Off. Every year keeps the rate of the historical year drawn for it.";
            return "At " + F(a, "0.##") + "%: a year in a dry period as deep as the deepest of the historical years has " + F(1 + a / 100, "0.00") + " times the rate drawn for it; " +
                   "half as deep, " + F(1 + a / 200, "0.00") + " times; the most a year can have is " + F(1 + DEPTH_CAP * a / 100, "0.00") + " times. " +
                   "Over a whole projection that came to roughly " + F(Math.Round(0.2 * a), "0") + " to " + F(Math.Round(0.4 * a), "0") + "% more of the event in trials, depending on how dry the climate run is.";
        }
    }
}
