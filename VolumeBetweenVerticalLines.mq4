//+------------------------------------------------------------------+
//|                                   VolumeBetweenVerticalLines.mq4 |
//|                             Copyright © 2019-2025, EarnForex.com |
//|                                       https://www.earnforex.com/ |
//+------------------------------------------------------------------+
#property copyright "Copyright 2019-2025, EarnForex.com"
#property link      "https://www.earnforex.com/indicators/Volume-Between-Vertical-Lines/"
#property version   "1.01"
#property strict

#property description "Calculates a sum of volume between two vertical lines and displays it on the chart."

#property indicator_chart_window

enum ENUM_LABEL_POSITION
{
    LABEL_POSITION_RIGHT_TOP, // Right top
    LABEL_POSITION_RIGHT_MID, // Right middle
    LABEL_POSITION_RIGHT_BOT, // Right bottom
    LABEL_POSITION_LEFT_TOP,  // Left top
    LABEL_POSITION_LEFT_MID,  // Left middle
    LABEL_POSITION_LEFT_BOT   // Left bottom
};

enum ENUM_LABEL_ORIENTATION
{
    LABEL_ORIENTATION_OUTSIDE, // Outside
    LABEL_ORIENTATION_INSIDE   // Inside
};

input bool IncludeLinesBars = true; // Include volume on bars where lines stand?
input string VerticleLine1 = "VerticalLine1"; // 1st Vertical Line
input string VerticleLine2 = "VerticalLine2"; // 2nd Vertical Line
input color VerticleLine1Color = clrRed; // 1st Vertical Line Color
input color VerticleLine2Color = clrRed; // 2nd Vertical Line Color
input ENUM_LINE_STYLE VerticleLine1Style = STYLE_SOLID; // 1st Vertical Line Style
input ENUM_LINE_STYLE VerticleLine2Style = STYLE_SOLID; // 2nd Vertical Line Style
input int VerticleLine1Width = 1; // 1st Vertical Line Width
input int VerticleLine2Width = 1; // 2nd Vertical Line Width
input string VolumeSum = "VolumeSum"; // Volume sum
input int VolumeSumFontSize = 8; // Volume sum font size
input string VolumeSumFontFace = "Courier"; // Volume sum font size
input color VolumeSumColor = clrRed; // Volume sum color
input ENUM_LABEL_POSITION LabelPosition = LABEL_POSITION_LEFT_TOP; // Label position
input ENUM_LABEL_ORIENTATION LabelOrientation = LABEL_ORIENTATION_OUTSIDE; // Label orientation

void OnDeinit(const int reason)
{
    if (reason != REASON_CHARTCHANGE && reason != REASON_PARAMETERS)
    {
        ObjectDelete(0, VerticleLine1);
        ObjectDelete(0, VerticleLine2);
        ObjectDelete(0, VolumeSum);
    }
}

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
    RefreshVolumeSum();
    return rates_total;
}

void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
    // Recalculate on chart changes, clicks, and certain object dragging.
    if ((id == CHARTEVENT_CLICK) || (id == CHARTEVENT_CHART_CHANGE) ||
       ((id == CHARTEVENT_OBJECT_DRAG) && ((sparam == VerticleLine1) || (sparam == VerticleLine2))))
    {
        // Moving lines should trigger volume sum recalculation and label update.
        if ((id == CHARTEVENT_OBJECT_DRAG) && (sparam == VerticleLine1)) RefreshVolumeSum();
        if ((id == CHARTEVENT_OBJECT_DRAG) && (sparam == VerticleLine2)) RefreshVolumeSum();
        if ((id == CHARTEVENT_CLICK) || (id == CHARTEVENT_CHART_CHANGE)) RefreshVolumeSum();
    }
}

void RefreshVolumeSum()
{
    if (Bars < 3) return; // Chart data not loaded yet.

    if (ObjectFind(0, VerticleLine1) < 0) // 1st vertical line is missing.
    {
        ObjectCreate(0, VerticleLine1, OBJ_VLINE, 0, Time[5], 0);
        ObjectSetInteger(0, VerticleLine1, OBJPROP_SELECTABLE, true);
        ObjectSetInteger(0, VerticleLine1, OBJPROP_SELECTED, true);
        ObjectSetInteger(0, VerticleLine1, OBJPROP_HIDDEN, false);
    }
    ObjectSetInteger(0, VerticleLine1, OBJPROP_COLOR, VerticleLine1Color);
    ObjectSetInteger(0, VerticleLine1, OBJPROP_STYLE, VerticleLine1Style);
    ObjectSetInteger(0, VerticleLine1, OBJPROP_WIDTH, VerticleLine1Width);

    if (ObjectFind(0, VerticleLine2) < 0) // 2nd vertical line is missing.
    {
        ObjectCreate(0, VerticleLine2, OBJ_VLINE, 0, Time[0], 0);
        ObjectSetInteger(0, VerticleLine2, OBJPROP_SELECTABLE, true);
        ObjectSetInteger(0, VerticleLine2, OBJPROP_SELECTED, true);
        ObjectSetInteger(0, VerticleLine2, OBJPROP_HIDDEN, false);
    }
    ObjectSetInteger(0, VerticleLine2, OBJPROP_COLOR, VerticleLine2Color);
    ObjectSetInteger(0, VerticleLine2, OBJPROP_STYLE, VerticleLine2Style);
    ObjectSetInteger(0, VerticleLine2, OBJPROP_WIDTH, VerticleLine2Width);

    datetime vl1_time = (datetime)ObjectGetInteger(0, VerticleLine1, OBJPROP_TIME, 0);
    datetime vl2_time = (datetime)ObjectGetInteger(0, VerticleLine2, OBJPROP_TIME, 0);

    // Check if a vertical line is set in future - move it back.
    if (vl1_time > Time[0]) ObjectSetInteger(0, VerticleLine1, OBJPROP_TIME, 0, Time[0]);
    if (vl2_time > Time[0]) ObjectSetInteger(0, VerticleLine2, OBJPROP_TIME, 0, Time[0]);

    // Find bar shift for lines' times.
    int vl1_shift = -1;
    int vl2_shift = -1;
    // Find lines.
    for (int i = 0; i < Bars; i++)
    {
        if ((Time[i] <= vl1_time) && (vl1_shift == -1)) // 1st vertical line found.
        {
            vl1_shift = i;
        }
        if ((Time[i] <= vl2_time) && (vl2_shift == -1)) // 2nd vertical line found.
        {
            vl2_shift = i;
        }
        if ((vl1_shift >= 0) && (vl2_shift >= 0)) break;
    }

    if ((vl1_shift == -1) || (vl2_shift == -1)) return; // Failed to find lines for some reason.

    // Find the beginning and the end irrespective of which line is first and which one is last.
    int begin, end;
    if (vl1_shift > vl2_shift)
    {
        begin = vl1_shift;
        end = vl2_shift;
    }
    else if (vl1_shift < vl2_shift)
    {
        begin = vl2_shift;
        end = vl1_shift;
    }
    else
    {
        begin = vl1_shift;
        end = vl2_shift;
    }
    if (!IncludeLinesBars)
    {
        begin--;
        end++;
    }

    // Calculate the volume sum.
    long sum = 0;
    for (int i = begin; i >= end; i--)
    {
        sum += Volume[i];
    }
    string vol_sum = IntegerToString(sum);

    // Create, configure and set the volume sum object.
    int x, y;
    uint w, h;
    
    int shift; // Based on left or right position of the label.
    int width_multiplier; // Based on both position and orientation.
    int margin_multiplier; // Based on both position and orientation.
    if (LabelPosition == LABEL_POSITION_LEFT_TOP || LabelPosition == LABEL_POSITION_LEFT_MID || LabelPosition == LABEL_POSITION_LEFT_BOT)
    {
        shift = MathMax(vl1_shift, vl2_shift); // Left
        if (LabelOrientation == LABEL_ORIENTATION_OUTSIDE)
        {
            width_multiplier = -1;
            margin_multiplier = -1;
        }
        else
        {
            width_multiplier = 0;
            margin_multiplier = 1;
        }
    }
    else 
    {
        shift = MathMin(vl1_shift, vl2_shift); // Right
        if (LabelOrientation == LABEL_ORIENTATION_OUTSIDE)
        {
            width_multiplier = 0;
            margin_multiplier = 1;
        }
        else
        {
            width_multiplier = -1;
            margin_multiplier = -1;
        }
    }

    // Needed only for x, y is derived from the chart height. Price doesn't matter.
    ChartTimePriceToXY(0, 0, Time[shift], 0, x, y);
    // Get the width of the text bas1ed on font and its size. Negative because OS-dependent, *10 because set in 1/10 of pt.
    TextSetFont(VolumeSumFontFace, VolumeSumFontSize * -10);
    TextGetSize(vol_sum, w, h);

    if (ObjectFind(0, VolumeSum) < 0) // Volume sum object not found.
    {
        ObjectCreate(0, VolumeSum, OBJ_LABEL, 0, /*Time[MathMax(vl1_shift, vl2_shift)]*/0, /*High[0]*/0); // Both time and price are dummy because labels use X/Y coordinates.
        ObjectSetInteger(0, VolumeSum, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, VolumeSum, OBJPROP_SELECTED, false);
        ObjectSetInteger(0, VolumeSum, OBJPROP_HIDDEN, false);
    }
    ObjectSetInteger(0, VolumeSum, OBJPROP_FONTSIZE, VolumeSumFontSize);
    ObjectSetString(0, VolumeSum, OBJPROP_FONT, VolumeSumFontFace);
    ObjectSetInteger(0, VolumeSum, OBJPROP_COLOR, VolumeSumColor);
    ObjectSetInteger(0, VolumeSum, OBJPROP_XDISTANCE, x + width_multiplier * w + margin_multiplier * 4); // 4 is a margin.

    int window_height = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
    int y_distance;
    if (LabelPosition == LABEL_POSITION_LEFT_TOP || LabelPosition == LABEL_POSITION_RIGHT_TOP) // Top
    {
        y_distance = (int)h - 12; // -12 moves the label closer to the screen's top.
    }
    else if (LabelPosition == LABEL_POSITION_LEFT_MID || LabelPosition == LABEL_POSITION_RIGHT_MID) // Middle
    {
        y_distance = (window_height + (int)h) / 2 - 6; // -6 moves the label closer to the screen's top.
    }
    else // Bottom
    {
        y_distance = window_height - (int)h - 4; // -4 moves the label closer to the screen's top.
    }
    ObjectSetInteger(0, VolumeSum, OBJPROP_YDISTANCE, y_distance);

    ObjectSetString(0, VolumeSum, OBJPROP_TEXT, vol_sum);
}
//+------------------------------------------------------------------+