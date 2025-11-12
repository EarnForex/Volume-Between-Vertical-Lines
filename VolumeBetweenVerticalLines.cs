// -------------------------------------------------------------------------------
//   Calculates a sum of volume between two vertical lines and displays it on the chart.
//   
//   Version 1.01
//   Copyright 2019-2025, EarnForex.com
//   https://www.earnforex.com/indicators/Volume-Between-Vertical-Lines/
// -------------------------------------------------------------------------------

using System;
using cAlgo.API;

namespace cAlgo.Indicators
{
    [Indicator(IsOverlay = true, AccessRights = AccessRights.None)]
    public class VolumeBetweenVerticalLines : Indicator
    {
        public enum LabelPosition
        {
            RightTop,
            RightMiddle,
            RightBottom,
            LeftTop,
            LeftMiddle,
            LeftBottom
        }

        public enum LabelOrientation
        {
            Outside,
            Inside
        }

        [Parameter("Include Lines Bars", DefaultValue = true, Group = "Volume")]
        public bool IncludeLinesBars { get; set; }

        [Parameter("1st Vertical Line Name", DefaultValue = "VerticalLine1", Group = "Lines")]
        public string VerticalLine1Name { get; set; }

        [Parameter("2nd Vertical Line Name", DefaultValue = "VerticalLine2", Group = "Lines")]
        public string VerticalLine2Name { get; set; }

        [Parameter("1st Line Color", DefaultValue = "Red", Group = "Lines")]
        public Color VerticalLine1Color { get; set; }

        [Parameter("2nd Line Color", DefaultValue = "Red", Group = "Lines")]
        public Color VerticalLine2Color { get; set; }

        [Parameter("1st Line Style", DefaultValue = LineStyle.Solid, Group = "Lines")]
        public LineStyle VerticalLine1Style { get; set; }

        [Parameter("2nd Line Style", DefaultValue = LineStyle.Solid, Group = "Lines")]
        public LineStyle VerticalLine2Style { get; set; }

        [Parameter("1st Line Thickness", DefaultValue = 1, MinValue = 1, MaxValue = 5, Group = "Lines")]
        public int VerticalLine1Width { get; set; }

        [Parameter("2nd Line Thickness", DefaultValue = 1, MinValue = 1, MaxValue = 5, Group = "Lines")]
        public int VerticalLine2Width { get; set; }

        [Parameter("Volume Sum Label Name", DefaultValue = "VolumeSum", Group = "Label")]
        public string VolumeSumName { get; set; }

        [Parameter("Label Font Size", DefaultValue = 18, MinValue = 1, MaxValue = 100, Group = "Label")]
        public int VolumeSumFontSize { get; set; }

        [Parameter("Label Font", DefaultValue = "Courier New", Group = "Label")]
        public string VolumeSumFontFace { get; set; }

        [Parameter("Label Color", DefaultValue = "Red", Group = "Label")]
        public Color VolumeSumColor { get; set; }

        [Parameter("Label Position", DefaultValue = LabelPosition.LeftTop, Group = "Label")]
        public LabelPosition LabelPositionSetting { get; set; }

        [Parameter("Label Orientation", DefaultValue = LabelOrientation.Outside, Group = "Label")]
        public LabelOrientation LabelOrientationSetting { get; set; }

        private ChartVerticalLine VerticalLine1;
        private ChartVerticalLine VerticalLine2;

        protected override void Initialize()
        {
            VerticalLine1 = Chart.FindObject(VerticalLine1Name) as ChartVerticalLine;
            if (VerticalLine1 == null) // If the line doesn't exist yet.
            {
                // Create the first vertical line if it doesn't exist.
                VerticalLine1 = Chart.DrawVerticalLine(VerticalLine1Name, Bars.OpenTimes[Math.Max(0, Bars.Count - 6)], VerticalLine1Color, VerticalLine1Width, VerticalLine1Style);
                VerticalLine1.IsInteractive = true;
            }
            
            VerticalLine2 = Chart.FindObject(VerticalLine2Name) as ChartVerticalLine;
            if (VerticalLine2 == null) // If the line doesn't exist yet.
            {
                // Create the second vertical line if it doesn't exist.
                VerticalLine2 = Chart.DrawVerticalLine(VerticalLine2Name, Bars.OpenTimes[Bars.Count - 1], VerticalLine2Color, VerticalLine2Width, VerticalLine2Style);
                VerticalLine2.IsInteractive = true;
            }

            // Subscribe to chart events.
            Chart.ObjectsUpdated += OnChartObjectsUpdated;
            Chart.ZoomChanged += OnChartChanged;
            Chart.ScrollChanged += OnChartChanged;

            RefreshVolumeSum();
        }

        public override void Calculate(int index)
        {
            if (!IsLastBar) return;
            RefreshVolumeSum();
        }

        private void OnChartObjectsUpdated(ChartObjectsUpdatedEventArgs obj)
        {
            RefreshVolumeSum();
        }

        private void OnChartChanged(ChartScrollEventArgs obj)
        {
            RefreshVolumeSum();
        }

        private void OnChartChanged(ChartZoomEventArgs obj)
        {
            RefreshVolumeSum();
        }

        private void RefreshVolumeSum()
        {
            if (Bars.Count < 3)
                return;

            // Update line properties.
            UpdateLineProperties();

            // Get the times of both vertical lines.
            DateTime line1Time = VerticalLine1.Time;
            DateTime line2Time = VerticalLine2.Time;

            // Ensure lines are not in the future.
            DateTime currentBarTime = Bars.OpenTimes.LastValue;
            if (line1Time > currentBarTime)
            {
                line1Time = currentBarTime;
                VerticalLine1.Time = currentBarTime;
            }
            if (line2Time > currentBarTime)
            {
                line2Time = currentBarTime;
                VerticalLine2.Time = currentBarTime;
            }

            // Find bar indices for both lines.
            int line1Index = GetBarIndex(line1Time);
            int line2Index = GetBarIndex(line2Time);

            if (line1Index < 0 || line2Index < 0)
                return;

            // Determine start and end indices.
            int startIndex = Math.Min(line1Index, line2Index);
            int endIndex = Math.Max(line1Index, line2Index);

            if (!IncludeLinesBars)
            {
                startIndex++;
                endIndex--;
            }

            // Calculate volume sum.
            long volumeSum = CalculateVolumeSum(startIndex, endIndex);

            // Display the volume sum.
            DisplayVolumeSum(volumeSum, line1Index, line2Index);
        }

        private void UpdateLineProperties()
        {
            VerticalLine1.Color = VerticalLine1Color;
            VerticalLine1.LineStyle = VerticalLine1Style;
            VerticalLine1.Thickness = VerticalLine1Width;

            VerticalLine2.Color = VerticalLine2Color;
            VerticalLine2.LineStyle = VerticalLine2Style;
            VerticalLine2.Thickness = VerticalLine2Width;
        }

        private int GetBarIndex(DateTime time)
        {
            for (int i = Bars.Count - 1; i >= 0; i--)
            {
                if (Bars.OpenTimes[i] <= time)
                    return i;
            }
            return -1;
        }

        private long CalculateVolumeSum(int startIndex, int endIndex)
        {
            long sum = 0;

            if (startIndex > endIndex)
                return sum;

            for (int i = startIndex; i <= endIndex; i++)
            {
                sum += (long)Bars.TickVolumes[i];
            }

            return sum;
        }

        private void DisplayVolumeSum(long volumeSum, int line1Index, int line2Index)
        {
            string volumeText = volumeSum.ToString("N0");

            // Remove existing label if it exists.
            Chart.RemoveObject(VolumeSumName);

            // Determine which line to position the label next to.
            bool isLeft = LabelPositionSetting == LabelPosition.LeftTop || 
                          LabelPositionSetting == LabelPosition.LeftMiddle || 
                          LabelPositionSetting == LabelPosition.LeftBottom;
            
            int targetIndex;
            if (isLeft)
            {
                targetIndex = Math.Min(line1Index, line2Index); // Leftmost line
            }
            else
            {
                targetIndex = Math.Max(line1Index, line2Index); // Rightmost line
            }

            DrawLabelNearLine(volumeText, targetIndex, isLeft);
        }

        private void DrawLabelNearLine(string volumeText, int targetIndex, bool isLeft)
        {
            // Get price for vertical positioning.
            double targetPrice = GetLabelPrice();

            // Draw the text at the calculated position.
            var label = Chart.DrawText(VolumeSumName, volumeText, targetIndex, targetPrice, VolumeSumColor);
            label.FontSize = VolumeSumFontSize;
            label.FontFamily = VolumeSumFontFace;

            // Set text alignment.
            if (isLeft)
            {
                label.HorizontalAlignment = (LabelOrientationSetting == LabelOrientation.Outside) ? 
                    HorizontalAlignment.Left : HorizontalAlignment.Right;
            }
            else
            {
                label.HorizontalAlignment = (LabelOrientationSetting == LabelOrientation.Outside) ? 
                    HorizontalAlignment.Right : HorizontalAlignment.Left;
            }

            // Set vertical alignment based on position.
            switch (LabelPositionSetting)
            {
                case LabelPosition.LeftTop:
                case LabelPosition.RightTop:
                    label.VerticalAlignment = VerticalAlignment.Bottom;
                    break;
                case LabelPosition.LeftMiddle:
                case LabelPosition.RightMiddle:
                    label.VerticalAlignment = VerticalAlignment.Center;
                    break;
                case LabelPosition.LeftBottom:
                case LabelPosition.RightBottom:
                    label.VerticalAlignment = VerticalAlignment.Top;
                    break;
            }
        }

        private double GetLabelPrice()
        {
            double highest = Chart.TopY;
            double lowest = Chart.BottomY;
            double middle = (highest + lowest) / 2;

            // Set position based on settings.
            switch (LabelPositionSetting)
            {
                case LabelPosition.LeftTop:
                case LabelPosition.RightTop:
                    return highest;
                case LabelPosition.LeftMiddle:
                case LabelPosition.RightMiddle:
                    return middle;
                case LabelPosition.LeftBottom:
                case LabelPosition.RightBottom:
                    return lowest;
                default:
                    return middle;
            }
        }
    }
}