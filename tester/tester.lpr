// Simple tests to make sure nothing is broken when changes are made.

program tester;

{$i simpleocr.inc}
{$assertions on}

uses
  Classes, SysUtils, IntfGraphics, GraphType, Graphics,
  simpleocr.base, simpleocr.engine, simpleocr.filters;

function LoadMatrix(FileName: String): TColorRGBAMatrix;
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
      Result[Y, X] := TColorRGBA(FPColorToTColor(Image.Colors[X, Y]));

  Image.Free();
end;

procedure SaveMatrix(Matrix: TColorRGBAMatrix; FileName: String);
var
  Description: TRawImageDescription;
  Image: TLazIntfImage;
   X, Y: Int32;
begin
  Description.Init_BPP32_B8G8R8_BIO_TTB(Length(Matrix[0]), Length(Matrix));

  Image := TLazIntfImage.Create(0, 0);
  Image.DataDescription := Description;

  for X := 0 to Image.Width - 1 do
    for Y := 0 to Image.Height - 1 do
      Image.Colors[X, Y] := TColorToFPColor(TColor(Matrix[Y, X]));

  Image.SaveToFile(FileName);
  Image.Free();
end;

var
  OCR: TSimpleOCR;

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
    ColorRule: (Colors: (0,128); Tolerances: (0, 0); Invert: False);
    ThresholdRule: ();
    ShadowRule: ();
    Blacklist: '';
  );
var
  Lines: TStringArray;
begin
  Lines := OCR.RecognizeLines(LoadMatrix('images/multiline1.png'), Filter, FONT_QUILL_8);

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
    ColorRule: (Colors: (0); Tolerances: (5); Invert: False);
    ThresholdRule: ();
    ShadowRule: ();
    Blacklist: '';
  );
var
  Lines: TStringArray;
begin
  Lines := OCR.RecognizeLines(LoadMatrix('images/multiline2.png'), Filter, FONT_PLAIN_12);

  Assert(Length(Lines) = 2);
  Assert(Lines[0] = 'Blighted super');
  Assert(Lines[1] = 'restore(4)');
end;

procedure Test_MultiLine3;
const
  Filter1: TOCRFilter = (
    FilterType: EOCRFilterType.COLOR;
    AnyColorFilter: ();
    ColorRule: (Colors: ($009933); Tolerances: (0); Invert: False);
    ThresholdRule: ();
    ShadowRule: ();
    Blacklist: '';
  );
  Filter2: TOCRFilter = (
    FilterType: EOCRFilterType.COLOR;
    AnyColorFilter: ();
    ColorRule: (Colors: ($00CC33); Tolerances: (0); Invert: False);
    ThresholdRule: ();
    ShadowRule: ();
    Blacklist: '';
  );
var
  Lines: TStringArray;
  I: Integer;
begin
  Lines := OCR.RecognizeLines(LoadMatrix('images/multiline3.png'), Filter1, FONT_PLAIN_11);
  for I := 0 to High(Lines) do
    Lines[I] := StringReplace(Lines[I], 'I', 'l', [rfReplaceAll]);

  Assert(Length(Lines) = 5);
  Assert(Lines[0] = 'Leather Boots:');
  Assert(Lines[1] = 'Adamant Kiteshield:');
  Assert(Lines[2] = 'Adamant Helm:');
  Assert(Lines[3] = 'Emerald:');
  Assert(Lines[4] = 'Rune Longsword:');

  Lines := OCR.RecognizeLines(LoadMatrix('images/multiline3.png'), Filter2, FONT_PLAIN_11);

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
    ColorRule: (Colors: ($000000); Tolerances: (0); Invert: False);
    ThresholdRule: ();
    ShadowRule: ();
    Blacklist: '';
  );
var
  Lines: TStringArray;
begin
  Lines := OCR.RecognizeLines(LoadMatrix('images/multiline4.png'), Filter, FONT_PLAIN_12);

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
    ColorRule: (Colors: (3099981); Tolerances: (0); Invert: False);
    ThresholdRule: ();
    ShadowRule: ();
    Blacklist: '';
  );
var
  Lines: TStringArray;
begin
  Lines := OCR.RecognizeLines(LoadMatrix('images/multiline5.png'), Filter, FONT_PLAIN_12);

  Assert(Length(Lines) = 7);
  Assert(Lines[0] = 'Ahrim');
  Assert(Lines[1] = 'Dharok');
  Assert(Lines[2] = 'Guthan');
  Assert(Lines[3] = 'Karil');
  Assert(Lines[4] = 'Torag');
  Assert(Lines[5] = 'Verac');
  Assert(Lines[6] = 'Rewards potential: 0%');
end;



procedure Test_MultiLine6;
const
  Filter: TOCRFilter = (
    FilterType: EOCRFilterType.COLOR;
    AnyColorFilter: ();
    ColorRule: (Colors: (0); Tolerances: (0); Invert: False);
    ThresholdRule: ();
    ShadowRule: ();
    Blacklist: '';
  );
var
  Lines: TStringArray;
begin
  Lines := OCR.RecognizeLines(LoadMatrix('images/multiline6.png'), Filter, FONT_QUILL_8);

  Assert(Length(Lines) = 4);
  Assert(Lines[0] = 'Al Kharid PvP Arena.');
  Assert(Lines[1] = 'Castle Wars Arena.');
  Assert(Lines[2] = 'Ferox Enclave.');
  Assert(Lines[3] = 'Nowhere.');
end;

procedure Test_UpText;
const
  Filter: TOCRFilter = (
    FilterType: EOCRFilterType.ANY_COLOR;
    AnyColorFilter: (MaxShadowValue: 60; Tolerance: 20);
    ColorRule: ();
    ThresholdRule: ();
    ShadowRule: ();
    Blacklist: ',."'+#39;
  );

var
  Mat: TColorRGBAMatrix;

  function Recognize(Y: Integer): String;
  begin
    Result := OCR.RecognizeStatic(Copy(Mat, Y), Filter, FONT_BOLD_12_SHADOW);
  end;

begin
  Mat := LoadMatrix('images/uptext.png');

  Assert(Recognize(0)   = 'Chop down Yew tree / 2 more options');
  Assert(Recognize(20)  = 'Talk-to Grand Exchange Clerk / 98 more options');
  Assert(Recognize(39)  = 'Bank Bank booth / 3 more options');
  Assert(Recognize(58)  = 'Remove Chaotic handegg / 1 more options');
  Assert(Recognize(76)  = 'Use Body rune -> King Roald / 1 more options');
  Assert(Recognize(95)  = 'Pray-at Altar / 2 more options');
  Assert(Recognize(114) = 'Attack Grizzly bear (level-21) / 2 more options');
  Assert(Recognize(133) = 'Use Gold bar -> BAYRAKTAR22 (level-109) / 2 more options');
  Assert(Recognize(151) = 'Lookup-entity Wiki -> Grand Exchange booth');
  Assert(Recognize(170) = 'Talk-to rand Exchange Clerk / 1'); // incorrect
  Assert(Recognize(190) = 'Use Super strength(3) (Members) -> 23 Steal 1');
  Assert(Recognize(209) = 'Take Green d hide vambraces / 2 more options');
  Assert(Recognize(228) = 'Use Super strength(3) (Members) -> Hanging banner / 2 more'); // incorrect
  Assert(Recognize(246) = 'Use Body rune -> Fireplace');
  Assert(Recognize(264) = 'Talk-to Cook / 2 more options');
  Assert(Recognize(283) = 'Use Body rune -> Spider (level-1)');
  Assert(Recognize(302) = 'Use Gold bar -> Barrel / 1 more options');
  Assert(Recognize(320) = 'Use Body rune -> Cooking Pots / 1 more options');
  Assert(Recognize(338) = 'Take Mind rune / 2 more options');
  Assert(Recognize(354) = 'Use Gold bar -> Bank Deposit Box');
  Assert(Recognize(372) = 'Withdraw-1 Gold bracelet (Members) / 8 more options');
  Assert(Recognize(390) = 'Talk-to Banker tutor / 8 more options');
  Assert(Recognize(409) = 'Use Gold bar -> Super strength(3) (Members)');
  Assert(Recognize(428) = 'Withdraw-1 Clue geode (hard) (Members) / 8 more options');
  Assert(Recognize(448) = 'Talk-to Spirit tree / 3 more options');
end;

procedure Test_Shadow;
const
  Filter: TOCRFilter = (
    FilterType: EOCRFilterType.SHADOW;
    AnyColorFilter: ();
    ColorRule: ();
    ThresholdRule: ();
    ShadowRule: (MaxShadowValue: 5; Tolerance: 1);
    Blacklist: '';
  );
begin
  Assert(OCR.Recognize(LoadMatrix('images/shadow.png'), Filter, FONT_PLAIN_11) = '53');
end;

procedure Test_Static;
const
  Filter: TOCRFilter = (
    FilterType: EOCRFilterType.COLOR;
    AnyColorFilter: ();
    ColorRule: (Colors: (0); Tolerances: (0); Invert: False);
    ThresholdRule: ();
    ShadowRule: ();
    Blacklist: '';
  );
begin
  Assert(OCR.RecognizeStatic(LoadMatrix('images/static.png'), Filter, FONT_PLAIN_12) = 'You have correctly entered your PIN.');
end;

procedure Test_Threshold1;
const
  Filter: TOCRFilter = (
    FilterType: EOCRFilterType.THRESHOLD;
    AnyColorFilter: ();
    ColorRule: ();
    ThresholdRule: (Invert: False; C: 10);
    ShadowRule: ();
    Blacklist: '';
  );
begin
  Assert(OCR.Recognize(LoadMatrix('images/thresh.png'), Filter, FONT_BOLD_12) = 'Showing items: hello');
end;

procedure Test_Threshold2;
const
  Filter: TOCRFilter = (
    FilterType: EOCRFilterType.THRESHOLD;
    AnyColorFilter: ();
    ColorRule: ();
    ThresholdRule: (Invert: False; C: 0);
    ShadowRule: ();
    Blacklist: '';
  );
begin
  Assert(OCR.Recognize(LoadMatrix('images/thresh.png'), Filter, FONT_BOLD_12) = 'Showing items:');
end;

procedure Test_ThresholdInvert;
const
  Filter: TOCRFilter = (
    FilterType: EOCRFilterType.THRESHOLD;
    AnyColorFilter: ();
    ColorRule: ();
    ThresholdRule: (Invert: True; C: 0);
    ShadowRule: ();
    Blacklist: '';
  );
var
  Lines: TStringArray;
begin
  Lines := OCR.RecognizeLines(LoadMatrix('images/thresh_inv.png'), Filter, FONT_QUILL_8);

  Assert(Length(Lines) = 2);
  Assert(Lines[0] = 'Where would you like to teleport to?');
  Assert(Lines[1] = 'Al Kharid PvP Arena.');
end;

procedure Test_Locate1;
const
  Filter: TOCRFilter = (
    FilterType: EOCRFilterType.THRESHOLD;
    AnyColorFilter: ();
    ColorRule: ();
    ThresholdRule: (Invert: False; C: 10);
    ShadowRule: ();
    Blacklist: '';
  );
var
  Match: Single;
begin
  Match := OCR.Locate(LoadMatrix('images/locate1.png'), 'items:', FONT_BOLD_12, Filter);

  Assert(Abs(Match - 0.98) < 0.005); // 0.98 because some rogue pixels exist in the `:` character!
  Assert(Length(OCR.Matches) = 1);
  Assert(OCR.Matches[0].Bounds.X1 = 69);
  Assert(OCR.Matches[0].Bounds.Y1 = 6);
  Assert(OCR.Matches[0].Bounds.X2 = 109);
  Assert(OCR.Matches[0].Bounds.Y2 = 15);
end;

procedure Test_Locate2;
var
  Filter: TOCRFilter;
begin
  Filter := Default(TOCRFilter);
  Filter.FilterType := EOCRFilterType.ANY_COLOR;

  // no matches, not enough tolerance
  Filter.AnyColorFilter.Tolerance := 5;
  Assert(OCR.Locate(LoadMatrix('images/locate2.png'), 'Showing items:', FONT_BOLD_12, Filter) = 0);

  // should find now
  Filter.AnyColorFilter.Tolerance := 10;
  Assert(OCR.Locate(LoadMatrix('images/locate2.png'), 'Showing items:', FONT_BOLD_12, Filter) = 1);
end;

procedure Test_Invert;
const
  Filter: TOCRFilter = (
    FilterType: EOCRFilterType.COLOR;
    AnyColorFilter: ();
    ColorRule: (Colors: (0, $47545D); Tolerances: (0, 0); Invert: True);
    ThresholdRule: ();
    ShadowRule: ();
    Blacklist: '';
  );
begin
  Assert(OCR.Recognize(LoadMatrix('images/invert.png'), Filter, FONT_BOLD_12) = 'Remove Amulet of glory(1) (Members)');
  Assert(OCR.RecognizeStatic(LoadMatrix('images/invert.png'), Filter, FONT_BOLD_12) = 'Remove Amulet of glory(1) (Members)');
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
  OCR := Default(TSimpleOCR);

  FONT_QUILL_8        := TFontSet.Create('../fonts/Quill 8');
  FONT_BOLD_12        := TFontSet.Create('../fonts/Bold 12');
  FONT_BOLD_12_SHADOW := TFontSet.Create('../fonts/Bold 12 Shadow');
  FONT_PLAIN_11       := TFontSet.Create('../fonts/Plain 11');
  FONT_PLAIN_12       := TFontSet.Create('../fonts/Plain 12');

  Fail := 0;
  Pass := 0;
  StartTime := GetTickCount64();

  Test(@Test_UpText, 'UpText');
  Test(@Test_Threshold1, 'Threshold1');
  Test(@Test_Threshold2, 'Threshold2');
  Test(@Test_ThresholdInvert, 'Threshold Invert');
  Test(@Test_MultiLine1, 'MultiLine1');
  Test(@Test_MultiLine2, 'MultiLine2');
  Test(@Test_MultiLine3, 'MultiLine3');
  Test(@Test_MultiLine4, 'MultiLine4');
  Test(@Test_MultiLine5, 'MultiLine5');
  Test(@Test_MultiLine6, 'MultiLine6');
  Test(@Test_Shadow, 'Shadow');
  Test(@Test_Invert, 'Invert');
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

  ReadLn;
end.

