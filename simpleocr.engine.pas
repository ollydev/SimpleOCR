unit simpleocr.engine;
{==============================================================================]
  Copyright (c) 2019, Jarl `slacky` Holta
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

type
  PFontChar = ^TFontChar;
  TFontChar = packed record
    Character: AnsiChar;
    Width, Height: Int32;
    Loaded, HasShadow: Boolean;
    CharacterPoints: TPointArray;
    ShadowPoints: TPointArray;
    BackgroundPoints: TPointArray;
  end;
  TFontChars = array of TFontChar;

  PFontSet = ^TFontSet;
  TFontSet = packed record
    Name: String;
    Data: TFontChars;
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
    MinCharacterMatch: Int32;
  end;

  PSimpleOCR = ^TSimpleOCR;
  TSimpleOCR = packed record
    Font: TFontSet;
    Client: T2DIntegerArray;
    Width: Int32;
    Height: Int32;

    function CompareChar(constref Character: TFontChar; constref Offset: TPoint; constref Info: TCompareRules): Int32;
    function Recognize(constref AClient: T2DIntegerArray; Filter: TCompareRules; constref FontSet: TFontSet; IsStatic: Boolean; MaxWalk: Int32): String;
  end;

implementation

uses
  graphtype, intfgraphics, lazfileutils, math;

function FindColors(constref Matrix: T2DIntegerArray; Color: TRGB32; Tolerance: Int32): TPointArray;
var
  X, Y, Width, Height: Int32;
  Size, Count: Int32;
  Test: TRGB32;
begin
  Result := Default(TPointArray);

  Height := High(Matrix);
  if (Height < 0) then
    Exit;
  Width := High(Matrix[0]);
  if (Width < 0) then
    Exit;

  Count := 0;
  Size := 1024;
  SetLength(Result, Size);

  for Y := 0 to Height do
    for X := 0 to Width do
    begin
      Test := TRGB32(Matrix[Y][X]);

      if Sqr(Test.R - Color.R) + Sqr(Test.B - Color.B) + Sqr(Test.G - Color.G) <= Tolerance then
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

  SetLength(Result, Count);
end;

function FindColor(Data: PRGB32; Color: Int32; Width, Height: Int32): TPointArray;
var
  x,y,idx,c: Int32;
  Target: TRGB32;
begin
  Target.R := Color and $FF;
  Target.G := Color shr 8 and $FF;
  Target.B := Color shr 16 and $FF;
  Target.A := 0;

  c := 0;
  idx := 0;
  SetLength(Result, Width * Height);
  for y := 0 to Height - 1 do
    for x := 0 to Width - 1 do
    begin
      if (Data[idx].R = Target.R) and (Data[idx].G = Target.G) and (Data[idx].B = Target.B) then
      begin
        Result[c].x := x;
        Result[c].y := y;
        Inc(c);
      end;
      Inc(idx);
    end;
  SetLength(Result, c);
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
  ShadowBounds, CharacterBounds: TBox;
  Image: TLazIntfImage;
  Description: TRawImageDescription;
begin
  Self.Name := ExtractFileNameOnly(FontPath);
  Self.SpaceWidth := Space;

  FontPath := IncludeTrailingPathDelimiter(FontPath);
  if not DirectoryExists(FontPath) then
    Exit;

  Description.Init_BPP32_B8G8R8_BIO_TTB(0, 0);

  Image := TLazIntfImage.Create(0, 0);
  Image.DataDescription := Description;

  SetLength(Data, 256);

  for I := 0 to 255 do
  begin
    Data[I].Loaded := False;

    if FileExists(FontPath + IntToStr(I) + '.bmp') then
    begin
      Image.LoadFromFile(FontPath + IntToStr(I) + '.bmp');

      Data[I].Character := Chr(I);
      Data[I].CharacterPoints := FindColor(PRGB32(Image.PixelData), $FFFFFF, Image.Width, Image.Height);
      Data[I].Loaded := Length(Data[I].CharacterPoints) > 0;

      if Data[I].Loaded then
      begin
        Data[I].ShadowPoints := FindColor(PRGB32(Image.PixelData), $0000FF, Image.Width, Image.Height);
        Data[I].HasShadow := Length(Data[I].ShadowPoints) > 0;

        ShadowBounds := TPABounds(Data[I].ShadowPoints);
        CharacterBounds := TPABounds(Data[I].CharacterPoints);

        if CharacterBounds.X1 > 0 then
        begin
          OffsetTPA(Data[I].CharacterPoints, -CharacterBounds.X1,0);
          SortTPAByColumn(Data[I].CharacterPoints);
          if Data[I].HasShadow then
            OffsetTPA(Data[I].ShadowPoints, -CharacterBounds.X1, 0);

          Data[I].BackgroundPoints := InvertTPA(CombineTPA(Data[I].CharacterPoints, Data[I].ShadowPoints));
        end;

        Data[I].Width  := Max(CharacterBounds.X2 - CharacterBounds.X1, ShadowBounds.X2 - ShadowBounds.X1) + 1;
        Data[I].Height := Max(CharacterBounds.Y2, ShadowBounds.Y2) + 1;

        if Data[I].Width > MaxWidth then
          MaxWidth := Data[I].Width;
        if Data[I].Height > MaxHeight then
          MaxHeight := Data[I].Height;
      end;
    end;
  end;

  Image.Free();
end;

function TSimpleOCR.CompareChar(constref Character: TFontChar; constref Offset: TPoint; constref Info: TCompareRules): Int32;
var
  I, Hits, Any, MaxShadow: Int32;
  First, Color: TRGB32;
  P: TPoint;
begin
  Hits := 0;
  Any := 0;

  if (Info.Color = -1) then
  begin
    P := Character.CharacterPoints[0];
    P.X += Offset.X;
    P.Y += Offset.Y;
    if (P.X >= Self.Width) or (P.Y >= Self.Height) or (P.X < 0) or (P.Y < 0) then
      Exit(-1);

    First := TRGB32(Client[P.Y, P.X]);
    if Info.UseShadow then
    begin
      MaxShadow := 2 * Info.ShadowMaxValue;
      if ((First.R + First.G + First.B) div 3 < 85) and ((First.R < MaxShadow) and (First.G < MaxShadow) and (First.B < MaxShadow)) then
        Exit(-1);
    end;
  end else
    First := TRGB32(Info.Color);

  //count hits for the character
  for I := 0 to High(Character.CharacterPoints) do
  begin
    P := Character.CharacterPoints[I];
    P.X += Offset.X;
    P.Y += Offset.Y;
    if (P.X >= Self.Width) or (P.Y >= Self.Height) or (P.X < 0) or (P.Y < 0) then
      Exit(-1);

    Color := TRGB32(Client[P.Y, P.X]);
    if not (Sqr(Color.R - First.R) + Sqr(Color.B - First.B) + Sqr(Color.G - First.G) <= Info.Tolerance) then
      Exit(-1)
    else
      Inc(Hits, 2);
  end;

  if Hits < Length(Character.CharacterPoints) then
    Exit(-1); // < 50% match.

  if not Info.UseShadow then
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
      if Sqr(Color.R - First.R) + Sqr(Color.B - First.B) + Sqr(Color.G - First.G) > Info.Tolerance then
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

      if not ((Color.R < Info.ShadowMaxValue) and (Color.G < Info.ShadowMaxValue) and (Color.B < Info.ShadowMaxValue)) then
        Exit(-1)
      else
        Inc(Hits);
    end;
  end;

  if (Hits < Info.MinCharacterMatch) then
    Exit(-1);

  Result := Hits;
end;

function TSimpleOCR.Recognize(constref AClient: T2DIntegerArray; Filter: TCompareRules; constref FontSet: TFontSet; IsStatic: Boolean; MaxWalk: Int32): String;

  function Search(constref Bounds: TBox; out BestX, BestY: Int32; Recognize: Boolean): Boolean;
  var
    X, Y, I, H: Int32;
    Hits: Int32;
    Best: record
      Hits: Int32;
      X, Y: Int32;
    end;
  begin
    H := High(Self.Font.Data);

    Best.Hits := 0;
    Best.X := 0;
    Best.Y := 0;

    for X := Bounds.X1 to Bounds.X2 do
    begin
      if not Recognize then
        Best.Hits := 0;

      for Y := Bounds.Y1 to Bounds.Y2 do
      begin
        for I := 0 to H do
        begin
          if (not Self.Font.Data[I].Loaded) then
            Continue;

          Hits := Self.CompareChar(Self.Font.Data[I], Point(X, Y), Filter);
          if (Hits > Best.Hits) then
          begin
            Best.Hits := Hits;
            Best.X := X;
            Best.Y := Y;
          end;
        end;
      end;

      if (not Recognize) and (Best.Hits > 0) then
        Break;
    end;

    BestX := Best.X;
    BestY := Best.Y;

    Result := Best.Hits > 0;
  end;

var
  Bounds: TBox;
  Space, I, X, Y, H: Int32;
  Hits: Int32;
  Best: record
    Hits: Int32;
    Index: Int32;
    X, Y: Int32;
  end;
begin
  Result := '';

  Self.Font := FontSet;
  Self.Client := AClient;
  if (Length(Self.Client) = 0) or (Length(Client[0]) = 0) then
    Exit;

  Self.Width := Length(Client[0]);
  Self.Height := Length(Client);

  X := 0;
  Y := 0;
  H := High(Self.Font.Data);
  if (H < 0) then
    Exit;

  if Filter.Threshold then
  begin
    Filter.Color := 255;

    ThresholdAdaptive(Self.Client, 0, Filter.Color, Filter.ThresholdInvert, Filter.ThresholdAmount);
  end;

  if (Filter.Tolerance = 0) then
    Filter.Tolerance := Sqr(1)
  else
    Filter.Tolerance := Sqr(Filter.Tolerance);

  if not IsStatic then
  begin
    if (Filter.Color > -1) then
    begin
      Bounds := TPABounds(FindColors(Self.Client, TRGB32(Filter.Color), Filter.Tolerance));
      Bounds.X1 -= (FontSet.MaxWidth  div 3);
      Bounds.Y1 -= (FontSet.MaxHeight div 3);
      Bounds.X2 += (FontSet.MaxWidth  div 3);
      Bounds.Y2 += (FontSet.MaxHeight div 3);
    end
    else
    begin
      // OCR entire client (slow)
      Bounds.X1 := -Self.Font.MaxWidth  div 3;
      Bounds.Y1 := -Self.Font.MaxHeight div 3;
      Bounds.X2 := Self.Width  - (Self.Font.MaxWidth  div 3);
      Bounds.Y2 := Self.Height - (Self.Font.MaxHeight div 3);
    end;

    // Find something
    if not Search(Bounds, X, Y, False) then
      Exit;

    // Find best character around where something was found
    Bounds.X1 := X - (FontSet.MaxWidth  div 3);
    Bounds.Y1 := Y - (FontSet.MaxHeight div 3);
    Bounds.X2 := X + (FontSet.MaxWidth  div 3);
    Bounds.Y2 := Y + (FontSet.MaxHeight div 3);

    if not Search(Bounds, X, Y, True) then
      Exit;
  end;

  Space := 0;

  while (X < Self.Width) and (Space < MaxWalk) do
  begin
    Best.Hits := 0;
    Best.Index := -1;

    for I := 0 to H do
    begin
      if (not Self.Font.Data[I].Loaded) or (Width - X < Self.Font.Data[I].Width) then
        Continue;

      Hits := Self.CompareChar(Self.Font.Data[I], Point(X, Y), Filter);
      if (Hits > Best.Hits) then
      begin
        Best.Hits := Hits;
        Best.Index := I;
      end;
    end;

    if (Best.Index > -1) then
    begin
      if (Space >= Self.Font.SpaceWidth) then
        Result += #32;
      Space := 0;

      Result += Self.Font.Data[Best.Index].Character;
      X += Self.Font.Data[Best.Index].Width;

      Continue;
    end else
      Space += 1;

    X += 1;
  end;
end;

end.
