unit simpleocr.engine;
{==============================================================================]
  Copyright (c) 2021, Jarl `slacky` Holta
  Project: SimpleOCR
  Project URL: https://github.com/slackydev/SimpleOCR
  License: GNU Lesser GPL (http://www.gnu.org/licenses/lgpl.html)
[==============================================================================}
{$i simpleocr.inc}

interface

uses
  classes, sysutils,
  simpleocr.tpa, simpleocr.types;

const
  FONTSET_SPACE = #32;

  FONTSET_START = #32;
  FONTSET_END   = #126;

type
  PFontCharacter = ^TFontCharacter;
  TFontCharacter = packed record
    ImageWidth, ImageHeight: Integer;
    Width, Height: Integer;
    CharacterBounds: TBox;
    CharacterPoints: TPointArray;
    CharacterPointsLength: Integer;
    ShadowPoints: TPointArray;
    BackgroundPoints: TPointArray;
    BackgroundPointsLength: Integer;
    TotalBounds: TBox;
    Value: Char;
  end;

  PFontSet = ^TFontSet;
  TFontSet = packed record
  private
    function GetCharacterPoints(Character: Char): Integer; inline;
  public
    Name: String;
    Characters: array[FONTSET_START..FONTSET_END] of TFontCharacter;
    SpaceWidth: Integer;
    MaxWidth: Integer;
    MaxHeight: Integer;

    property CharacterPoints[Character: Char]: Integer read GetCharacterPoints;

    procedure Load(FontPath: String; Space: Integer = 4);
  end;

  EOCRFilterType = (
    UPTEXT,
    COLOR,
    THRESHOLD,
    SHADOW,
    INVERT_COLOR
  );

  POCRFilter = ^TOCRFilter;
  TOCRFilter = packed record
    FilterType: EOCRFilterType;

    UpTextFilter: packed record
      MaxShadowValue: Int32;
      Tolerance: Int32;
    end;

    ColorRule: packed record
      Colors: array of packed record
        Color: Integer;
        Tolerance: Integer;
      end;
      Invert: Boolean;
    end;

    ThresholdRule: packed record
      Amount: Integer;
      Invert: Boolean;
    end;

    ShadowRule: packed record
      MaxShadowValue: Integer;
      Tolerance: Integer;
    end;

    MinCharacterMatch: Char;
  end;

  PSimpleOCR = ^TSimpleOCR;
  TSimpleOCR = packed record
  private
    FFontSet: TFontSet;
    FClient: T2DIntegerArray;
    FWidth: Integer;
    FHeight: Integer;
    FSearchArea: TBox;

    function Init(const FontSet: TFontSet; const Static: Boolean): Boolean;
    function Init(const FontSet: TFontSet; const Filter: TOCRFilter): Boolean;

    function _RecognizeX(Bounds: TBox; const MinCharacterCount, MaxWalk: Integer; out TextHits: Integer; out TextBounds: TBox): String;
    function _RecognizeXY(Bounds: TBox; const MinCharacterCount, MaxWalk: Integer; out TextHits: Integer; out TextBounds: TBox): String;
  public
    class function Create(const Client: T2DIntegerArray): TSimpleOCR; static;

    function TextToMatrix(const Text: String; const FontSet: TFontSet): T2DIntegerArray;
    function TextToTPA(const Text: String; const FontSet: TFontSet): TPointArray;

    function LocateText(const Text: String; const FontSet: TFontSet; out Bounds: TBox): Single; overload;
    function LocateText(const Text: String; const FontSet: TFontSet; const Filter: TOCRFilter; out Bounds: TBox): Single; overload;

    function Recognize(const Filter: TOCRFilter; const FontSet: TFontSet): String;
    function RecognizeStatic(const Filter: TOCRFilter; const FontSet: TFontSet; const MaxWalk: Integer = 20): String;
    function RecognizeLines(const Filter: TOCRFilter; const FontSet: TFontSet; out TextBounds: TBoxArray): TStringArray; overload;
    function RecognizeLines(const Filter: TOCRFilter; const FontSet: TFontSet): TStringArray; overload;
    function RecognizeUpText(const Filter: TOCRFilter; const FontSet: TFontSet; const MaxWalk: Integer = 20): String;
  end;

implementation

uses
  graphtype, intfgraphics, graphics, lazfileutils, math,
  simpleocr.filters;

function TFontSet.GetCharacterPoints(Character: Char): Integer;
begin
  if (Character in [FONTSET_START..FONTSET_END]) then
    Result := Characters[Character].CharacterPointsLength
  else
    Result := 0;
end;

procedure TFontSet.Load(FontPath: String; Space: Integer);

  function FindColor(Image: TLazIntfImage; Color: Integer): TPointArray;
  var
    X, Y: Integer;
    Count: Integer = 0;
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
  I: Integer;
  Image: TLazIntfImage;
  Description: TRawImageDescription;
  FontChar: TFontCharacter;
begin
  FontPath := IncludeTrailingPathDelimiter(ExpandFileName(FontPath));

  Self := Default(TFontSet);
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

      if (Chr(I) = #32) then
      begin
        FontChar.Width := Image.Width;
        FontChar.Height := Image.Height;
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

      if (FontChar.Width > MaxWidth) then
        MaxWidth := FontChar.Width;
      if (FontChar.Height > MaxHeight) then
        MaxHeight := FontChar.Height;

      FontChar.TotalBounds := TPABounds(FontChar.CharacterPoints + FontChar.ShadowPoints + FontChar.BackgroundPoints);
      FontChar.CharacterPointsLength := Length(FontChar.CharacterPoints);

      Self.Characters[FontChar.Value] := FontChar;
    end;
  end;

  Image.Free();
end;

function TSimpleOCR.Init(const FontSet: TFontSet; const Static: Boolean): Boolean;
begin
  Result := MatrixDimensions(FClient, FWidth, FHeight);

  if Result then
  begin
    FFontSet := FontSet;
    FSearchArea := Box(0, 0, FWidth - 1, FHeight - 1);

    if not Static then
    begin
      FSearchArea.X1 -= FontSet.MaxWidth div 2;
      FSearchArea.Y1 -= FFontSet.MaxHeight div 2;
      FSearchArea.X2 += FontSet.MaxWidth div 2;
      FSearchArea.Y2 += FFontSet.MaxHeight div 2;
    end;
  end;
end;

function TSimpleOCR.Init(const FontSet: TFontSet; const Filter: TOCRFilter): Boolean;
begin
  Result := MatrixDimensions(FClient, FWidth, FHeight);

  if Result then
  begin
    FFontSet := FontSet;

    case Filter.FilterType of
      EOCRFilterType.COLOR,
      EOCRFilterType.INVERT_COLOR:
        Result := SimpleOCRFilter.ApplyColorRule(FClient, TColorRuleArray(Filter.ColorRule.Colors), Filter.ColorRule.Invert, FSearchArea);

      EOCRFilterType.THRESHOLD:
        Result := SimpleOCRFilter.ApplyThresholdRule(FClient, Filter.ThresholdRule.Invert, Filter.ThresholdRule.Amount, FSearchArea);

      EOCRFilterType.SHADOW:
        Result := SimpleOCRFilter.ApplyShadowRule(FClient, Filter.ShadowRule.MaxShadowValue, Filter.ShadowRule.Tolerance, FSearchArea);
    end;

    FSearchArea.X1 -= FontSet.MaxWidth div 2;
    FSearchArea.Y1 -= FFontSet.MaxHeight div 2;
    FSearchArea.X2 += FontSet.MaxWidth div 2;
    FSearchArea.Y2 += FFontSet.MaxHeight div 2;
  end;
end;

function TSimpleOCR._RecognizeX(Bounds: TBox; const MinCharacterCount, MaxWalk: Integer; out TextHits: Integer; out TextBounds: TBox): String;

  function CompareChar(const Character: TFontCharacter; const OffsetX, OffsetY: Integer): Integer; inline;
  var
    I, Hits, Any: Integer;
    P: TPoint;
  begin
    Result := 0;

    // Check if  character is loaded
    if (Character.CharacterPointsLength = 0) then
      Exit;

    // Check if entire character is in client
    with Character.TotalBounds do
      if (X1 + OffsetX < 0) or (Y1 + OffsetY < 0) or (X2 + OffsetX >= FWidth) or (Y2 + OffsetY >= FHeight) then
        Exit;

    Hits := 0;
    Any := 0;

    // count hits for the character
    for I := 0 to Character.CharacterPointsLength - 1 do
    begin
      P := Character.CharacterPoints[I];
      if (FClient[P.Y + OffsetY, P.X + OffsetX] <> FILTER_HIT) then
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
        if (FClient[P.Y + OffsetY, P.X + OffsetX] <> FILTER_HIT) then
          Inc(Any)
        else
          Dec(Hits);
      end;

      if (Any <= (Character.BackgroundPointsLength div 2)) then
        Exit; // <= 50% match.

      Inc(Hits, Any);
    end;

    Result := Hits;
  end;

var
  Space, Hits, BestHits: Integer;
  BestCharacter: PFontCharacter;
  Character: Char;
begin
  Result := '';

  TextHits := 0;

  TextBounds.X1 := $FFFFFF;
  TextBounds.Y1 := $FFFFFF;
  TextBounds.X2 := 0;
  TextBounds.Y2 := 0;

  Space := 0;

  while (Bounds.X1 < Bounds.X2) and (Space < MaxWalk) do
  begin
    BestHits := 0;

    for Character := FONTSET_START to FONTSET_END do
    begin
      Hits := CompareChar(FFontSet.Characters[Character], Bounds.X1, Bounds.Y1);

      if (Hits > BestHits) then
      begin
        BestHits := Hits;
        BestCharacter := @FFontSet.Characters[Character];
      end;
    end;

    if (BestHits > 0) then
    begin
      if (BestCharacter^.CharacterPointsLength >= MinCharacterCount) then
      begin
        if (Result <> '') and (Space >= FFontSet.SpaceWidth) then
          Result += ' ';

        Space := 0;

        TextHits += BestHits;

        TextBounds.X1 := Min(TextBounds.X1, Bounds.X1 + BestCharacter^.CharacterBounds.X1);
        TextBounds.Y1 := Min(TextBounds.Y1, Bounds.Y1 + BestCharacter^.CharacterBounds.Y1);
        TextBounds.X2 := Max(TextBounds.X2, Bounds.X1 + BestCharacter^.CharacterBounds.X2);
        TextBounds.Y2 := Max(TextBounds.Y2, Bounds.Y1 + BestCharacter^.CharacterBounds.Y2);

        Result += BestCharacter^.Value;
        Bounds.X1 += BestCharacter^.Width;

        Continue;
      end else
        Space := 0;
    end else
      Space += 1;

    Bounds.X1 += 1;
  end;
end;

function TSimpleOCR._RecognizeXY(Bounds: TBox; const MinCharacterCount, MaxWalk: Integer; out TextHits: Integer; out TextBounds: TBox): String;
var
  Text: String;
  Best: record
    Hits: Integer;
    Bounds: TBox;
    Text: String;
  end;
begin
  Best.Hits := 0;

  while (Bounds.Y1 < Bounds.Y2) do
  begin
    Text := Self._RecognizeX(Bounds, MinCharacterCount, MaxWalk, TextHits, TextBounds);

    if (TextHits > Best.Hits) then
    begin
      Best.Hits := TextHits;
      Best.Bounds := TextBounds;
      Best.Text := Text;
    end;

    Bounds.Y1 += 1;
  end;

  TextHits := Best.Hits;
  TextBounds := Best.Bounds;

  Result := Best.Text;
end;

class function TSimpleOCR.Create(const Client: T2DIntegerArray): TSimpleOCR;
begin
  Result := Default(TSimpleOCR);
  Result.FClient := Client;
end;

function TSimpleOCR.TextToMatrix(const Text: String; const FontSet: TFontSet): T2DIntegerArray;
var
  I, J, X, Y: Integer;
  Bounds: TBox;
begin
  Bounds.X1 := 0;
  Bounds.X2 := 0;
  Bounds.Y1 := $FFFFFF;
  Bounds.Y2 := 0;

  for I := 1 to Length(Text) do
    if (Text[I] in [FONTSET_START..FONTSET_END]) then
      with FontSet.Characters[Text[I]] do
      begin
        if (Text[I] <> FONTSET_SPACE) then
        begin
          if (CharacterBounds.Y1 < Bounds.Y1) then
            Bounds.Y1 := CharacterBounds.Y1;
          if (CharacterBounds.Y2 > Bounds.Y2) then
            Bounds.Y2 := CharacterBounds.Y2;
        end;

        Bounds.X2 += ImageWidth;
      end;

  SetLength(Result, Max(0, (Bounds.Y2 - Bounds.Y1) + 1), Bounds.X2);
  if (Length(Result) = 0) or (Length(Result[0]) = 0) then
    Exit;

  for I := 1 to Length(Text) do
  begin
    if (not (Text[I] in [FONTSET_START..FONTSET_END])) then
      Continue;

    with FontSet.Characters[Text[I]] do
    begin
      if (Text[I] = FONTSET_SPACE) then
      begin
        for X := Bounds.X1 to (Bounds.X1 + ImageWidth) - 1 do
          for Y := 0 to Bounds.Y2 - Bounds.Y1 do
            Result[Y, X] := $00FF00;
      end else
      begin
        for J := 0 to CharacterPointsLength - 1 do
          Result[CharacterPoints[J].Y - Bounds.Y1, Bounds.X1 + CharacterPoints[J].X + CharacterBounds.X1] := $0000FF;
      end;

      Bounds.X1 += ImageWidth;
    end;
  end;
end;

function TSimpleOCR.TextToTPA(const Text: String; const FontSet: TFontSet): TPointArray;
var
  Matrix: T2DIntegerArray;
  X, Y, W, H: Integer;
  Count: Integer;
begin
  Result := nil;

  Matrix := Self.TextToMatrix(Text, FontSet);
  if MatrixDimensions(Matrix, W, H) then
  begin
    SetLength(Result, W*H);

    Count := 0;
    for Y := 0 to H-1 do
      for X := 0 to W-1 do
        if (Matrix[Y, X] = $0000FF) then
        begin
          Result[Count] := Point(X, Y);
          Inc(Count);
        end;

    SetLength(Result, Count);
  end;
end;

function TSimpleOCR.LocateText(const Text: String; const FontSet: TFontSet; out Bounds: TBox): Single;
var
  X, Y: Integer;
  Color, Bad, I: Integer;
  P: TPoint;
  Match: Single;
  TextMatrix: T2DIntegerArray;
  TextWidth, TextHeight: Integer;
  CharacterIndices, OtherIndices: TPointArray;
  CharacterCount, OtherCount: Integer;
label
  NotFound;
begin
  Result := 0;

  TextMatrix := Self.TextToMatrix(Text, FontSet);
  if not MatrixDimensions(TextMatrix, TextWidth, TextHeight) then
    Exit;
  if not Self.Init(FontSet, False) then
    Exit;

  SetLength(CharacterIndices, TextWidth * TextHeight);
  SetLength(OtherIndices, TextWidth * TextHeight);

  CharacterCount := 0;
  OtherCount := 0;

  for Y := 0 to TextHeight - 1 do
    for X := 0 to TextWidth - 1 do
      if (TextMatrix[Y][X] = 255) then
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

  if (Length(CharacterIndices) > 0) then
  begin
    FSearchArea.X2 -= TextWidth - 1;
    FSearchArea.Y2 -= TextHeight - 1;

    for Y := FSearchArea.Y1 to FSearchArea.Y2 do
      for X := FSearchArea.X1 to FSearchArea.X2 do
      begin
        P.Y := Y + CharacterIndices[0].Y;
        P.X := X + CharacterIndices[0].X;

        if (P.X < 0) or (P.Y < 0) or (P.X >= FWidth) or (P.Y >= FHeight) then
          Continue;
        Color := FClient[P.Y, P.X];
        if (Color = FILTER_MISS) then
          Continue;

        for I := 1 to CharacterCount do
        begin
          P.Y := Y + CharacterIndices[I].Y;
          P.X := X + CharacterIndices[I].X;

          if (P.X < 0) or (P.Y < 0) or (P.X >= FWidth) or (P.Y >= FHeight) or (FClient[P.Y, P.X] <> Color) then
            goto NotFound;
        end;

        Bad := 0;

        for I := 0 to OtherCount do
        begin
          P.Y := Y + OtherIndices[I].Y;
          P.X := X + OtherIndices[I].X;

          if (P.X < 0) or (P.Y < 0) or (P.X >= FWidth) or (P.Y >= FHeight) or (FClient[P.Y, P.X] = Color) then
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

function TSimpleOCR.LocateText(const Text: String; const FontSet: TFontSet; const Filter: TOCRFilter; out Bounds: TBox): Single;
begin
  Result := 0;
  if Self.Init(FontSet, Filter) then
    Result := LocateText(Text, FontSet, Bounds);
end;

function TSimpleOCR.Recognize(const Filter: TOCRFilter; const FontSet: TFontSet): String;
var
  Hits: Integer;
  Bounds: TBox;
begin
  Result := '';
  if Self.Init(FontSet, Filter) then
    Result := _RecognizeXY(FSearchArea, FontSet.CharacterPoints[Filter.MinCharacterMatch], $FFFFFF, Hits, Bounds);
end;

// Uptext has its own special CompareChar
function TSimpleOCR.RecognizeUpText(const Filter: TOCRFilter; const FontSet: TFontSet; const MaxWalk: Integer): String;

  function CompareChar(const Character: TFontCharacter; const OffsetX, OffsetY: Integer): Integer; inline;
  var
    I, Hits, Any: Integer;
    First: TRGB32;
    P: TPoint;
  begin
    Result := 0;

    // Check if  character is loaded
    if (Character.CharacterPointsLength = 0) then
      Exit;

    // Check if entire character is in client
    with Character.TotalBounds do
      if (X1 + OffsetX < 0) or (Y1 + OffsetY < 0) or (X2 + OffsetX >= FWidth) or (Y2 + OffsetY >= FHeight) then
        Exit;

    with Filter.UpTextFilter do
    begin
      Hits := 0;
      Any := 0;

      First := TRGB32(FClient[Character.CharacterPoints[0].Y + OffsetY, Character.CharacterPoints[0].X + OffsetX]);
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
        with TRGB32(FClient[P.Y + OffsetY, P.X + OffsetX]) do
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
          with TRGB32(FClient[P.Y + OffsetY, P.X + OffsetX]) do
            if Sqr(R - First.R) + Sqr(B - First.B) + Sqr(G - First.G) > Tolerance then
              Inc(Any)
            else
              Dec(Hits);
        end;

        if (Character.BackgroundPointsLength > 0) and (Any <= (Character.BackgroundPointsLength div 2)) then
          Exit;

        Inc(Hits, Any);
      end else
      begin
        // count hits for shadow
        for I := 0 to High(Character.ShadowPoints) do
        begin
          P := Character.ShadowPoints[I];
          with TRGB32(FClient[P.Y + OffsetY, P.X + OffsetX]) do
            if (R > MaxShadowValue) or (G > MaxShadowValue) or (B > MaxShadowValue) then
              Exit;

          Inc(Hits);
        end;
      end;

      Result := Hits;
    end;
  end;

var
  Character: Char;
  BestCharacter: PFontCharacter;
  Space, Hits, BestHits, MinPointsNeeded: Integer;
begin
  Result := '';

  if (Filter.FilterType <> EOCRFilterType.UPTEXT) then
  begin
    WriteLn('TSimpleOCR.RecognizeUpText: OCR Filter is not TOCRUpTextFilter');
    Halt(1);
  end;

  if Self.Init(FontSet, True) then
  begin
    MinPointsNeeded := FontSet.CharacterPoints[Filter.MinCharacterMatch];
    Space := 0;

    while (FSearchArea.X1 < FSearchArea.X2) and (Space < MaxWalk) do
    begin
      BestHits := 0;

      for Character := FONTSET_START to FONTSET_END do
      begin
        Hits := CompareChar(FFontSet.Characters[Character], FSearchArea.X1, FSearchArea.Y1);

        if (Hits > BestHits) then
        begin
          BestHits := Hits;
          BestCharacter := @FFontSet.Characters[Character];
        end;
      end;

      if (BestHits > 0) then
      begin
        if (BestCharacter^.CharacterPointsLength >= MinPointsNeeded) then
        begin
          if (Result <> '') and (Space >= FFontSet.SpaceWidth) then
            Result += ' ';
          Space := 0;

          Result += BestCharacter^.Value;
          FSearchArea.X1 += BestCharacter^.Width;

          Continue;
        end else
          Space := 0;
      end else
        Space += 1;

      FSearchArea.X1 += 1;
    end;
  end;
end;

function TSimpleOCR.RecognizeStatic(const Filter: TOCRFilter; const FontSet: TFontSet; const MaxWalk: Integer): String;
var
  Hits: Integer;
  Bounds: TBox;
begin
  Result := '';
  if Self.Init(FontSet, Filter) then
    Result := Self._RecognizeX(FSearchArea, FontSet.CharacterPoints[Filter.MinCharacterMatch], MaxWalk, Hits, Bounds);
end;

function TSimpleOCR.RecognizeLines(const Filter: TOCRFilter; const FontSet: TFontSet; out TextBounds: TBoxArray): TStringArray;
var
  Bounds: TBox;
  Text: String;
  Hits: Integer;
  MinCharacterPoints: Integer;
begin
  Result := nil;
  TextBounds := nil;

  if Self.Init(FontSet, Filter) then
  begin
    MinCharacterPoints := FontSet.CharacterPoints[','];

    while (FSearchArea.Y1 + (FFontSet.MaxHeight div 2) < FSearchArea.Y2) do
    begin
      Self._RecognizeX(FSearchArea, MinCharacterPoints, $FFFFFF, Hits, Bounds);

      if (Hits > 0) then
      begin
        Text := Self._RecognizeXY(Box(FSearchArea.X1, FSearchArea.Y1, FSearchArea.X2, FSearchArea.Y1 + FFontSet.MaxHeight - 2), MinCharacterPoints, $FFFFFF, Hits, Bounds);
        if (Text = '') then
          Exit;

        Result := Result + [Text];
        TextBounds := TextBounds + [Bounds];

        FSearchArea.Y1 += FFontSet.MaxHeight - 4;
      end;

      FSearchArea.Y1 += 1;
    end;
  end;
end;

function TSimpleOCR.RecognizeLines(const Filter: TOCRFilter; const FontSet: TFontSet): TStringArray;
var
  TextBounds: TBoxArray;
begin
  Result := Self.RecognizeLines(Filter, FontSet, TextBounds);
end;

end.
