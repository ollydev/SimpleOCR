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
  Classes, SysUtils,
  simpleocr.types, simpleocr.filters;

const
  ALPHA_NUMERIC_SYM = ['a'..'z', 'A'..'Z', '0'..'9','%','&','#','$','[',']','{','}','@','!','?'];


type
  TFontGlyph = record
    ImageWidth, ImageHeight: Integer;
    Width, Height: Integer;
    CharacterBounds: TBox;
    CharacterPoints: TPointArray;
    ShadowPoints: TPointArray;
    BackgroundPoints: TPointArray;
    TotalBounds: TBox;
    Character: Char;
  end;
  TFontGlyphArray = array of TFontGlyph;

  TFontSet = record
  public
    Name: String;
    SpaceWidth: Integer;
    Glyphs: TFontGlyphArray;
    MaxGlyphWidth: Integer;
    MaxGlyphHeight: Integer;

    function TextToMatrix(Text: String): TIntegerMatrix;
    function TextToTPA(Text: String): TPointArray;

    function GlyphFromChar(const C: Char): Integer;

    class function Create(FontPath: String; Space: Integer = 4): TFontSet; static;
  end;

  TOCRMatch = record
    Text: String;
    Bounds: TBox;
    Hits: Integer;
  end;
  TOCRMatchArray = array of TOCRMatch;

  TSimpleOCR = record
  private
    FClient: TColorRGBAMatrix;
    FMatches: TOCRMatchArray;
    FOffset: TPoint; // apply a offset to TOCRMatch

    // "Internal data"
    FFontSet: ^TFontSet;
    FWidth: Integer;
    FHeight: Integer;
    FSearchArea: TBox;
    FBinaryImage: Boolean;
    FMaxShadowValue: Integer;
    FTolerance: Integer;

    function Init(constref FontSet: TFontSet; Filter: TOCRFilter; Static: Boolean): Boolean;

    function getGlpyhIndices(Blacklist: String): TIntegerArray;
    function addMatch(Match: TOCRMatch): String;

    function _RecognizeX(Bounds: TBox; GlpyhIndices: TIntegerArray; MaxWalk: Integer = 20): TOCRMatch;
    function _RecognizeXY(Bounds: TBox; GlpyhIndices: TIntegerArray; MaxWalk: Integer = 20): TOCRMatch;
  public
    class function InternalDataSize: SizeUInt; static;

    function LocateText(Text: String; constref FontSet: TFontSet; Filter: TOCRFilter): Single;

    function Recognize(Filter: TOCRFilter; constref FontSet: TFontSet): String;
    function RecognizeStatic(Filter: TOCRFilter; constref FontSet: TFontSet): String;
    function RecognizeLines(Filter: TOCRFilter; constref FontSet: TFontSet): TStringArray;

    property Client: TColorRGBAMatrix read FClient write FClient;
    property Matches: TOCRMatchArray read FMatches;
  end;

implementation

uses
  GraphType, IntfGraphics, Graphics, Math;

function ContainsAlphaNumSym(const text: string): Boolean; inline;
var i: Int32;
begin
  Result := False;
  for i:=1 to Length(text) do
    if Text[i] in ALPHA_NUMERIC_SYM then
      Exit(True);
end;

function TFontSet.TextToMatrix(Text: String): TIntegerMatrix;
var
  I, J, X, Y: Integer;
  Bounds: TBox;
  GylphIndex: Integer;
begin
  Bounds.X1 := 0;
  Bounds.X2 := 0;
  Bounds.Y1 := $FFFFFF;
  Bounds.Y2 := 0;

  for I := 1 to Length(Text) do
  begin
    GylphIndex := GlyphFromChar(Text[I]);
    if (GylphIndex = -1) then
      Continue;

    with Glyphs[GylphIndex] do
    begin
      if (Text[I] <> ' ') then
      begin
        if (CharacterBounds.Y1 < Bounds.Y1) then
          Bounds.Y1 := CharacterBounds.Y1;
        if (CharacterBounds.Y2 > Bounds.Y2) then
          Bounds.Y2 := CharacterBounds.Y2;
      end;

      Bounds.X2 += ImageWidth;
    end;
  end;

  SetLength(Result, Max(0, (Bounds.Y2 - Bounds.Y1) + 1), Bounds.X2);
  if (Length(Result) = 0) or (Length(Result[0]) = 0) then
    Exit;

  for I := 1 to Length(Text) do
  begin
    GylphIndex := GlyphFromChar(Text[I]);
    if (GylphIndex = -1) then
      Continue;

    with Glyphs[GylphIndex] do
    begin
      if (Text[I] = ' ') then
      begin
        for X := Bounds.X1 to (Bounds.X1 + ImageWidth) - 1 do
          for Y := 0 to Bounds.Y2 - Bounds.Y1 do
            Result[Y, X] := $00FF00;
      end else
      begin
        for J := 0 to High(CharacterPoints) do
          Result[CharacterPoints[J].Y - Bounds.Y1, Bounds.X1 + CharacterPoints[J].X + CharacterBounds.X1] := $0000FF;
      end;

      Bounds.X1 += ImageWidth;
    end;
  end;
end;

function TFontSet.TextToTPA(Text: String): TPointArray;
var
  Matrix: TIntegerMatrix;
  X, Y, Count: Integer;
begin
  Result := nil;

  Matrix := TextToMatrix(Text);
  if (Length(Matrix) > 0) and (Length(Matrix[0]) > 0) then
  begin
    SetLength(Result, Length(Matrix[0]) * Length(Matrix));

    Count := 0;
    for Y := 0 to High(Matrix) do
      for X := 0 to High(Matrix[0]) do
        if (Matrix[Y, X] = $0000FF) then
        begin
          Result[Count].X := X;
          Result[Count].Y := Y;
          Inc(Count);
        end;

    SetLength(Result, Count);
  end;
end;

function TFontSet.GlyphFromChar(const C: Char): Integer;
var
  I: Integer;
begin
  for I := 0 to High(Glyphs) do
    if (Glyphs[I].Character = C) then
      Exit(I);

  Result := -1;
end;

class function TFontSet.Create(FontPath: String; Space: Integer): TFontSet;
var
  I: Integer;
  Image: TSimpleImage;
  Glyph: TFontGlyph;
begin
  FontPath := IncludeTrailingPathDelimiter(ExpandFileName(FontPath));
  if (not DirectoryExists(FontPath)) then
    raise Exception.Create('TFontSet.Load: Font does not exist "' + FontPath + '"');

  Result := Default(TFontSet);
  Result.Name := ExtractFileName(ExcludeTrailingPathDelimiter(FontPath));
  Result.SpaceWidth := Space;

  for I := 32 to 126 do
  begin
    if FileExists(FontPath + IntToStr(I) + '.bmp') then
      Image := TSimpleImage.Create(FontPath + IntToStr(I) + '.bmp')
    else
    if FileExists(FontPath + IntToStr(I) + '.png') then
      Image := TSimpleImage.Create(FontPath + IntToStr(I) + '.png')
    else
      Image := nil;

    if (Image <> nil) then
    try
      Glyph := Default(TFontGlyph);
      Glyph.ImageWidth := Image.Width;
      Glyph.ImageHeight := Image.Height;
      Glyph.Character := Chr(I);

      if (Glyph.Character = ' ') then
      begin
        Glyph.Width := Image.Width;
        Glyph.Height := Image.Height;
      end else
      begin
        Glyph.CharacterPoints := Image.FindColor($FFFFFF);
        Glyph.CharacterBounds := TPABounds(Glyph.CharacterPoints);
        Glyph.ShadowPoints := Image.FindColor($0000FF);

        if (Glyph.CharacterBounds.X1 > 0) then
        begin
          OffsetTPA(Glyph.CharacterPoints, -Glyph.CharacterBounds.X1, 0);
          OffsetTPA(Glyph.ShadowPoints, -Glyph.CharacterBounds.X1, 0);
        end;

        Glyph.BackgroundPoints := InvertTPA(Glyph.CharacterPoints + Glyph.ShadowPoints);

        with TPABounds(Glyph.CharacterPoints + Glyph.ShadowPoints) do
        begin
          Glyph.Width  := X2-X1+1;
          Glyph.Height := Y2-Y1+1;
        end;
      end;

      if (Glyph.Width  > Result.MaxGlyphWidth)  then Result.MaxGlyphWidth  := Glyph.Width;
      if (Glyph.Height > Result.MaxGlyphHeight) then Result.MaxGlyphHeight := Glyph.Height;

      Glyph.TotalBounds := TPABounds(Glyph.CharacterPoints + Glyph.ShadowPoints + Glyph.BackgroundPoints);

      Result.Glyphs := Result.Glyphs + [Glyph];
    finally
      Image.Free();
    end;
  end;
end;

function TSimpleOCR.Init(constref FontSet: TFontSet; Filter: TOCRFilter; Static: Boolean): Boolean;
begin
  FHeight := Length(FClient);
  if FHeight > 0 then
    FWidth := Length(FClient[0]);
  Result := (FHeight > 0) and (FWidth > 0);

  if Result then
  begin
    FMatches := [];
    FClient := TColorRGBAMatrix(FClient);
    FFontSet := @FontSet;
    FBinaryImage := Filter.FilterType <> EOCRFilterType.ANY_COLOR;
    FMaxShadowValue := Filter.AnyColorFilter.MaxShadowValue;
    FTolerance := Sqr(Filter.AnyColorFilter.Tolerance);

    case Filter.FilterType of
      EOCRFilterType.COLOR, EOCRFilterType.INVERT_COLOR:
        Result := ApplyColorFilter(Filter, FClient, FSearchArea);

      EOCRFilterType.THRESHOLD:
        Result := ApplyThresholdFilter(Filter, FClient, FSearchArea);

      EOCRFilterType.SHADOW:
        Result := ApplyShadowFilter(Filter, FClient, FSearchArea);
    end;

    if Static then
    begin
      FSearchArea.X1 := 0;
      FSearchArea.Y1 := 0;
      FSearchArea.X2 := FWidth - 1;
      FSearchArea.Y2 := FHeight - 1;
    end else
    begin
      // Filter sets the bounds, but expand a little
      FSearchArea.X1 -= FFontSet^.MaxGlyphWidth div 2;
      FSearchArea.Y1 -= FFontSet^.MaxGlyphHeight div 2;
      FSearchArea.X2 += FFontSet^.MaxGlyphWidth div 2;
      FSearchArea.Y2 += FFontSet^.MaxGlyphHeight div 2;
    end;
  end;
end;

function TSimpleOCR.getGlpyhIndices(Blacklist: String): TIntegerArray;
var
  Count, I: Integer;
begin
  SetLength(Result, Length(FFontSet^.Glyphs));
  Count := 0;
  for I := 0 to High(FFontSet^.Glyphs) do
    if (FFontSet^.Glyphs[I].Character <> ' ') and (Pos(FFontSet^.Glyphs[I].Character, Blacklist) = 0) then
    begin
      Result[Count] := I;
      Inc(Count);
    end;
  SetLength(Result, Count);
end;

function TSimpleOCR.addMatch(Match: TOCRMatch): String;
begin
  Match.Bounds.X1 += FOffset.X;
  Match.Bounds.Y1 += FOffset.Y;

  FMatches := FMatches + [Match];

  Result := Match.Text;
end;

function TSimpleOCR._RecognizeX(Bounds: TBox; GlpyhIndices: TIntegerArray; MaxWalk: Integer): TOCRMatch;

  function CompareChar(const Index: Integer; const OffsetX, OffsetY: Integer): Integer; inline;
  var
    First: TColorRGBA;
    P: TPoint;
    Hits: Integer;
  begin
    Result := 0;
    Hits := 0;

    with FFontSet^.Glyphs[Index] do
    begin
      // Check if entire character is in client
      if (TotalBounds.X1 + OffsetX < 0) or
         (TotalBounds.Y1 + OffsetY < 0) or
         (TotalBounds.X2 + OffsetX >= FWidth) or
         (TotalBounds.Y2 + OffsetY >= FHeight) then
        Exit;

      // if FClient is binary it's a simple check
      if FBinaryImage then
      begin
        // Every character point must match...
        for P in CharacterPoints do
          if (FClient[P.Y + OffsetY, P.X + OffsetX].AsInteger <> $FFFFFF) then
            Exit;

        // counts hits for the points that shouldn't be a character point
        // if > 50% it's bad and cannot be a match.
        if (High(BackgroundPoints) > 0) then
        begin
          for P in BackgroundPoints do
            if (FClient[P.Y + OffsetY, P.X + OffsetX].AsInteger = 0) then
              Hits += 1;

          if (Hits < High(BackgroundPoints) div 2) then
            Exit;
        end;

        Result := Length(CharacterPoints) + Hits;
      end else
      begin
        // Use first pixel to compare against
        First := FClient[CharacterPoints[0].Y + OffsetY, CharacterPoints[0].X + OffsetX];

        // Check if not a shadow
        if (FMaxShadowValue > 0) and (Length(ShadowPoints) > 0) then
        begin
          // if first pix is a dark'ish color its a non starter
          if IsShadow(First, FMaxShadowValue * 2) then
            Exit;
          // if first shadow isn't one it's not a match
          if not IsShadow(FClient[ShadowPoints[0].Y + OffsetY, ShadowPoints[0].X + OffsetX], FMaxShadowValue) then
            Exit;
        end;

        // count hits for the character
        for P in CharacterPoints do
          if not SimilarColors(FClient[P.Y + OffsetY, P.X + OffsetX], First, FTolerance) then
            Exit;

        // count hits for shadow
        for P in ShadowPoints do
          if not IsShadow(FClient[P.Y + OffsetY, P.X + OffsetX], FMaxShadowValue) then
            Exit;

        Result := Length(CharacterPoints) + Length(ShadowPoints);
      end;
    end;
  end;

var
  Space, Hits, BestHits: Integer;
  I: Integer;
  BestIndex: Integer;
begin
  Result := Default(TOCRMatch);
  Result.Bounds.X1 := Integer.MaxValue;
  Result.Bounds.Y1 := Integer.MaxValue;

  Space := 0;

  while (Bounds.X1 < Bounds.X2) and (Space < MaxWalk) do
  begin
    BestHits := 0;
    BestIndex := -1;

    for I := 0 to High(GlpyhIndices) do
    begin
      Hits := CompareChar(GlpyhIndices[I], Bounds.X1, Bounds.Y1);
      if (Hits > BestHits) then
      begin
        BestHits := Hits;
        BestIndex := GlpyhIndices[I];
      end;
    end;

    if (BestHits > 0) then
    begin
      if (Result.Text <> '') and (Space >= FFontSet^.SpaceWidth) then
        Result.Text += ' ';

      Space := 0;

      Result.Bounds.X1 := Min(Result.Bounds.X1, Bounds.X1 + FFontSet^.Glyphs[BestIndex].CharacterBounds.X1);
      Result.Bounds.Y1 := Min(Result.Bounds.Y1, Bounds.Y1 + FFontSet^.Glyphs[BestIndex].CharacterBounds.Y1);
      Result.Bounds.X2 := Max(Result.Bounds.X2, Bounds.X1 + FFontSet^.Glyphs[BestIndex].CharacterBounds.X2);
      Result.Bounds.Y2 := Max(Result.Bounds.Y2, Bounds.Y1 + FFontSet^.Glyphs[BestIndex].CharacterBounds.Y2);

      Result.Hits += BestHits;
      Result.Text += FFontSet^.Glyphs[BestIndex].Character;

      Bounds.X1 += FFontSet^.Glyphs[BestIndex].Width;
    end else
    begin
      Space += 1;
      Bounds.X1 += 1;
    end;
  end;
end;

function TSimpleOCR._RecognizeXY(Bounds: TBox; GlpyhIndices: TIntegerArray; MaxWalk: Integer): TOCRMatch;
var
  Pass: TOCRMatch;
begin
  Result := Default(TOCRMatch);

  while (Bounds.Y1 < Bounds.Y2) do
  begin
    Pass := Self._RecognizeX(Bounds, GlpyhIndices, MaxWalk);
    if (Pass.Hits > Result.Hits) then
      Result := Pass;

    Bounds.Y1 += 1;
  end;
end;

class function TSimpleOCR.InternalDataSize: SizeUInt;
begin
  Result := SizeOf(TSimpleOCR);

  Dec(Result, SizeOf(Pointer)); // FClient
  Dec(Result, SizeOf(Pointer)); // FMatches
  Dec(Result, SizeOf(TPoint));  // FOffset
end;

function TSimpleOCR.LocateText(Text: String; constref FontSet: TFontSet; Filter: TOCRFilter): Single;
var
  X, Y: Integer;
  Color, Bad, I: Integer;
  P: TPoint;
  Match: Single;
  TextMatrix: TIntegerMatrix;
  TextWidth, TextHeight: Integer;
  CharacterIndices, OtherIndices: TPointArray;
  CharacterCount, OtherCount: Integer;
  BestMatch: TOCRMatch;
label
  NotFound, Finished;
begin
  Result := 0;

  TextMatrix := FontSet.TextToMatrix(Text);
  if (Length(TextMatrix) = 0) or (Length(TextMatrix[0]) = 0) then
    Exit;
  TextHeight := Length(TextMatrix);
  TextWidth := Length(TextMatrix[0]);
  if not Self.Init(FontSet, Filter, True) then
    Exit;

  SetLength(CharacterIndices, TextWidth * TextHeight);
  SetLength(OtherIndices, TextWidth * TextHeight);

  CharacterCount := 0;
  OtherCount := 0;

  Dec(TextWidth);
  Dec(TextHeight);
  for Y := 0 to TextHeight do
    for X := 0 to TextWidth do
      if (TextMatrix[Y, X] = 255) then
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
    FSearchArea.X2 -= TextWidth;
    FSearchArea.Y2 -= TextHeight;

    for Y := FSearchArea.Y1 to FSearchArea.Y2 do
      for X := FSearchArea.X1 to FSearchArea.X2 do
      begin
        P.Y := Y + CharacterIndices[0].Y;
        P.X := X + CharacterIndices[0].X;

        if (P.X < 0) or (P.Y < 0) or (P.X >= FWidth) or (P.Y >= FHeight) then
          Continue;
        Color := FClient[P.Y, P.X].AsInteger;

        // If binary image and not non-zero it cannot be a character point
        if FBinaryImage and (Integer(Color) = 0) then
          Continue;

        for I := 1 to CharacterCount do
        begin
          P.Y := Y + CharacterIndices[I].Y;
          P.X := X + CharacterIndices[I].X;

          if (P.X < 0) or (P.Y < 0) or (P.X >= FWidth) or (P.Y >= FHeight) or (not SimilarColors(Client[P.Y, P.X], TColorRGBA(Color), FTolerance)) then
            goto NotFound;
        end;

        Bad := 0;

        for I := 0 to OtherCount do
        begin
          P.Y := Y + OtherIndices[I].Y;
          P.X := X + OtherIndices[I].X;

          if (P.X < 0) or (P.Y < 0) or (P.X >= FWidth) or (P.Y >= FHeight) or SimilarColors(FClient[P.Y, P.X], TColorRGBA(Color), FTolerance) then
            Inc(Bad);
        end;

        Match := 1 - (Bad / OtherCount);

        if (Match > Result) then
        begin
          Result := Match;

          BestMatch.Bounds.X1 := X;
          BestMatch.Bounds.Y1 := Y;
          BestMatch.Bounds.X2 := X + TextWidth;
          BestMatch.Bounds.Y2 := Y + TextHeight;

          if (Result = 1) then
            goto Finished;
        end;

        NotFound:
      end;
  end;
  Finished:

  BestMatch.Hits := Round(Result * 100);
  BestMatch.Text := Text;
  BestMatch.Bounds.X2 += 1;
  BestMatch.Bounds.Y2 += 1;

  addMatch(BestMatch);
end;

function TSimpleOCR.Recognize(Filter: TOCRFilter; constref FontSet: TFontSet): String;
var
  Match: TOCRMatch;
begin
  Result := '';

  if Self.Init(FontSet, Filter, False) then
  begin
    Match := _RecognizeXY(FSearchArea, getGlpyhIndices(Filter.Blacklist));

    Result := addMatch(Match);
  end;
end;

function TSimpleOCR.RecognizeStatic(Filter: TOCRFilter; constref FontSet: TFontSet): String;
var
  Match: TOCRMatch;
begin
  Result := '';

  if Self.Init(FontSet, Filter, True) then
  begin
    Match := Self._RecognizeX(FSearchArea, getGlpyhIndices(Filter.Blacklist));

    Result := addMatch(Match);
  end;
end;

function TSimpleOCR.RecognizeLines(Filter: TOCRFilter; constref FontSet: TFontSet): TStringArray;
var
  Indices: TIntegerArray;
  IndicesNoSmall: TIntegerArray;

  function RecognizeSomething(B: TBox; out Match: TOCRMatch): Boolean;
  begin
    Result := False;

    // Find something on a row that isn't a small character
    Match := Self._RecognizeX(B, IndicesNoSmall, $FFFFFF);
    if (Match.Hits > 0) then
    begin
      // OCR the row and some extra rows
      B.Y2 := B.Y1 + (FFontSet^.MaxGlyphHeight div 2);
      Match := Self._RecognizeXY(B, Indices, $FFFFFF);

      // Ensure that actual text was extracted, not just a symbol mess of short or small character symbols.
      if ContainsAlphaNumSym(Match.Text) then
        Result := True;
    end;
  end;

var
  SearchBox: TBox;
  Match: TOCRMatch;
  I: Integer;
begin
  Result := [];

  Indices := getGlpyhIndices(Filter.Blacklist);
  IndicesNoSmall := getGlpyhIndices(Filter.Blacklist + '~^;`_-:.,'+#39+#34);

  if Self.Init(FontSet, Filter, False) then
  begin
    SearchBox := FSearchArea;

    while (SearchBox.Y1 + (FFontSet^.MaxGlyphHeight div 2) < FSearchArea.Y2) do
    begin
      if RecognizeSomething(SearchBox, Match) then
      begin
        addMatch(Match);

        // Now we can confidently skip this search line by a jump, but we dont skip fully in case of close/overlapping text
        // So we divide the texts max glyph height by 4, and subtract that from the lower end of the found bounds.
        SearchBox.Y1 := Max(SearchBox.Y1, Match.Bounds.Y2 - (FFontSet^.MaxGlyphHeight div 4));
      end;

      SearchBox.Y1 += 1;
    end;

    SetLength(Result, Length(FMatches));
    for I := 0 to High(FMatches) do
      Result[I] := FMatches[I].Text;
  end;
end;

end.
