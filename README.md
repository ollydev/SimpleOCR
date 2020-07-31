## SimpleOCR

SimpleOCR is a Simba plugin for reading text in Old School RuneScape. 

Results: 

![Example](docs/uptext-1.png)
```
Recognized: Talk-to Grand Exchange Clerk / 262 more options
````

![Example](docs/uptext-2.png)
```
Recognized: Climb-up Ladder / 2 more option
```

-----

## Exports

```pascal 
procedure TFontSet.Load(Font: String; Space: Int32 = 4);
function TSimpleOCR.Recognize(constref AClient: T2DIntegerArray; Filter: TCompareRules; constref FontSet: TFontSet; IsStatic: Boolean = False; MaxWalk: Int32 = 40): String;
function TSimpleOCR.Recognize(B: TBox; Filter: TCompareRules; constref Font: TFontSet; IsStatic: Boolean = False; MaxWalk: Int32 = 40): AnsiString;
```

-----

`Filter` parameter:

```pascal
TCompareRules = packed record 
  Color, Tolerance: Int32;  // Color and tolerance. Color can be -1 to match any color.
  UseShadow: Boolean;       // If the fontset has a shadow, it can be used to improve recognition.
  ShadowMaxValue: Int32;    // Max brightness of shadow, Shadows are black so this is often low.
  Threshold: Boolean;       // Threshold the image? If so all above fields are ignored.
  ThresholdAmount: Int32;   // Threshold amount.
  ThresholdInvert: Boolean; // Threshold invert?
  MinCharacterMatch: Int32; // Minimum hits required to match a character. Useful to remove smaller characters (like dots) that are often misread.
end;
```

-----

`IsStatic` parameter:

If the starting position (X1,Y1) of the text never changes the text is static which greatly increases accuracy and speed. If this is the case you must pass the *pixel perfect* bounds of the text you want to read.

-----

`MaxWalk` parameter:

How far the OCR looks on the X axis before giving up. By default this is `40` so if no characaters are matched in 40 pixels the function finishes.