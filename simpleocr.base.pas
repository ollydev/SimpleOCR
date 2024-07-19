unit simpleocr.base;
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
  IntfGraphics;

type
  TStringArray = array of String;
  TIntegerArray = array of Integer;
  TIntegerMatrix = array of TIntegerArray;
  TSingleArray = array of Single;

  TPoint = record
    X, Y: Integer;
  end;
  TPointArray = array of TPoint;

  TBox = record
    X1, Y1, X2, Y2: Integer;
  end;
  TBoxArray = array of TBox;

  TColorRGBA = record
  case Byte of
    0: (R,G,B,A: UInt8);
    1: (AsInteger: UInt32);
  end;
  TColorRGBAMatrix = array of array of TColorRGBA;

procedure Swap(var A, B: TPoint); inline;
procedure Swap(var A, B: Integer); inline;

function TPABounds(const TPA: TPointArray): TBox;
function InvertTPA(const TPA: TPointArray): TPointArray;
procedure OffsetTPA(var TPA: TPointArray; SX, SY: Integer);
function Mode(Self: TIntegerArray; Hi: Integer): Integer;

function SimilarColors(const Color1, Color2: TColorRGBA; const Tolerance: Single): Boolean; inline;
function IsShadow(const Color: TColorRGBA; const MaxValue: Integer): Boolean; inline;

type
  TSimpleImage = class(TObject)
  protected
    FInternalImage: TLazIntfImage;
    FWidth: Integer;
    FHeight: Integer;
  public
    constructor Create(FileName: String); reintroduce;
    destructor Destroy; override;

    property Width: Integer read FWidth;
    property Height: Integer read FHeight;

    function FindColor(Color: Integer): TPointArray;
  end;

implementation

uses
  GraphType, Graphics;

procedure Swap(var A, B: TPoint);
var
  C: TPoint;
begin
  C := A;
  A := B;
  B := C;
end;

procedure Swap(var A, B: Integer);
var
  C: Integer;
begin
  C := A;
  A := B;
  B := C;
end;

function TPABounds(const TPA: TPointArray): TBox;
var
  I, L: Integer;
begin
  Result := Default(TBox);
  L := High(TPA);
  if (l < 0) then Exit;
  Result.x1 := TPA[0].x;
  Result.y1 := TPA[0].y;
  Result.x2 := TPA[0].x;
  Result.y2 := TPA[0].y;
  for I:= 1 to L do
  begin
    if TPA[i].x > Result.x2 then
      Result.x2 := TPA[i].x
    else if TPA[i].x < Result.x1 then
      Result.x1 := TPA[i].x;
    if TPA[i].y > Result.y2 then
      Result.y2 := TPA[i].y
    else if TPA[i].y < Result.y1 then
      Result.y1 := TPA[i].y;
  end;
end;

function InvertTPA(const TPA: TPointArray): TPointArray;
var
  Matrix: TIntegerMatrix;
  i,h,x,y: Integer;
  Area: TBox;
begin
  Area := TPABounds(TPA);
  Area.X2 := (Area.X2-Area.X1);
  Area.Y2 := (Area.Y2-Area.Y1);
  SetLength(Matrix, Area.Y2+1, Area.X2+1);

  H := High(TPA);
  for i:=0 to H do
    Matrix[TPA[i].y-Area.y1][TPA[i].x-Area.x1] := 1;

  SetLength(Result, (Area.X2+1)*(Area.Y2+1) - H);
  i := 0;
  for y:=0 to Area.Y2 do
    for x:=0 to Area.X2 do
      if Matrix[y][x] <> 1 then
      begin
        Result[i].X := x+Area.x1;
        Result[i].Y := y+Area.y1;
        Inc(i);
      end;
  SetLength(Result, i);
  SetLength(Matrix, 0);
end;

procedure OffsetTPA(var TPA: TPointArray; SX, SY: Integer);
var
  I: Integer;
begin
  for I := 0 to High(TPA) do
  begin
    TPA[I].X := TPA[I].X + SX;
    TPA[I].Y := TPA[I].Y + SY;
  end;
end;

procedure QuickSort(var A: TIntegerArray; iLo, iHi: Integer);
var
  Lo, Hi, Pivot, T: Integer;
begin
  Lo := iLo;
  Hi := iHi;
  Pivot := A[(Lo + Hi) div 2];
  repeat
    while A[Lo] < Pivot do Inc(Lo);
    while A[Hi] > Pivot do Dec(Hi);
    if Lo <= Hi then
    begin
      T := A[Lo];
      A[Lo] := A[Hi];
      A[Hi] := T;
      Inc(Lo);
      Dec(Hi);
    end;
  until Lo > Hi;
  if Hi > iLo then QuickSort(A, iLo, Hi);
  if Lo < iHi then QuickSort(A, Lo, iHi);
end;

function Mode(Self: TIntegerArray; Hi: Integer): Integer;
var
  I, Hits, Best: Integer;
  Cur: Integer;
begin
  Result := 0;

  if (Length(Self) > 0) then
  begin
    QuickSort(Self, 0, Hi);

    Cur := Self[0];
    Hits := 1;
    Best := 0;

    for I := 1 to Hi do
    begin
      if (Self[I] <> Cur) then
      begin
        if (Hits > Best) then
        begin
          Best := Hits;
          Result := Cur;
        end;

        Hits := 0;
        Cur := Self[I];
      end;

      Inc(Hits);
    end;

    if (Hits > Best) then
      Result := Cur;
  end;
end;

function SimilarColors(const Color1, Color2: TColorRGBA; const Tolerance: Single): Boolean;
const
  MAX_DISTANCE_RGB = Single(441.672955930064); // Sqrt(Sqr(255) + Sqr(255) + Sqr(255))
begin
  if (Tolerance > 0) then
    Result := (Sqrt(Sqr(Color1.R-Color2.R) + Sqr(Color1.G-Color2.G) + Sqr(Color1.B-Color2.B)) / MAX_DISTANCE_RGB * 100) <= Tolerance
  else
    Result := (Color1.B = Color2.B) and (Color1.G = Color2.G) and (Color1.R = Color2.R);
end;

function IsShadow(const Color: TColorRGBA; const MaxValue: Integer): Boolean;
begin
  Result := (Color.R <= MaxValue) and (Color.G <= MaxValue) and (Color.B <= MaxValue + 5); // allow a little more in the blue channel only
end;

procedure OCRException(const Msg: String; Args: array of const);
begin
  raise Exception.Create(Format(Msg, Args));
end;

constructor TSimpleImage.Create(FileName: String);
var
  Description: TRawImageDescription;
begin
  inherited Create();

  Description.Init_BPP32_B8G8R8_BIO_TTB(0, 0);

  FInternalImage := TLazIntfImage.Create(0, 0);
  FInternalImage.DataDescription := Description;
  FInternalImage.LoadFromFile(FileName);

  FWidth := FInternalImage.Width;
  FHeight := FInternalImage.Height;
end;

destructor TSimpleImage.Destroy;
begin
  FreeAndNil(FInternalImage);

  inherited Destroy();
end;

function TSimpleImage.FindColor(Color: Integer): TPointArray;
var
  X, Y, Count: Integer;
begin
  SetLength(Result, FInternalImage.Width * FInternalImage.Height);

  Count := 0;
  for X := 0 to FInternalImage.Width - 1 do
    for Y := 0 to FInternalImage.Height - 1 do
      if FPColorToTColor(FInternalImage[X, Y]) = Color then
      begin
        Result[Count].X := X;
        Result[Count].Y := Y;

        Inc(Count);
      end;

  SetLength(Result, Count);
end;

end.
