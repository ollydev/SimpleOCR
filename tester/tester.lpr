// Simple tests to make sure nothing is broken when changes are made.

program tester;

{$i simpleocr.inc}
{$assertions on}

uses
  Classes, SysUtils, Zipper, IntfGraphics, GraphType, Graphics,
  simpleocr.types, simpleocr.engine, simpleocr.filters;

function LoadMatrix(FileName: String): TIntegerMatrix;
var
  Description: TRawImageDescription;
  Image: TLazIntfImage;
  X, Y: Int32;
begin
  Description.Init_BPP32_B8G8R8_BIO_TTB(0, 0);

  Image := TLazIntfImage.Create(0, 0);
  Image.DataDescription := Description;
  Image.LoadFromFile(FileName);

  SetLength(Result, Image.Height, Image.Width);

  for X := 0 to Image.Width - 1 do
    for Y := 0 to Image.Height - 1 do
      Result[Y, X] := FPColorToTColor(Image.Colors[X, Y]);

  Image.Free();
end;

procedure SaveMatrix(Matrix: TIntegerMatrix; FileName: String);
var
  Description: TRawImageDescription;
  Image: TLazIntfImage;
  W, H, X, Y: Int32;
begin
  if (not MatrixDimensions(Matrix, W, H)) then
    Exit;

  Description.Init_BPP32_B8G8R8_BIO_TTB(W, H);

  Image := TLazIntfImage.Create(0, 0);
  Image.DataDescription := Description;

  for X := 0 to Image.Width - 1 do
    for Y := 0 to Image.Height - 1 do
      Image.Colors[X, Y] := TColorToFPColor(Matrix[Y, X]);

  Image.SaveToFile(FileName);
  Image.Free();
end;

var
  SimpleOCR: TSimpleOCR;

  FONT_QUILL_8: TFontSet;
  FONT_BOLD_12: TFontSet;
  FONT_BOLD_12_SHADOW: TFontSet;
  FONT_PLAIN_11: TFontSet;
  FONT_PLAIN_12: TFontSet;

procedure Test_MultiLine1;
const
  Filter: TOCRFilter = (
    FilterType: EOCRFilterType.COLOR;
    AnyColorFilter: ();
    ColorRule: (Colors: ((Color: 0; Tolerance: 0), (Color: 128; Tolerance: 0)); Invert: False);
    ThresholdRule: ();
    ShadowRule: ();
    MinCharacterMatch: #0;
  );
var
  Lines: TStringArray;
begin
  Lines := SimpleOCR.RecognizeLines(LoadMatrix('images/multiline1.png'), Filter, FONT_QUILL_8);

  Assert(Length(Lines) = 5);
  Assert(Lines[0] = 'Select an Option');
  Assert(Lines[1] = 'I''d like to access my bank account, please.');
  Assert(Lines[2] = 'I''d like to check my PIN settings.');
  Assert(Lines[3] = 'I''d like to collect items.');
  Assert(Lines[4] = 'What is this place?');
end;

procedure Test_MultiLine2;
const
  Filter: TOCRFilter = (
    FilterType: EOCRFilterType.COLOR;
    AnyColorFilter: ();
    ColorRule: (Colors: ((Color: 0; Tolerance: 5)); Invert: False);
    ThresholdRule: ();
    ShadowRule: ();
    MinCharacterMatch: #0;
  );
var
  Lines: TStringArray;
begin
  Lines := SimpleOCR.RecognizeLines(LoadMatrix('images/multiline2.png'), Filter, FONT_PLAIN_12);

  Assert(Length(Lines) = 2);
  Assert(Lines[0] = 'Blighted super');
  Assert(Lines[1] = 'restore(4)');
end;

procedure Test_MultiLine3;
const
  Filter1: TOCRFilter = (
    FilterType: EOCRFilterType.COLOR;
    AnyColorFilter: ();
    ColorRule: (Colors: ((Color: $009933; Tolerance: 0)); Invert: False);
    ThresholdRule: ();
    ShadowRule: ();
    MinCharacterMatch: #0;
  );
  Filter2: TOCRFilter = (
    FilterType: EOCRFilterType.COLOR;
    AnyColorFilter: ();
    ColorRule: (Colors: ((Color: $00CC33; Tolerance: 0)); Invert: False);
    ThresholdRule: ();
    ShadowRule: ();
    MinCharacterMatch: #0;
  );
var
  Lines: TStringArray;
  I: Integer;
begin
  Lines := SimpleOCR.RecognizeLines(LoadMatrix('images/multiline3.png'), Filter1, FONT_PLAIN_11);
  for I := 0 to High(Lines) do
    Lines[I] := StringReplace(Lines[I], 'I', 'l', [rfReplaceAll]);

  Assert(Length(Lines) = 5);
  Assert(Lines[0] = 'Leather Boots:');
  Assert(Lines[1] = 'Adamant Kiteshield:');
  Assert(Lines[2] = 'Adamant Helm:');
  Assert(Lines[3] = 'Emerald:');
  Assert(Lines[4] = 'Rune Longsword:');

  Lines := SimpleOCR.RecognizeLines(LoadMatrix('images/multiline3.png'), Filter2, FONT_PLAIN_11);

  Assert(Length(Lines) = 6);
  Assert(Lines[0] = '0');
  Assert(Lines[1] = '5');
  Assert(Lines[2] = '1');
  Assert(Lines[3] = '30');
  Assert(Lines[4] = '15');
  Assert(Lines[5] = '8');
end;

procedure Test_MultiLine4;
const
  Filter: TOCRFilter = (
    FilterType: EOCRFilterType.COLOR;
    AnyColorFilter: ();
    ColorRule: (Colors: ((Color: $000000; Tolerance: 0)); Invert: False);
    ThresholdRule: ();
    ShadowRule: ();
    MinCharacterMatch: #0;
  );
var
  Lines: TStringArray;
begin
  Lines := SimpleOCR.RecognizeLines(LoadMatrix('images/multiline4.png'), Filter, FONT_PLAIN_12);

  Assert(Length(Lines) = 3);
  Assert(Lines[0] = 'Fishing XP: 20');
  Assert(Lines[1] = 'Next level at: 83');
  Assert(Lines[2] = 'Remaining XP: 63');
end;

procedure Test_MultiLine5;
const
  Filter: TOCRFilter = (
    FilterType: EOCRFilterType.COLOR;
    AnyColorFilter: ();
    ColorRule: (Colors: ((Color: 3099981; Tolerance: 0)); Invert: False);
    ThresholdRule: ();
    ShadowRule: ();
    MinCharacterMatch: #0;
  );
var
  Lines: TStringArray;
begin
  Lines := SimpleOCR.RecognizeLines(LoadMatrix('images/multiline5.png'), Filter, FONT_PLAIN_12);

  Assert(Length(Lines) = 7);
  Assert(Lines[0] = 'Ahrim');
  Assert(Lines[1] = 'Dharok');
  Assert(Lines[2] = 'Guthan');
  Assert(Lines[3] = 'Karil');
  Assert(Lines[4] = 'Torag');
  Assert(Lines[5] = 'Verac');
  Assert(Lines[6] = 'Rewards potential: 0%');
end;

procedure Test_UpText1;
const
  Filter: TOCRFilter = (
    FilterType: EOCRFilterType.ANY_COLOR;
    AnyColorFilter: (MaxShadowValue: 60; Tolerance: 85);
    ColorRule: ();
    ThresholdRule: ();
    ShadowRule: ();
    MinCharacterMatch: #0;
  );
begin
  Assert(SimpleOCR.RecognizeStatic(LoadMatrix('images/uptext1.png'), Filter, FONT_BOLD_12_SHADOW) = 'Take Green d''hide vambraces / 2 more options');
end;

procedure Test_UpText2;
const
  Filter: TOCRFilter = (
    FilterType: EOCRFilterType.ANY_COLOR;
    AnyColorFilter: (MaxShadowValue: 60; Tolerance: 85);
    ColorRule: ();
    ThresholdRule: ();
    ShadowRule: ();
    MinCharacterMatch: #0;
  );
begin
  Assert(SimpleOCR.RecognizeStatic(LoadMatrix('images/uptext2.png'), Filter, FONT_BOLD_12_SHADOW) = 'Bank Bank booth / 3 more options');
end;

procedure Test_Shadow;
const
  Filter: TOCRFilter = (
    FilterType: EOCRFilterType.SHADOW;
    AnyColorFilter: ();
    ColorRule: ();
    ThresholdRule: ();
    ShadowRule: (MaxShadowValue: 5; Tolerance: 5);
    MinCharacterMatch: #0;
  );
begin
  Assert(SimpleOCR.Recognize(LoadMatrix('images/shadow.png'), Filter, FONT_PLAIN_11) = '53');
end;

procedure Test_Static;
const
  Filter: TOCRFilter = (
    FilterType: EOCRFilterType.COLOR;
    AnyColorFilter: ();
    ColorRule: (Colors: ((Color: 0; Tolerance: 0)); Invert: False);
    ThresholdRule: ();
    ShadowRule: ();
    MinCharacterMatch: #0;
  );
begin
  Assert(SimpleOCR.RecognizeStatic(LoadMatrix('images/static.png'), Filter, FONT_PLAIN_12) = 'You have correctly entered your PIN.');
end;

procedure Test_Threshold1;
const
  Filter: TOCRFilter = (
    FilterType: EOCRFilterType.THRESHOLD;
    AnyColorFilter: ();
    ColorRule: ();
    ThresholdRule: (Amount: 10; Invert: False);
    ShadowRule: ();
    MinCharacterMatch: #0;
  );
begin
  Assert(SimpleOCR.Recognize(LoadMatrix('images/thresh.png'), Filter, FONT_BOLD_12) = 'Showing items: hello');
end;

procedure Test_Threshold2;
const
  Filter: TOCRFilter = (
    FilterType: EOCRFilterType.THRESHOLD;
    AnyColorFilter: ();
    ColorRule: ();
    ThresholdRule: (Amount: 50; Invert: False);
    ShadowRule: ();
    MinCharacterMatch: #0;
  );
begin
  Assert(SimpleOCR.Recognize(LoadMatrix('images/thresh.png'), Filter, FONT_BOLD_12) = 'Showing items:');
end;

procedure Test_Locate1;
const
  Filter: TOCRFilter = (
    FilterType: EOCRFilterType.THRESHOLD;
    AnyColorFilter: ();
    ColorRule: ();
    ThresholdRule: (Amount: 10; Invert: False);
    ShadowRule: ();
    MinCharacterMatch: #0;
  );
var
  B: TBox;
  Match: Single;
begin
  Match := SimpleOCR.LocateText(LoadMatrix('images/locate1.png'), 'items:', FONT_BOLD_12, Filter, B);

  Assert(Abs(Match - 0.98) < 0.005); // 0.98 because some rogue pixels exist in the `:` character!
  Assert(B.X1 = 69);
  Assert(B.Y1 = 6);
  Assert(B.X2 = 109);
  Assert(B.Y2 = 15);
end;

procedure Test_Locate2;
var
  Filter: TOCRFilter;
  B: TBox;
begin
  Filter := Default(TOCRFilter);
  Filter.FilterType := EOCRFilterType.ANY_COLOR;
  Filter.AnyColorFilter.Tolerance := 40;

  Assert(SimpleOCR.LocateText(LoadMatrix('images/locate2.png'), 'Showing items:', FONT_BOLD_12, Filter, B) = 0);

  Filter.AnyColorFilter.Tolerance := 50;

  Assert(SimpleOCR.LocateText(LoadMatrix('images/locate2.png'), 'Showing items:', FONT_BOLD_12, Filter, B) = 1);
end;

var
  Fail, Pass: Integer;
  StartTime: UInt64;

procedure Test(Proc: TProcedure; Name: String);
begin
  try
    WriteLn('Testing: ' + Name);
    Proc();
    WriteLn('Passed');

    Inc(Pass);
  except
    on E: Exception do
    begin
      if E is EAssertionFailed then
        WriteLn('Failed')
      else
        WriteLn('Failed: ', E.Message);

      Inc(Fail);
    end;
  end;
end;

begin
  if not DirectoryExists('fonts') then
    TUnZipper.Unzip('fonts.zip');

  SimpleOCR := Default(TSimpleOCR);

  FONT_QUILL_8.Load('fonts/Quill 8');
  FONT_BOLD_12.Load('fonts/Bold 12');
  FONT_BOLD_12_SHADOW.Load('fonts/Bold 12 Shadow');
  FONT_PLAIN_11.Load('fonts/Plain 11');
  FONT_PLAIN_12.Load('fonts/Plain 12');

  Fail := 0;
  Pass := 0;
  StartTime := GetTickCount64();

  Test(@Test_Threshold1, 'Threshold1');
  Test(@Test_Threshold2, 'Threshold2');
  Test(@Test_MultiLine1, 'MultiLine1');
  Test(@Test_MultiLine2, 'MultiLine2');
  Test(@Test_MultiLine3, 'MultiLine3');
  Test(@Test_MultiLine4, 'MultiLine4');
  Test(@Test_MultiLine5, 'MultiLine5');
  Test(@Test_UpText1, 'UpText1');
  Test(@Test_UpText2, 'UpText2');
  Test(@Test_Shadow, 'Shadow');
  Test(@Test_Static, 'Static');
  Test(@Test_Locate1, 'Locate1');
  Test(@Test_Locate2, 'Locate2');

  WriteLn();
  WriteLn(Format('Ran %d tests in %d ms', [Pass + Fail, (GetTickCount64() - StartTime)]));
  WriteLn(Format('%3d / %d tests failed', [Fail, Pass + Fail]));
  WriteLn(Format('%3d / %d tests passed', [Pass, Pass + Fail]));
  WriteLn();

  if (Fail > 0) then
    ExitCode := 1;

  //ReadLn;
end.

