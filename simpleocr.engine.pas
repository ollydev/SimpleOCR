unit simpleocr.engine;
{==============================================================================]
  Copyright (c) 2021, Jarl `slacky` Holta
  Project: SimpleOCR
  Project URL: https://github.com/slackydev/SimpleOCR
  License: GNU Lesser GPL (http://www.gnu.org/licenses/lgpl.html)
[==============================================================================}

{$i simpleocr.inc}

{$IFOPT D-} // No debug info = enable max optimization
  {$OPTIMIZATION LEVEL4}

  {$OPTIMIZATION noORDERFIELDS} // need same field ordering in script
  {$OPTIMIZATION noDEADSTORE}   // buggy as of FPC .2.2
{$ENDIF}

interface

uses
  Classes, SysUtils,
  simpleocr.types, simpleocr.filters;

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
    function GetCharacterPoints(const Character: Char): Integer; inline;
  public
    Name: String;
    Characters: array[FONTSET_START..FONTSET_END] of TFontCharacter;
    SpaceWidth: Integer;
    MaxWidth: Integer;
    MaxHeight: Integer;

    property CharacterPoints[Character: Char]: Integer read GetCharacterPoints;

    procedure Load(FontPath: String; Space: Integer = 4);
  end;

  PSimpleOCR = ^TSimpleOCR;
  TSimpleOCR = packed record
  private
    FFontSet: TFontSet;
    FClient: TIntegerMatrix;
    // "Internal data"
    FWidth: Integer;
    FHeight: Integer;
    FSearchArea: TBox;
    FBinaryImage: Boolean;
    FMaxShadowValue: Integer;
    FTolerance: Integer;

    function Init(Matrix: TIntegerMatrix; constref FontSet: TFontSet; Filter: TOCRFilter; Static: Boolean): Boolean;

    function _RecognizeX(Bounds: TBox; const MinCharacterCount, MaxWalk: Integer; out TextHits: Integer; out TextBounds: TBox): String;
    function _RecognizeXY(Bounds: TBox; const MinCharacterCount, MaxWalk: Integer; out TextHits: Integer; out TextBounds: TBox): String;
  public
    property Client: TIntegerMatrix read FClient;

    function TextToMatrix(Text: String; constref FontSet: TFontSet): TIntegerMatrix;
    function TextToTPA(Text: String; constref FontSet: TFontSet): TPointArray;

    function LocateText(Matrix: TIntegerMatrix; Text: String; constref FontSet: TFontSet; Filter: TOCRFilter; out Bounds: TBox): Single; overload;
    function LocateText(Matrix: TIntegerMatrix; Text: String; constref FontSet: TFontSet; Filter: TOCRFilter; MinMatch: Single = 1): Boolean; overload;

    function Recognize(Matrix: TIntegerMatrix; Filter: TOCRFilter; constref FontSet: TFontSet): String;
    function RecognizeStatic(Matrix: TIntegerMatrix; Filter: TOCRFilter; constref FontSet: TFontSet; MaxWalk: Integer = 20): String;
    function RecognizeLines(Matrix: TIntegerMatrix; Filter: TOCRFilter; constref FontSet: TFontSet; out TextBounds: TBoxArray): TStringArray; overload;
    function RecognizeLines(Matrix: TIntegerMatrix; Filter: TOCRFilter; constref FontSet: TFontSet): TStringArray; overload;
  end;

implementation

uses
  graphtype, intfgraphics, graphics, math;

function TFontSet.GetCharacterPoints(const Character: Char): Integer;
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
  if (not DirectoryExists(FontPath)) then
  begin
    WriteLn('TFontSet.Load: Font does not exist "' + FontPath + '"');
    Halt(1);
  end;

  Self := Default(TFontSet);
  Self.Name := ExtractFileName(ExcludeTrailingPathDelimiter(FontPath));
  Self.SpaceWidth := Space;

  Description.Init_BPP32_B8G8R8_BIO_TTB(0, 0);

  Image := TLazIntfImage.Create(0, 0);
  Image.DataDescription := Description;

  for I := 32 to 126 do
  begin
    if FileExists(FontPath + IntToStr(I) + '.bmp') then
      Image.LoadFromFile(FontPath + IntToStr(I) + '.bmp')
    else
    if FileExists(FontPath + IntToStr(I) + '.png') then
      Image.LoadFromFile(FontPath + IntToStr(I) + '.png')
    else
      Continue;

    FontChar := Default(TFontCharacter);
    FontChar.ImageWidth := Image.Width;
    FontChar.ImageHeight := Image.Height;
    FontChar.Value := Chr(I);

    if (FontChar.Value = FONTSET_SPACE) then
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

  Image.Free();
end;

function TSimpleOCR.Init(Matrix: TIntegerMatrix; constref FontSet: TFontSet; Filter: TOCRFilter; Static: Boolean): Boolean;
begin
  Result := MatrixDimensions(Matrix, FWidth, FHeight);

  if Result then
  begin
    FClient := Matrix;
    FFontSet := FontSet;

    case Filter.FilterType of
      EOCRFilterType.COLOR,
      EOCRFilterType.INVERT_COLOR:
        begin
          Result := ApplyColorFilter(Filter, FClient, FSearchArea);

          FBinaryImage := True;
          FMaxShadowValue := 0;
          FTolerance := 0;
        end;

      EOCRFilterType.ANY_COLOR:
        begin
          FBinaryImage := False;
          FMaxShadowValue := Filter.AnyColorFilter.MaxShadowValue;
          FTolerance := Sqr(Filter.AnyColorFilter.Tolerance);
        end;

      EOCRFilterType.THRESHOLD:
        begin
          Result := ApplyThresholdFilter(Filter, FClient, FSearchArea);

          FBinaryImage := True;
          FMaxShadowValue := 0;
          FTolerance := 0;
        end;

      EOCRFilterType.SHADOW:
        begin
          Result := ApplyShadowFilter(Filter, FClient, FSearchArea);

          FBinaryImage := True;
          FMaxShadowValue := 0;
          FTolerance := 0;
        end;
    end;

    if Static then
      FSearchArea := Box(0, 0, FWidth - 1, FHeight - 1)
    else
    begin
      // Filter sets the bounds
      FSearchArea.X1 -= FontSet.MaxWidth div 2;
      FSearchArea.Y1 -= FFontSet.MaxHeight div 2;
      FSearchArea.X2 += FontSet.MaxWidth div 2;
      FSearchArea.Y2 += FFontSet.MaxHeight div 2;
    end;
  end;
end;

function TSimpleOCR._RecognizeX(Bounds: TBox; const MinCharacterCount, MaxWalk: Integer; out TextHits: Integer; out TextBounds: TBox): String;

  function CompareChar(const Character: TFontCharacter; const OffsetX, OffsetY: Integer): Integer; inline;
  var
    Hits, Any: Integer;
    First: TRGB32;
    P: TPoint;
  begin
    Result := 0;

    // Check if character is loaded
    if (Character.CharacterPointsLength = 0) then
      Exit;

    // Check if entire character is in client
    with Character.TotalBounds do
      if (X1 + OffsetX < 0) or (Y1 + OffsetY < 0) or (X2 + OffsetX >= FWidth) or (Y2 + OffsetY >= FHeight) then
        Exit;

    Hits := 0;
    Any := 0;

    First := TRGB32(FClient[Character.CharacterPoints[0].Y + OffsetY, Character.CharacterPoints[0].X + OffsetX]);
    // If binary image and not non-zero it cannot be a character point
    if FBinaryImage and (Integer(First) = 0) then
      Exit;

    // Check if not a shadow
    if (FMaxShadowValue > 0) then
    begin
      if ((First.R + First.G + First.B) div 3 < 85) and
         ((First.R < FMaxShadowValue * 2) and (First.G < FMaxShadowValue * 2) and (First.B < FMaxShadowValue * 2)) then
        Exit;
    end;

    // count hits for the character
    for P in Character.CharacterPoints do
    begin
      with TRGB32(FClient[P.Y + OffsetY, P.X + OffsetX]) do
        if Sqr(R - First.R) + Sqr(B - First.B) + Sqr(G - First.G) > FTolerance then
          Exit;

      Inc(Hits, 2);
    end;

    if (Hits < Character.CharacterPointsLength) then
      Exit; // < 50% match.

    if (FMaxShadowValue = 0) then
    begin
      // counts hits for the points that should not have equal Color to character
      // not needed for shadow-fonts
      for P in Character.BackgroundPoints do
      begin
        with TRGB32(FClient[P.Y + OffsetY, P.X + OffsetX]) do
          if Sqr(R - First.R) + Sqr(B - First.B) + Sqr(G - First.G) > FTolerance then
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
      for P in Character.ShadowPoints do
      begin
        with TRGB32(FClient[P.Y + OffsetY, P.X + OffsetX]) do
          if (R > FMaxShadowValue) or (G > FMaxShadowValue) or (B > FMaxShadowValue) then
            Exit;

        Inc(Hits);
      end;
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

function TSimpleOCR.TextToMatrix(Text: String; constref FontSet: TFontSet): TIntegerMatrix;
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

function TSimpleOCR.TextToTPA(Text: String; constref FontSet: TFontSet): TPointArray;
var
  Matrix: TIntegerMatrix;
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

function TSimpleOCR.LocateText(Matrix: TIntegerMatrix; Text: String; constref FontSet: TFontSet; Filter: TOCRFilter; out Bounds: TBox): Single;

  function SimilarColors(const Color1, Color2: TRGB32; const Tolerance: Integer): Boolean; inline;
  begin
    Result := Sqr(Color1.R - Color2.R) + Sqr(Color1.G - Color2.G) + Sqr(Color1.B - Color2.B) <= Tolerance;
  end;

var
  X, Y: Integer;
  Color, Bad, I: Integer;
  P: TPoint;
  Match: Single;
  TextMatrix: TIntegerMatrix;
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
  if not Self.Init(Matrix, FontSet, Filter, True) then
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

        // If binary image and not non-zero it cannot be a character point
        if FBinaryImage and (Integer(Color) = 0) then
          Continue;

        for I := 1 to CharacterCount do
        begin
          P.Y := Y + CharacterIndices[I].Y;
          P.X := X + CharacterIndices[I].X;

          if (P.X < 0) or (P.Y < 0) or (P.X >= FWidth) or (P.Y >= FHeight) or (not SimilarColors(TRGB32(FClient[P.Y, P.X]), TRGB32(Color), FTolerance)) then
            goto NotFound;
        end;

        Bad := 0;

        for I := 0 to OtherCount do
        begin
          P.Y := Y + OtherIndices[I].Y;
          P.X := X + OtherIndices[I].X;

          if (P.X < 0) or (P.Y < 0) or (P.X >= FWidth) or (P.Y >= FHeight) or SimilarColors(TRGB32(FClient[P.Y, P.X]), TRGB32(Color), FTolerance) then
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

function TSimpleOCR.LocateText(Matrix: TIntegerMatrix; Text: String; constref FontSet: TFontSet; Filter: TOCRFilter; MinMatch: Single): Boolean;
var
  _: TBox;
begin
  Result := LocateText(Matrix, Text, FontSet, Filter, _) >= MinMatch;
end;

function TSimpleOCR.Recognize(Matrix: TIntegerMatrix; Filter: TOCRFilter; constref FontSet: TFontSet): String;
var
  Hits: Integer;
  Bounds: TBox;
begin
  Result := '';
  if Self.Init(Matrix, FontSet, Filter, False) then
    Result := _RecognizeXY(FSearchArea, FontSet.CharacterPoints[Filter.MinCharacterMatch], $FFFFFF, Hits, Bounds);
end;

function TSimpleOCR.RecognizeStatic(Matrix: TIntegerMatrix; Filter: TOCRFilter; constref FontSet: TFontSet; MaxWalk: Integer): String;
var
  Hits: Integer;
  Bounds: TBox;
begin
  Result := '';
  if Self.Init(Matrix, FontSet, Filter, True) then
    Result := Self._RecognizeX(FSearchArea, FontSet.CharacterPoints[Filter.MinCharacterMatch], MaxWalk, Hits, Bounds);
end;

function TSimpleOCR.RecognizeLines(Matrix: TIntegerMatrix; Filter: TOCRFilter; constref FontSet: TFontSet; out TextBounds: TBoxArray): TStringArray;
var
  SearchBox, Bounds, LastBounds: TBox;
  Text: String;
  Hits: Integer;
  MinCharacterPoints: Integer;
begin
  Result := nil;
  TextBounds := nil;

  if Self.Init(Matrix, FontSet, Filter, False) then
  begin
    MinCharacterPoints := FontSet.CharacterPoints[','] + 1;

    LastBounds := Box(-1, -1, -1, -1);
    SearchBox := FSearchArea;
    while (SearchBox.Y1 + (FFontSet.MaxHeight div 2) < FSearchArea.Y2) do
    begin
      // Find something on a row that is larger than `,`
      Self._RecognizeX(SearchBox, MinCharacterPoints, $FFFFFF, Hits, Bounds);

      if (Hits > 0) then
      begin
        // OCR the row and some extra columns
        Text := Self._RecognizeXY(Box(SearchBox.X1, SearchBox.Y1, SearchBox.X2, SearchBox.Y1 + (FFontSet.MaxHeight div 2)), FontSet.CharacterPoints[Filter.MinCharacterMatch], $FFFFFF, Hits, Bounds);
        if (Text = '') or (Bounds.Y1 = LastBounds.Y1) then
          Exit;

        LastBounds := Bounds;
        Result := Result + [Text];
        TextBounds := TextBounds + [Bounds];

        // Move down to the found text Bounds.Y2 (minus a little) so we don't recognize this again
        SearchBox.Y1 := Bounds.Y2 - (FFontSet.MaxHeight div 4);
      end;

      SearchBox.Y1 += 1;
    end;
  end;
end;

function TSimpleOCR.RecognizeLines(Matrix: TIntegerMatrix; Filter: TOCRFilter; constref FontSet: TFontSet): TStringArray;
var
  _: TBoxArray;
begin
  Result := Self.RecognizeLines(Matrix, Filter, FontSet, _);
end;

end.
