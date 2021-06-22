unit simpleocr.engine;
{==============================================================================]
  Copyright (c) 2021, Jarl `slacky` Holta
  Project: SimpleOCR
  Project URL: https://github.com/slackydev/SimpleOCR
  License: GNU Lesser GPL (http://www.gnu.org/licenses/lgpl.html)
[==============================================================================}
{$mode objfpc}{$H+}
{$i simpleocr.inc}

interface

uses
  sysutils,
  simpleocr.tpa, simpleocr.types;

const
  FONTSET_START = #32;
  FONTSET_END   = #126;
  FONTSET_RANGE = [#32..#126];

  FONTSET_SPACE = #32;

type
  PFontChar = ^TFontCharacter;
  TFontCharacter = packed record
    ImageWidth, ImageHeight: Int32;
    Width, Height: Int32;
    CharacterBounds: TBox;
    CharacterPoints: TPointArray;
    CharacterPointsLength: Int32;
    ShadowPoints: TPointArray;
    BackgroundPoints: TPointArray;
    BackgroundPointsLength: Int32;
    TotalBounds: TBox;
    Value: Char;
  end;

  PFontSet = ^TFontSet;
  TFontSet = packed record
    Name: String;
    Characters: array[FONTSET_START..FONTSET_END] of TFontCharacter;
    SpaceWidth: Int32;
    MaxWidth: Int32;
    MaxHeight: Int32;

    procedure Load(FontPath: String; Space: Int32);
  end;

  EOCRRule = (
    ANY_COLOR,
    COLOR,
    THRESHOLD,
    SHADOW
  );

  PCompareRules = ^TCompareRules;
  TCompareRules = packed record
    Rule: EOCRRule;

    AnyColorRule: packed record
      MaxShadowValue: Int32;
      Tolerance: Int32;
    end;

    ColorRule: packed record
      Colors: array of packed record
        Color: Int32;
        Tolerance: Int32;
      end;
    end;

    ThresholdRule: packed record
      Amount: Int32;
      Invert: Boolean;
    end;

    ShadowRule: packed record
      MaxShadowValue: Int32;
    end;

    MinCharacterMatch: Char;
  end;

  PSimpleOCR = ^TSimpleOCR;
  TSimpleOCR = packed record
  public
  type
    TRecognizeCharFunction = function(var Self: TSimpleOCR; const Offset: TPoint; out FontChar: TFontCharacter): Int32;
  private
    FFont: TFontSet;
    FClient: T2DIntegerArray;
    FWidth: Int32;
    FHeight: Int32;
    FSearchArea: TBox;
    FCompareRules: TCompareRules;

    function Init(const Matrix: T2DIntegerArray; const Font: TFontSet; const Filter: TCompareRules): Boolean;

    function InClient(const Character: TFontCharacter; const Offset: TPoint): Boolean;

    function RecognizeRow(const RecognizeCharFunction: TRecognizeCharFunction; Bounds: TBox; const MaxWalk: Int32; out TextHits: Int32; out TextBounds: TBox): String;
  public
    function DrawText(const Text: String; const Font: TFontSet): T2DIntegerArray;

    function LocateText(const Matrix: T2DIntegerArray; const Text: String; const Font: TFontSet; const Filter: TCompareRules; out Bounds: TBox): Single; overload;

    function Recognize(const Matrix: T2DIntegerArray; const Filter: TCompareRules; const Font: TFontSet): String;
    function RecognizeStatic(const Matrix: T2DIntegerArray; const Filter: TCompareRules; const Font: TFontSet; const MaxWalk: Int32): String;
    function RecognizeMulti(const Matrix: T2DIntegerArray; const Filter: TCompareRules; const Font: TFontSet; out TextBounds: TBoxArray): TStringArray;
  end;

implementation

uses
  graphtype, intfgraphics, graphics, lazfileutils, math,
  simpleocr.filters;

function RecognizeChar(var Self: TSimpleOCR; const Offset: TPoint; out FoundCharacter: TFontCharacter): Int32;

  function Compare(const Character: TFontCharacter): Int32; inline;
  var
    I, Hits, Any: Int32;
    P: TPoint;
  begin
    Result := 0;

    with Self do
    begin
      Hits := 0;
      Any := 0;

      // count hits for the character
      for I := 0 to Character.CharacterPointsLength - 1 do
      begin
        P := Character.CharacterPoints[I];
        if (FClient[P.Y + Offset.Y, P.X + Offset.X] <> FILTER_HIT) then
          Exit;

        Inc(Hits, 2);
      end;

      if (Hits < Character.CharacterPointsLength) then
        Exit; // < 50% match.

      if (Character.BackgroundPointsLength > 0) then
      begin
        // counts hits for the points that should not have equal Color to character
        for I := 0 to High(Character.BackgroundPoints) do
        begin
          P := Character.BackgroundPoints[I];
          if (FClient[P.Y + Offset.Y, P.X + Offset.X] <> FILTER_HIT) then
            Inc(Any)
          else
            Dec(Hits);
        end;

        if (Any <= (Character.BackgroundPointsLength div 2)) then
          Exit; // <= 50% match.
      end;

      Inc(Hits, Any);
    end;

    Result := Hits;
  end;

var
  Index, BestIndex: Char;
  Hits, BestHits: Int32;
begin
  with Self do
  begin
    BestHits := 0;

    for Index := FONTSET_START to FONTSET_END do
    begin
      if (FFont.Characters[Index].Value > FONTSET_SPACE) and InClient(FFont.Characters[Index], Offset) then
      begin
        Hits := Compare(FFont.Characters[Index]);

        if (Hits > BestHits) then
        begin
          BestHits := Hits;
          BestIndex := Index;
        end;
      end;
    end;

    Result := BestHits;
    if (Result > 0) then
      FoundCharacter := FFont.Characters[BestIndex];
  end;
end;

function RecognizeChar_AnyColor(var Self: TSimpleOCR; const Offset: TPoint; out FoundCharacter: TFontCharacter): Int32;

  function Compare(const Character: TFontCharacter): Int32; inline;
  var
    I, Hits, Any: Int32;
    First: TRGB32;
    P: TPoint;
  begin
    Result := 0;

    with Self, FCompareRules.AnyColorRule do
    begin
      Hits := 0;
      Any := 0;

      First := TRGB32(FClient[Character.CharacterPoints[0].Y + Offset.Y, Character.CharacterPoints[0].X + Offset.X]);
      if (MaxShadowValue > 0) then
      begin
        if ((First.R + First.G + First.B) div 3 < 85) and
           ((First.R < MaxShadowValue * 2) and (First.G < MaxShadowValue * 2) and (First.B < MaxShadowValue * 2)) then
          Exit;
      end;

      // count hits for the character
      for I := 0 to Character.CharacterPointsLength - 1 do
      begin
        P := Character.CharacterPoints[I];
        with TRGB32(FClient[P.Y + Offset.Y, P.X + Offset.X]) do
          if Sqr(R - First.R) + Sqr(B - First.B) + Sqr(G - First.G) > Tolerance then
            Exit;

        Inc(Hits, 2);
      end;

      if (Hits < Character.CharacterPointsLength) then
        Exit; // < 50% match.

      if (MaxShadowValue = 0) then
      begin
        // counts hits for the points that should not have equal Color to character
        // not needed for shadow-fonts
        for I := 0 to High(Character.BackgroundPoints) do
        begin
          P := Character.BackgroundPoints[I];
          with TRGB32(FClient[P.Y + Offset.Y, P.X + Offset.X]) do
            if Sqr(R - First.R) + Sqr(B - First.B) + Sqr(G - First.G) > Tolerance then
              Inc(Any)
            else
              Dec(Hits);
        end;

        if (Length(Character.BackgroundPoints) > 0) and (Any <= (Length(Character.BackgroundPoints) div 2)) then
          Exit;

        Inc(Hits, Any);
      end else
      begin
        // count hits for FFont-shadow
        for I := 0 to High(Character.ShadowPoints) do
        begin
          P := Character.ShadowPoints[I];
          with TRGB32(FClient[P.Y + Offset.Y, P.X + Offset.X]) do
            if (R > MaxShadowValue) or (G > MaxShadowValue) or (B > MaxShadowValue) then
              Exit;

          Inc(Hits);
        end;
      end;

      Result := Hits;
    end;
  end;

var
  Index, BestIndex: Char;
  Hits, BestHits: Int32;
begin
  with Self do
  begin
    BestHits := 0;

    for Index := FONTSET_START to FONTSET_END do
    begin
      if (FFont.Characters[Index].Value > FONTSET_SPACE) and InClient(FFont.Characters[Index], Offset) then
      begin
        Hits := Compare(FFont.Characters[Index]);

        if (Hits > BestHits) then
        begin
          BestHits := Hits;
          BestIndex := Index;
        end;
      end;
    end;

    Result := BestHits;
    if (Result > 0) then
      FoundCharacter := FFont.Characters[BestIndex];
  end;
end;

procedure TFontSet.Load(FontPath: String; Space: Int32);

  function FindColor(Image: TLazIntfImage; Color: Int32): TPointArray;
  var
    X, Y: Int32;
    Count: Int32 = 0;
  begin
    SetLength(Result, Image.Width * Image.Height);

    for X := 0 to Image.Width - 1 do
      for Y := 0 to Image.Height - 1 do
      begin
        if FPColorToTColor(Image.Colors[X, Y]) = Color then
        begin
          Result[Count].X := X;
          Result[Count].Y := Y;

          Inc(Count);
        end;
      end;

    SetLength(Result, Count);
  end;

var
  I: Int32;
  Image: TLazIntfImage;
  Description: TRawImageDescription;
  FontChar: TFontCharacter;
begin
  FontPath := IncludeTrailingPathDelimiter(ExpandFileName(FontPath));

  Self.Name := ExtractFileNameOnly(FontPath);
  Self.SpaceWidth := Space;

  Description.Init_BPP32_B8G8R8_BIO_TTB(0, 0);

  Image := TLazIntfImage.Create(0, 0);
  Image.DataDescription := Description;

  for I := 32 to 126 do
  begin
    if FileExists(FontPath + IntToStr(I) + '.bmp') then
    begin
      Image.LoadFromFile(FontPath + IntToStr(I) + '.bmp');

      FontChar := Default(TFontCharacter);
      FontChar.ImageWidth := Image.Width;
      FontChar.ImageHeight := Image.Height;
      FontChar.Value := Chr(I);

      if (Chr(I) = FONTSET_START) then
      begin
        FontChar.Width := Image.Width;
        FontChar.Height := Image.Height;
        FontChar.CharacterPoints := FindColor(Image, $000000);
        FontChar.CharacterBounds := TPABounds(FontChar.CharacterPoints);
      end else
      begin
        FontChar.CharacterPoints := FindColor(Image, $FFFFFF);
        FontChar.CharacterBounds := TPABounds(FontChar.CharacterPoints);
        FontChar.ShadowPoints := FindColor(Image, $0000FF);

        if (FontChar.CharacterBounds.X1 > 0) then
        begin
          OffsetTPA(FontChar.CharacterPoints, -FontChar.CharacterBounds.X1, 0);
          OffsetTPA(FontChar.ShadowPoints, -FontChar.CharacterBounds.X1, 0);

          SortTPAByColumn(FontChar.CharacterPoints);
        end;

        FontChar.BackgroundPoints := InvertTPA(FontChar.CharacterPoints + FontChar.ShadowPoints);
        FontChar.BackgroundPointsLength := Length(FontChar.BackgroundPoints);

        with TPABounds(FontChar.CharacterPoints + FontChar.ShadowPoints) do
        begin
          FontChar.Width  := X2-X1+1;
          FontChar.Height := Y2-Y1+1;
        end;
      end;

      if FontChar.Width > MaxWidth then
        MaxWidth := FontChar.Width;
      if FontChar.Height > MaxHeight then
        MaxHeight := FontChar.Height;

      FontChar.TotalBounds := TPABounds(FontChar.CharacterPoints + FontChar.ShadowPoints + FontChar.BackgroundPoints);
      FontChar.CharacterPointsLength := Length(FontChar.CharacterPoints);
      if (FontChar.CharacterPointsLength > 0) then
        Self.Characters[FontChar.Value] := FontChar;
    end;
  end;

  Image.Free();
end;

function TSimpleOCR.DrawText(const Text: String; const Font: TFontSet): T2DIntegerArray;
var
  I, X, Y: Int32;
  P: TPoint;
  Bounds: TBox;
begin
  Bounds.X1 := 0;
  Bounds.X2 := 0;
  Bounds.Y1 := $FFFFFF;
  Bounds.Y2 := 0;

  for I := 1 to Length(Text) do
    if (Text[I] in FONTSET_RANGE) then
      with Font.Characters[Text[I]] do
      begin
        if (Text[I] <> FONTSET_START) then
        begin
          if (CharacterBounds.Y1 < Bounds.Y1) then
            Bounds.Y1 := CharacterBounds.Y1;
          if (CharacterBounds.Y2 > Bounds.Y2) then
            Bounds.Y2 := CharacterBounds.Y2;
        end;

        Bounds.X2 += ImageWidth;
      end;

  SetLength(Result, (Bounds.Y2 - Bounds.Y1) + 1, Bounds.X2);

  for I := 1 to Length(Text) do
    if (Text[I] in FONTSET_RANGE) then
      with Font.Characters[Text[I]] do
      begin
        if (Text[I] = ' ') then
        begin
          for X := Bounds.X1 to (Bounds.X1 + ImageWidth) - 1 do
           for Y := 0 to Bounds.Y2 - Bounds.Y1 do
              Result[Y, X] := $00FF00;
        end else
          for P in CharacterPoints do
            Result[P.Y - Bounds.Y1, Bounds.X1 + P.X + CharacterBounds.X1] := $0000FF;

        Bounds.X1 += ImageWidth;
      end;
end;

function TSimpleOCR.LocateText(const Matrix: T2DIntegerArray; const Text: String; const Font: TFontSet; const Filter: TCompareRules; out Bounds: TBox): Single;

  function GetClientSafe(X, Y: Int32): Int32; inline;
  begin
    if (X < 0) or (Y < 0) or (X >= FWidth) or (Y >= FHeight) then
      Result := -1
    else
      Result := FClient[Y, X];
  end;

var
  X, Y: Int32;
  Color, Bad, I: Int32;
  P: TPoint;
  Match: Single;
  TextMatrix: T2DIntegerArray;
  TextWidth, TextHeight: Int32;
  CharacterIndices, OtherIndices: TPointArray;
  CharacterCount, OtherCount: Int32;
label
  NotFound;
begin
  Result := 0;

  if Self.Init(Matrix, Font, Filter) then
  begin
    TextMatrix := Self.DrawText(Text, Font);
    TextHeight := Length(TextMatrix);
    if (TextHeight = 0) then
      Exit;
    TextWidth := Length(TextMatrix[0]);
    if (TextWidth = 0) then
      Exit;

    SetLength(CharacterIndices, TextWidth * TextHeight);
    SetLength(OtherIndices, TextWidth * TextHeight);

    CharacterCount := 0;
    OtherCount := 0;

    for Y := 0 to TextHeight - 1 do
      for X := 0 to TextWidth - 1 do
        if TextMatrix[Y][X] = 255 then
        begin
          CharacterIndices[CharacterCount].X := X;
          CharacterIndices[CharacterCount].Y := Y;

          Inc(CharacterCount);
        end else
        begin
          OtherIndices[OtherCount].X := X;
          OtherIndices[OtherCount].Y := Y;

          Inc(OtherCount);
        end;

    CharacterCount := CharacterCount - 1;
    OtherCount := OtherCount - 1;

    if Length(CharacterIndices) > 0 then
    begin
      FSearchArea.X2 -= TextWidth - 1;
      FSearchArea.Y2 -= TextHeight - 1;

      for Y := FSearchArea.Y1 to FSearchArea.Y2 do
        for X := FSearchArea.X1 to FSearchArea.X2 do
        begin
          P.Y := Y + CharacterIndices[0].Y;
          P.X := X + CharacterIndices[0].X;

          Color := GetClientSafe(P.X, P.Y);
          if (Color = FILTER_MISS) then
            Continue;

          for I := 1 to CharacterCount do
          begin
            P.Y := Y + CharacterIndices[I].Y;
            P.X := X + CharacterIndices[I].X;

            if (GetClientSafe(P.X, P.Y) <> Color) then
              goto NotFound;
          end;

          Bad := 0;

          for I := 0 to OtherCount do
          begin
            P.Y := Y + OtherIndices[I].Y;
            P.X := X + OtherIndices[I].X;

            if (GetClientSafe(P.X, P.Y) = Color) then
              Inc(Bad);
          end;

          Match := 1 - (Bad / OtherCount);

          if (Match > Result) then
          begin
            Result := Match;

            Bounds.X1 := X;
            Bounds.Y1 := Y;
            Bounds.X2 := X + TextWidth;
            Bounds.Y2 := Y + TextHeight;

            if (Result = 1) then
              Exit;
          end;

          NotFound:
        end;
    end;
  end;
end;

function TSimpleOCR.Init(const Matrix: T2DIntegerArray; const Font: TFontSet; const Filter: TCompareRules): Boolean;
begin
  FFont := Font;
  FCompareRules := Filter;
  FClient := Matrix;
  FHeight := Length(FClient);
  if (FHeight > 0) then
    FWidth := Length(FClient[0]);

  Result := (FHeight > 0) and (FWidth > 0);
  if Result then
  begin
    FSearchArea.X1 := 0;
    FSearchArea.Y1 := 0;
    FSearchArea.X2 := FWidth;
    FSearchArea.Y2 := FHeight;

    // Preprocess to binary image
    case FCompareRules.Rule of
      EOCRRule.COLOR:
        Result := SimpleOCRFilter.ApplyColorRule(FClient, TColorRuleArray(Filter.ColorRule.Colors), FSearchArea);

      EOCRRule.THRESHOLD:
        Result := SimpleOCRFilter.ApplyThresholdRule(FClient, Filter.ThresholdRule.Invert, Filter.ThresholdRule.Amount, FSearchArea);

      EOCRRule.SHADOW:
        Result := SimpleOCRFilter.ApplyShadowRule(FClient, Filter.ShadowRule.MaxShadowValue, FSearchArea);
    end;

    FSearchArea := FSearchArea.Expand(FFont.MaxWidth div 2, FFont.MaxHeight div 2);
  end;
end;

function TSimpleOCR.InClient(const Character: TFontCharacter; const Offset: TPoint): Boolean;
begin
  with Character.TotalBounds do
    Result := (X1 + Offset.X >= 0) and (Y1 + Offset.Y >= 0) and (X2 + Offset.X < FWidth) and (Y2 + Offset.Y < FHeight);
end;

function TSimpleOCR.RecognizeRow(const RecognizeCharFunction: TRecognizeCharFunction; Bounds: TBox; const MaxWalk: Int32; out TextHits: Int32; out TextBounds: TBox): String;
var
  Character: TFontCharacter;
  Space, Hits, MinPointsNeeded: Int32;
begin
  Result := '';

  if (FCompareRules.MinCharacterMatch in [FONTSET_START..FONTSET_END]) then
    MinPointsNeeded := FFont.Characters[FCompareRules.MinCharacterMatch].CharacterPointsLength
  else
    MinPointsNeeded := 0;

  TextBounds := Box($FFFFFF, $FFFFFF, 0, 0);
  TextHits := 0;

  Space := 0;

  while (Bounds.X1 < Bounds.X2) and (Space < MaxWalk) do
  begin
    Hits := RecognizeCharFunction(Self, Point(Bounds.X1, Bounds.Y1), Character);

    if (Hits > 0) then
    begin
      if (Character.CharacterPointsLength >= MinPointsNeeded) then
      begin
        if (Result <> '') and (Space >= FFont.SpaceWidth) then
          Result += ' ';
        Space := 0;

        TextBounds.X1 := Min(TextBounds.X1, Bounds.X1 + Character.CharacterBounds.X1);
        TextBounds.Y1 := Min(TextBounds.Y1, Bounds.Y1 + Character.CharacterBounds.Y1);
        TextBounds.X2 := Max(TextBounds.X2, Bounds.X1 + Character.CharacterBounds.X2);
        TextBounds.Y2 := Max(TextBounds.Y2, Bounds.Y1 + Character.CharacterBounds.Y2);

        TextHits += Hits;
        Result += Character.Value;
        Bounds.X1 += Character.Width;

        Continue;
      end else
        Space := 0;
    end else
      Space += 1;

    Bounds.X1 += 1;
  end;
end;

function TSimpleOCR.Recognize(const Matrix: T2DIntegerArray; const Filter: TCompareRules; const Font: TFontSet): String;
var
  Text, BestText: String;
  Hits, BestHits: Int32;
  Bounds: TBox;
begin
  Result := '';

  if Self.Init(Matrix, Font, Filter) then
  begin
    BestHits := 0;
    BestText := '';

    while (FSearchArea.Y1 < FSearchArea.Y2) do
    begin
      Text := Self.RecognizeRow(@RecognizeChar, FSearchArea, $FFFFFF, Hits, Bounds);

      if (Hits > BestHits) then
      begin
        BestText := Text;
        BestHits := Hits;
      end;

      FSearchArea.Y1 += 1;
    end;

    if (BestHits > 0) then
      Result := BestText;
  end;
end;

function TSimpleOCR.RecognizeStatic(const Matrix: T2DIntegerArray; const Filter: TCompareRules; const Font: TFontSet; const MaxWalk: Int32): String;
var
  Hits: Int32;
  Bounds: TBox;
begin
  if Self.Init(Matrix, Font, Filter) then
  begin
    FCompareRules.AnyColorRule.Tolerance := Sqr(FCompareRules.AnyColorRule.Tolerance);

    if (FCompareRules.Rule = EOCRRule.ANY_COLOR) then
      Result := Self.RecognizeRow(@RecognizeChar_AnyColor, Box(0, 0, FWidth - 1, FHeight - 1), MaxWalk, Hits, Bounds)
    else
      Result := Self.RecognizeRow(@RecognizeChar, Box(0, 0, FWidth - 1, FHeight - 1), MaxWalk, Hits, Bounds);
  end;
end;

function TSimpleOCR.RecognizeMulti(const Matrix: T2DIntegerArray; const Filter: TCompareRules; const Font: TFontSet; out TextBounds: TBoxArray): TStringArray;

  function _RecognizeBest(Bounds: TBox; out BestTextBounds: TBox): String; inline;
  var
    Text, BestText: String;
    Hits, BestHits: Int32;
    TextBounds: TBox;
  begin
    Result := '';

    BestHits := 0;
    BestText := '';

    while (Bounds.Y1 < Bounds.Y2) do
    begin
      Text := Self.RecognizeRow(@RecognizeChar, Bounds, $FFFFFF, Hits, TextBounds);

      if (Hits > BestHits) then
      begin
        BestHits := Hits;
        BestText := Text;
        BestTextBounds := TextBounds;
      end;

      Bounds.Y1 += 1;
    end;

    Result := BestText;
  end;

var
  Bounds: TBox;
  Text: String;
  Hits: Int32;
begin
  Result := nil;
  TextBounds := nil;

  if Self.Init(Matrix, Font, Filter) then
  begin
    FCompareRules.MinCharacterMatch := ',';

    while (FSearchArea.Y1 + (FFont.MaxHeight div 2) < FSearchArea.Y2) do
    begin
      Self.RecognizeRow(@RecognizeChar, FSearchArea, $FFFFFF, Hits, Bounds);

      if (Hits > 0) then
      begin
        Text := _RecognizeBest(Box(FSearchArea.X1, FSearchArea.Y1, FSearchArea.X2, FSearchArea.Y1 + FFont.MaxHeight - 2), Bounds);
        if (Text = '') then
          Exit;

        Result := Result + [Text];
        TextBounds := TextBounds + [Bounds];

        FSearchArea.Y1 += FFont.MaxHeight - 4;
      end;

      FSearchArea.Y1 += 1;
    end;
  end;
end;

end.
