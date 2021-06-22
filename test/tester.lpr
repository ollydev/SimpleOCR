// Extremely simple testing to make sure nothing is broken when making changes.

program tester;

{$i simpleocr.inc}
{$assertions on}

uses
  classes, sysutils,
  intfgraphics, graphtype, graphics,
  simpleocr.types, simpleocr.engine;

function LoadImage(FileName: String): T2DIntegerArray;
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
      Result[Y][X] := FPColorToTColor(Image.Colors[X, Y]);

  Image.Free();
end;

procedure SaveMatrix(Matrix: T2DIntegerArray; FileName: String);
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
      Image.Colors[X, Y] := TColorToFPColor(Matrix[Y][X]);

  Image.SaveToFile(FileName);
  Image.Free();
end;

procedure Test_Lines;
const
  Filter: TOCRFilter = (
    FilterType: EOCRFilterType.COLOR;
    UpTextFilter: ();
    ColorRule: (Colors: ((Color: 0; Tolerance: 0), (Color: 128; Tolerance: 0)); Invert: False);
    ThresholdRule: ();
    ShadowRule: ();
    MinCharacterMatch: #0;
  );
var
  SimpleOCR: TSimpleOCR;
  Font: TFontSet;
  TextBounds: TBoxArray;
  Lines: TStringArray;
begin
  SimpleOCR := TSimpleOCR.Create(LoadImage('images/chat.png'));
  Font.Load('../fonts/Quill 8');

  Lines := SimpleOCR.RecognizeLines(Filter, Font, TextBounds);

  Assert(Length(Lines) = 5);
  Assert(Lines[0] = 'Select an Option');
  Assert(Lines[1] = 'Id like to access my bank account, please.');
  Assert(Lines[2] = 'Id like to check my PIN settings.');
  Assert(Lines[3] = 'Id like to collect items.');
  Assert(Lines[4] = 'What is this place?');
end;

procedure Test_UpText;
const
  Filter: TOCRFilter = (
    FilterType: EOCRFilterType.UPTEXT;
    UpTextFilter: (MaxShadowValue: 60; Tolerance: Sqr(85));
    ColorRule: ();
    ThresholdRule: ();
    ShadowRule: ();
    MinCharacterMatch: #0;
  );
var
  SimpleOCR: TSimpleOCR;
  Font: TFontSet;
begin
  SimpleOCR := TSimpleOCR.Create(LoadImage('images/uptext.png'));
  Font.Load('../fonts/Bold 12 Shadow');

  Assert(SimpleOCR.RecognizeUpText(Filter, Font) = 'Take Green d''hide vambraces / 2 more options');
end;

procedure Test_Shadow;
const
  Filter: TOCRFilter = (
    FilterType: EOCRFilterType.SHADOW;
    UpTextFilter: ();
    ColorRule: ();
    ThresholdRule: ();
    ShadowRule: (MaxShadowValue: 5; Tolerance: Sqr(5));
    MinCharacterMatch: #0;
  );
var
  SimpleOCR: TSimpleOCR;
  Font: TFontSet;
begin
  SimpleOCR := TSimpleOCR.Create(LoadImage('images/run.png'));
  Font.Load('../fonts/Plain 11');

  Assert(SimpleOCR.Recognize(Filter, Font) = '53');
end;

begin
  try
    Test_Lines();
  except
    WriteLn('Lines test failed');

    ExitCode := 1;
  end;

  try
    Test_UpText();
  except
    WriteLn('UpText test failed');

    ExitCode := 1;
  end;

  try
    Test_Shadow();
  except
    WriteLn('Shadow test failed');

    ExitCode := 1;
  end;

  if (ExitCode = 0) then
    WriteLn('Tests passed!');
end.

