unit simpleocr.engine;
{==============================================================================]
  Copyright (c) 2021, Jarl `slacky` Holta
  Project: SimpleOCR
  Project URL: https://github.com/slackydev/SimpleOCR
  License: GNU Lesser GPL (http://www.gnu.org/licenses/lgpl.html)
[==============================================================================}
{$mode objfpc}{$H+}
{$modeswitch advancedrecords}

interface

uses
  sysutils,
  simpleocr.tpa, simpleocr.types;

const
  FONTSET_START = 32;
  FONTSET_END   = 126;
  FONTSET_COUNT = FONTSET_END - FONTSET_START + 1;

type
  PFontChar = ^TFontChar;
  TFontChar = packed record
    Character: Char;
    ImageWidth, ImageHeight: Int32;
    Width, Height: Int32;
    HasShadow: Boolean;
    CharacterBounds: TBox;
    CharacterPoints: TPointArray;
    ShadowPoints: TPointArray;
    BackgroundPoints: TPointArray;
  end;
  TFontChars = array of TFontChar;

  PFontSet = ^TFontSet;
  TFontSet = packed record
    Name: String;
    Data: TFontChars;
    Count: Int32;
    SpaceWidth: Int32;
    MaxWidth: Int32;
    MaxHeight: Int32;

    procedure Load(FontPath: String; Space: Int32);
  end;

  PCompareRules = ^TCompareRules;
  TCompareRules = packed record
    Color, Tolerance: Int32; // -1 = any color
    UseShadow: Boolean;
    ShadowMaxValue: Int32;
    Threshold: Boolean;
    ThresholdAmount: Int32;
    ThresholdInvert: Boolean;
    UseShadowForColor: Boolean;
    MinCharacterMatch: Int32;
  end;

  PSimpleOCR = ^TSimpleOCR;
  TSimpleOCR = packed record
  private
    Font: TFontSet;
    Client: T2DIntegerArray;
    Width: Int32;
    Height: Int32;

    function RecognizeChar(constref Character: TFontChar; constref Offset: TPoint; constref Filter: TCompareRules): Int32;
    function RecognizeStatic(Bounds: TBox; constref Filter: TCompareRules; constref MaxWalk: Int32; out Hits: Int32): String;
    function RecognizeDynamic(Bounds: TBox; constref Filter: TCompareRules): String;
  public
    function DrawText(constref Text: String; constref FontSet: TFontSet): T2DIntegerArray;

    function LocateText(constref Matrix: T2DIntegerArray; constref Text: String; constref FontSet: TFontSet; constref Filter: TCompareRules; out Bounds: TBox): Single; overload;
    function LocateText(constref Matrix: T2DIntegerArray; constref Text: String; constref FontSet: TFontSet; constref Filter: TCompareRules; constref MinMatch: Single = 1): Boolean; overload;

    function Recognize(constref Matrix: T2DIntegerArray; Filter: TCompareRules; constref FontSet: TFontSet; constref IsStatic: Boolean; constref MaxWalk: Int32): String;
  end;

implementation

uses
  graphtype, intfgraphics, lazfileutils;

function MatrixFromPointer(Data: PRGB32; Width, Height: Int32): T2DIntegerArray;
var
  X, Y: Int32;
begin
  SetLength(Result, Height, Width);
  for Y := 0 to Height-1 do
    for X := 0 to Width-1 do
      Result[Y][X] := Data[Y*Width+X].R or Data[Y*Width+X].G shl 8 or Data[Y*Width+X].B shl 16;
end;

function FindColors(constref Matrix: T2DIntegerArray; Color, Tolerance: Int32): TPointArray;
var
  X, Y, Width, Height: Int32;
  Size, Count: Int32;
  Pixel: TRGB32;
  R, G, B: UInt8;
begin
  Result := Default(TPointArray);
  if (Length(Matrix) = 0) or (Length(Matrix[0]) = 0) then
    Exit;

  Count := 0;
  Size := 512;
  SetLength(Result, Size);

  Height := High(Matrix);
  Width := High(Matrix[0]);

  if (Tolerance = 0) then
  begin
    for Y := 0 to Height do
      for X := 0 to Width do
      begin
        if Int32(Matrix[Y][X]) = Color then
        begin
          Result[Count] := Point(X, Y);
          Inc(Count);

          if (Count = Size) then
          begin
            Size *= 2;
            SetLength(Result, Size);
          end;
        end;
      end;
  end else
  begin
    R := Color and $FF;
    G := Color shr 8 and $FF;
    B := Color shr 16 and $FF;

    for Y := 0 to Height do
      for X := 0 to Width do
      begin
        Pixel := TRGB32(Matrix[Y][X]);

        if Sqr(Pixel.R - R) + Sqr(Pixel.G - G) + Sqr(Pixel.B - B) <= Tolerance then
        begin
          Result[Count] := Point(X, Y);
          Inc(Count);

          if (Count = Size) then
          begin
            Size *= 2;
            SetLength(Result, Size);
          end;
        end;
      end;
  end;

  SetLength(Result, Count);
end;

function FindColorFromShadow(constref Matrix: T2DIntegerArray; MaxShadow: Int32 = 85): Int32;
var
  X, Y, Width, Height: Int32;
  Size, Count: Int32;
  Pixel: TRGB32;
  Colors: TIntegerArray;
begin
  Result := 0;
  if (Length(Matrix) = 0) or (Length(Matrix[0]) = 0) then
    Exit;

  Count := 0;
  Size := 512;
  SetLength(Colors, Size);

  Height := High(Matrix);
  Width := High(Matrix[0]);

  for Y := 1 to Height do
    for X := 1 to Width do
    begin
      Pixel := TRGB32(Matrix[Y][X]);

      if ((Pixel.R + Pixel.G + Pixel.B) div 3) < MaxShadow then
      begin
        Colors[Count] := Matrix[Y-1][X-1];
        Inc(Count);

        if (Count = Size) then
        begin
          Size *= 2;
          SetLength(Colors, Size);
        end;
      end;
    end;

  SetLength(Colors, Count);

  Result := Mode(Colors);
end;

procedure ThresholdAdaptive(var Matrix: T2DIntegerArray; Alpha, Beta: Byte; Invert: Boolean; C: Integer);
var
  I, Size, X, Y, W, H: Int32;
  Threshold: UInt8;
  Counter: Int64;
  Tab: array [0..256] of UInt8;
  Temp: T2DIntegerArray;
begin
  if Alpha = Beta then Exit;
  if Invert then Exch(Alpha, Beta);

  H := Length(Matrix);
  W := Length(Matrix[0]);
  Size := (W * H) - 1;

  SetLength(Temp, H, W);

  Dec(W);
  Dec(H);

  //Finding the threshold - While at it set blue-scale to the RGB mean (needed for later).
  Threshold := 0;

  Counter := 0;
  for Y := 0 to H do
    for X := 0 to W do
    begin
      with TRGB32(Matrix[Y][X]) do
        Temp[Y][X] := (B + G + R) div 3;

      Counter += Temp[Y][X];
    end;

  Threshold := (Counter div Size) + C;

  for I := 0 to (Threshold - 1) do Tab[I] := Alpha;
  for I := Threshold to 255 do Tab[I] := Beta;

  for Y := 0 to H do
    for X := 0 to W do
      Matrix[Y][X] := Tab[Temp[Y][X]];
end;

procedure TFontSet.Load(FontPath: String; Space: Int32);
var
  I: Int32;
  Image: TLazIntfImage;
  Description: TRawImageDescription;
  FontChar: TFontChar;
begin
  FontPath := IncludeTrailingPathDelimiter(ExpandFileName(FontPath));

  Self.Name := ExtractFileNameOnly(FontPath);
  Self.SpaceWidth := Space;
  Self.Count := 0;

  SetLength(Self.Data, FONTSET_COUNT);

  Description.Init_BPP32_B8G8R8_BIO_TTB(0, 0);

  Image := TLazIntfImage.Create(0, 0);
  Image.DataDescription := Description;

  for I := FONTSET_START to FONTSET_END do
  begin
    if FileExists(FontPath + IntToStr(I) + '.bmp') then
    begin
      Image.LoadFromFile(FontPath + IntToStr(I) + '.bmp');

      FontChar := Default(TFontChar);
      FontChar.Character := Chr(I);
      FontChar.ImageWidth := Image.Width;
      FontChar.ImageHeight := Image.Height;

      if FontChar.Character = #32 then
      begin
        FontChar.Width := Image.Width;
        FontChar.Height := Image.Height;
        FontChar.CharacterPoints := FindColors(MatrixFromPointer(Pointer(Image.PixelData), Image.Width, Image.Height), $000000, 0);
        FontChar.CharacterBounds := TPABounds(FontChar.CharacterPoints);
      end else
      begin
        FontChar.CharacterPoints := FindColors(MatrixFromPointer(Pointer(Image.PixelData), Image.Width, Image.Height), $FFFFFF, 0);
        FontChar.CharacterBounds := TPABounds(FontChar.CharacterPoints);
        FontChar.ShadowPoints := FindColors(MatrixFromPointer(Pointer(Image.PixelData), Image.Width, Image.Height), $0000FF, 0);
        FontChar.HasShadow := Length(FontChar.ShadowPoints) > 0;

        if FontChar.CharacterBounds.X1 > 0 then
        begin
          OffsetTPA(FontChar.CharacterPoints, -FontChar.CharacterBounds.X1,0);
          OffsetTPA(FontChar.ShadowPoints, -FontChar.CharacterBounds.X1, 0);

          SortTPAByColumn(FontChar.CharacterPoints);
        end;

        FontChar.BackgroundPoints := InvertTPA(CombineTPA(FontChar.CharacterPoints, FontChar.ShadowPoints));

        with TPABounds(CombineTPA(FontChar.CharacterPoints, FontChar.ShadowPoints)) do
        begin
          FontChar.Width  := X2-X1+1;
          FontChar.Height := Y2-Y1+1;
        end;
      end;

      if FontChar.Width > MaxWidth then
        MaxWidth := FontChar.Width;
      if FontChar.Height > MaxHeight then
        MaxHeight := FontChar.Height;

      Self.Data[Self.Count] := FontChar;
      Self.Count += 1;
    end;
  end;

  Image.Free();

  SetLength(Self.Data, Self.Count);
end;

function TSimpleOCR.DrawText(constref Text: String; constref FontSet: TFontSet): T2DIntegerArray;
var
  I, X, Y: Int32;
  P: TPoint;
  FontChar: TFontChar;
  FontChars: TFontChars;
  Bounds: TBox;
begin
  Bounds.X1 := 0;
  Bounds.X2 := 0;
  Bounds.Y1 := $FFFFFF;
  Bounds.Y2 := 0;

  SetLength(FontChars, Length(Text));

  for I := 1 to Length(Text) do
  begin
    FontChar := FontSet.Data[Ord(Text[I]) - FONTSET_START];
    FontChars[I-1] := FontChar;

    if (FontChar.Character <> #32) then
    begin
      if (FontChar.CharacterBounds.Y1 < Bounds.Y1) then
        Bounds.Y1 := FontChar.CharacterBounds.Y1;
      if (FontChar.CharacterBounds.Y2 > Bounds.Y2) then
        Bounds.Y2 := FontChar.CharacterBounds.Y2;
    end;

    Bounds.X2 += FontChar.ImageWidth;
  end;

  SetLength(Result, Bounds.Y2-Bounds.Y1 + 1, Bounds.X2);

  for I := 0 to High(FontChars) do
  begin
    FontChar := FontChars[I];

    if FontChar.Character = #32 then
    begin
      for X := Bounds.X1 to (Bounds.X1 + FontChar.ImageWidth) - 1 do
       for Y := 0 to Bounds.Y2 - Bounds.Y1 do
          Result[Y, X] := $00FF00;
    end else
      for P in FontChar.CharacterPoints do
        Result[P.Y - Bounds.Y1, Bounds.X1 + P.X + FontChar.CharacterBounds.X1] := $0000FF;

    Bounds.X1 += FontChar.ImageWidth;
  end;
end;

function TSimpleOCR.LocateText(constref Matrix: T2DIntegerArray; constref Text: String; constref FontSet: TFontSet; constref Filter: TCompareRules; out Bounds: TBox): Single;
var
  X, Y, W, H, Tolerance: Int32;
  Pixel: TRGB32;
  R, G, B: UInt8;
  Color, Bad, dX, dY, I: Int32;
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

  TextMatrix := Self.DrawText(Text, FontSet);
  TextHeight := Length(TextMatrix);
  if (TextHeight = 0) then
    Exit;
  TextWidth := Length(TextMatrix[0]);
  if (TextWidth = 0) then
    Exit;

  // Preprocess
  H := High(Matrix);
  W := High(Matrix[0]);

  if (Filter.Color > -1) then
  begin
    if (Filter.Tolerance = 0) then
    begin
      for Y := 0 to H do
        for X := 0 to W do
        begin
          if Matrix[Y][X] = Filter.Color then
            Matrix[Y][X] := 1
          else
            Matrix[Y][X] := -1;
        end;
    end else
    begin
      Tolerance := Sqr(Filter.Tolerance);

      B := Filter.Color and $FF;
      G := Filter.Color shr 8 and $FF;
      R := Filter.Color shr 16 and $FF;

      for Y := 0 to H do
        for X := 0 to W do
        begin
          Pixel := TRGB32(Matrix[Y][X]);

          if Sqr(Pixel.R - R) + Sqr(Pixel.G - G) + Sqr(Pixel.B - B) <= Tolerance then
            Matrix[Y][X] := 1
          else
            Matrix[Y][X] := -1;
        end;
    end;
  end;

  // Matching
  SetLength(CharacterIndices, TextWidth * TextHeight);
  SetLength(OtherIndices, TextWidth * TextHeight);

  TextHeight -= 1;
  TextWidth -= 1;

  CharacterCount := 0;
  OtherCount := 0;

  for Y := 0 to TextHeight do
    for X := 0 to TextWidth do
      if TextMatrix[Y][X] = $0000FF then
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
    dX := Length(Matrix[0]) - (TextWidth+1);
    dY := Length(Matrix) - (TextHeight+1);

    for Y := 0 to dY do
      for X := 0 to dX do
      begin
        P.Y := Y + CharacterIndices[0].Y;
        P.X := X + CharacterIndices[0].X;

        Color := Matrix[P.Y][P.X];
        if (Color = -1) then
          Continue;

        for I := 1 to CharacterCount do
        begin
          P.Y := Y + CharacterIndices[I].Y;
          P.X := X + CharacterIndices[I].X;

          if (Matrix[P.Y][P.X] <> Color) then
            goto NotFound;
        end;

        Bad := 0;

        for I := 0 to OtherCount do
        begin
          P.Y := Y + OtherIndices[I].Y;
          P.X := X + OtherIndices[I].X;

          if (Matrix[P.Y][P.X] = Color) then
            Inc(Bad);
        end;

        Match := 1 - (Bad / OtherCount);

        if Match > Result then
        begin
          Result := Match;

          Bounds.X1 := X;
          Bounds.Y1 := Y;
          Bounds.X2 := X + TextWidth;
          Bounds.Y2 := Y + TextHeight;

          if Result = 1 then
            Exit;
        end;

        NotFound:
      end;
  end;
end;

function TSimpleOCR.LocateText(constref Matrix: T2DIntegerArray; constref Text: String; constref FontSet: TFontSet; constref Filter: TCompareRules; constref MinMatch: Single): Boolean;
var
  B: TBox;
begin
  Result := Self.LocateText(Matrix, Text, FontSet, Filter, B) >= MinMatch;
end;

function TSimpleOCR.RecognizeChar(constref Character: TFontChar; constref Offset: TPoint; constref Filter: TCompareRules): Int32;
var
  I, Hits, Any, MaxShadow: Int32;
  First, Color: TRGB32;
  P: TPoint;
begin
  Hits := 0;
  Any := 0;

  if (Filter.Color = -1) then
  begin
    P := Character.CharacterPoints[0];
    P.X += Offset.X;
    P.Y += Offset.Y;
    if (P.X >= Self.Width) or (P.Y >= Self.Height) or (P.X < 0) or (P.Y < 0) then
      Exit(-1);

    First := TRGB32(Client[P.Y, P.X]);
    if Filter.UseShadow then
    begin
      MaxShadow := 2 * Filter.ShadowMaxValue;
      if ((First.R + First.G + First.B) div 3 < 85) and ((First.R < MaxShadow) and (First.G < MaxShadow) and (First.B < MaxShadow)) then
        Exit(-1);
    end;
  end else
    First := TRGB32(Filter.Color);

  //count hits for the character
  for I := 0 to High(Character.CharacterPoints) do
  begin
    P := Character.CharacterPoints[I];
    P.X += Offset.X;
    P.Y += Offset.Y;
    if (P.X >= Self.Width) or (P.Y >= Self.Height) or (P.X < 0) or (P.Y < 0) then
      Exit(-1);

    Color := TRGB32(Client[P.Y, P.X]);
    if Sqr(Color.R - First.R) + Sqr(Color.B - First.B) + Sqr(Color.G - First.G) > Filter.Tolerance then
      Exit(-1)
    else
      Inc(Hits, 2);
  end;

  if Hits < Length(Character.CharacterPoints) then
    Exit(-1); // < 50% match.

  if not Filter.UseShadow then
  begin
    // counts hits for the points that should not have equal Color to character
    // not needed for shadow-fonts
    for I := 0 to High(Character.BackgroundPoints) do
    begin
      P := Character.BackgroundPoints[I];
      P.X += Offset.X;
      P.Y += Offset.Y;
      if (P.X >= Self.Width) or (P.Y >= Self.Height) or (P.X < 0) or (P.Y < 0) then
        Exit(-1);

      Color := TRGB32(Client[P.Y, P.X]);
      if Sqr(Color.R - First.R) + Sqr(Color.B - First.B) + Sqr(Color.G - First.G) > Filter.Tolerance then
        Inc(Any)
      else
        Dec(Hits);
    end;

    if (Length(Character.BackgroundPoints) > 0) and (Any <= (Length(Character.BackgroundPoints) div 2)) then
      Exit(-1) // <=50% match.
    else
      Inc(Hits, Any);
  end else
  begin
    // count hits for font-shadow
    for I := 0 to High(Character.ShadowPoints) do
    begin
      P := Character.ShadowPoints[I];
      P.X += Offset.X;
      P.Y += Offset.Y;
      if (P.X >= Self.Width) or (P.Y >= Self.Height) or (P.X < 0) or (P.Y < 0) then
        Exit(-1);

      Color := TRGB32(Client[P.Y, P.X]);

      if not ((Color.R < Filter.ShadowMaxValue) and (Color.G < Filter.ShadowMaxValue) and (Color.B < Filter.ShadowMaxValue)) then
        Exit(-1)
      else
        Inc(Hits);
    end;
  end;

  if (Hits < Filter.MinCharacterMatch) then
    Exit(-1);

  Result := Hits;
end;

function TSimpleOCR.RecognizeStatic(Bounds: TBox; constref Filter: TCompareRules; constref MaxWalk: Int32; out Hits: Int32): String;
var
  I: Int32;
  Space: Int32;
  CharacterHits: Int32;
  BestCharaterHits: Int32;
  BestCharacter: Int32;
begin
  Result := '';

  Hits := 0;
  Space := 0;

  while (Bounds.X1 < Bounds.X2) and (Space < MaxWalk) do
  begin
    BestCharacter := -1;
    BestCharaterHits := 0;

    for I := 0 to Self.Font.Count - 1 do
    begin
      CharacterHits := Self.RecognizeChar(Self.Font.Data[I], Point(Bounds.X1, Bounds.Y1), Filter);
      if (CharacterHits > BestCharaterHits) then
      begin
        BestCharaterHits := CharacterHits;
        BestCharacter := I;
      end;
    end;

    if (BestCharacter > -1) then
    begin
      if (Result <> '') and (Space >= Self.Font.SpaceWidth) then
        Result += #32;
      Space := 0;

      Hits += BestCharaterHits;
      Result += Self.Font.Data[BestCharacter].Character;

      Bounds.X1 += Self.Font.Data[BestCharacter].Width;
    end else
    begin
      Space += 1;

      Bounds.X1 += 1;
    end;
  end;
end;

function TSimpleOCR.RecognizeDynamic(Bounds: TBox; constref Filter: TCompareRules): String;
var
  BestTextHits, TextHits: Int32;
  Text: String;
begin
  Result := '';

  BestTextHits := 0;

  while Bounds.Y1 < Bounds.Y2 do
  begin
    Text := Self.RecognizeStatic(Bounds, Filter, High(Int32), TextHits);

    if TextHits > BestTextHits then
    begin
      BestTextHits := TextHits;

      Result := Text;
    end;

    Bounds.Y1 += 1;
  end;
end;

function TSimpleOCR.Recognize(constref Matrix: T2DIntegerArray; Filter: TCompareRules; constref FontSet: TFontSet; constref IsStatic: Boolean; constref MaxWalk: Int32): String;
var
  Bounds: TBox;
  Hits: Int32;
begin
  Result := '';

  Self.Font := FontSet;
  Self.Client := Matrix;
  if (Length(Self.Client) = 0) or (Length(Client[0]) = 0) then
    Exit;

  Self.Width := Length(Client[0]);
  Self.Height := Length(Client);

  if Filter.Threshold then
  begin
    Filter.Color := 255;

    ThresholdAdaptive(Self.Client, 0, Filter.Color, Filter.ThresholdInvert, Filter.ThresholdAmount);
  end;

  if Filter.UseShadowForColor then
    Filter.Color := FindColorFromShadow(Self.Client);

  if (Filter.Tolerance > 0) then
    Filter.Tolerance := Sqr(Filter.Tolerance);

  Bounds.X1 := 0;
  Bounds.Y1 := 0;
  Bounds.X2 := Self.Width - 1;
  Bounds.Y2 := Self.Height - 1;

  if IsStatic then
    Result := Self.RecognizeStatic(Bounds, Filter, MaxWalk, Hits)
  else
  begin
    // Speed by finding bounds
    if (Filter.Color > -1) then
    begin
      Bounds := TPABounds(FindColors(Self.Client, Filter.Color, Filter.Tolerance));
      Bounds.X1 -= FontSet.MaxWidth  div 2;
      Bounds.Y1 -= FontSet.MaxHeight div 2;
      Bounds.X2 += FontSet.MaxWidth  div 2;
      Bounds.Y2 += FontSet.MaxHeight div 2;
    end;

    Result := Self.RecognizeDynamic(Bounds, Filter);
  end;
end;

end.
