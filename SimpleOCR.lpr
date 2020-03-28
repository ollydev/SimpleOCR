library SimpleOCR;
{==============================================================================]
  Copyright (c) 2019, Jarl `slacky` Holta
  Project: SimpleOCR
  Project URL: https://github.com/slackydev/SimpleOCR
  License: GNU Lesser GPL (http://www.gnu.org/licenses/lgpl.html)
[==============================================================================}
{$mode objfpc}{$H+}

uses
  classes, sysutils,
  simpleocr.types, simpleocr.engine;

{$i simbaplugin.inc}

procedure TFontSet_Load(const Params: PParamArray); cdecl;
begin
  PFontSet(Params^[0])^.Load(PString(Params^[1])^, PInt32(Params^[2])^);
end;

procedure TSimpleOCR_Recognize(const Params: PParamArray; const Result:Pointer); cdecl;
begin
  PString(Result)^ := PSimpleOCR(Params^[0])^.Recognize(P2DIntegerArray(Params^[1])^, PCompareRules(Params^[2])^, PFontSet(Params^[3])^, PInt32(Params^[4])^);
end;

initialization
  addGlobalType('packed record'                  + LineEnding +
                '  FChar:AnsiChar;'              + LineEnding +
                '  FWidth,FHeight:Int32;'        + LineEnding +
                '  Loaded, HasShadow:LongBool;'  + LineEnding +
                '  PTS,Shadow,Bad:TPointArray;'  + LineEnding +
                'end;',
                'TFontChar');

  addGlobalType('packed record'                  + LineEnding +
                '  Name: String;'                + LineEnding +
                '  FData: Array of TFontChar;'   + LineEnding +
                '  SpaceWidth: Int32;'           + LineEnding +
                'end;',
                'TFontSet');

  addGlobalType('packed record'                  + LineEnding +
                '  Color, ColorMaxDiff: Int32;'  + LineEnding +
                '  UseShadow: LongBool;'         + LineEnding +
                '  ShadowMaxValue:Int32;'        + LineEnding +
                '  Threshold: Int32;'            + LineEnding +
                '  ThreshInv: LongBool;'         + LineEnding +
                'end;',
                'TCompareRules');

  addGlobalType('packed record'                  + LineEnding +
                '  FontData: TFontSet;'          + LineEnding +
                '  Client: T2DIntegerArray;'     + LineEnding +
                '  Width: Int32;'                + LineEnding +
                '  Height: Int32;'               + LineEnding +
                'end;',
                'TSimpleOCR');

  addGlobalFunc('procedure TFontSet.Load(Font: String; Space: Int32 = 4); native;', @TFontSet_Load);
  addGlobalFunc('function TSimpleOCR.Recognize(Client: T2DIntegerArray; Filter: TCompareRules; Font: TFontSet; MaxWalk: Int32 = 40): String; overload; native;', @TSimpleOCR_Recognize);

  addCode('function TSimpleOCR.Recognize(B: TBox; Filter: TCompareRules; Font: TFontSet; MaxWalk: Int32 = 40): AnsiString; overload;'     + LineEnding +
          'var'                                                                                                                           + LineEnding +
          '  Matrix: T2DIntegerArray;'                                                                                                    + LineEnding +
          '  BMP: Int32;'                                                                                                                 + LineEnding +
          'begin'                                                                                                                         + LineEnding +
          '  // Matrix := System.Client.GetIOManager().ReturnMatrix(B.X1, B.Y1, (B.X2 - B.X1) + 1, (B.Y2 - B.Y1) + 1);'                   + LineEnding +
          ''                                                                                                                              + LineEnding +
          '  BMP := BitmapFromClient(B.X1, B.Y1, B.X2, B.Y2);'                                                                            + LineEnding +
          '  Matrix := BitmapToMatrix(BMP);'                                                                                              + LineEnding +
          '  FreeBitmap(BMP);'                                                                                                            + LineEnding +
          ''                                                                                                                              + LineEnding +
          '  if Filter.Color <> -1 then'                                                                                                  + LineEnding +
          '    with TRGB32(Filter.Color) do'                                                                                              + LineEnding +
          '      Filter.Color := r or g shl 8 or b shl 16;'                                                                               + LineEnding +
          ''                                                                                                                              + LineEnding +
          '  Result := Self.Recognize(Matrix, Filter, Font, MaxWalk);'                                                                    + LineEnding +
          'end;'                                                                                                                          + LineEnding +
          ''                                                                                                                              + LineEnding +
          'function TSimpleOCR.Recognize(TPA: TPointArray; Font: TFontSet; MaxWalk: Int32 = 40): String; overload;'                       + LineEnding +
          'var'                                                                                                                           + LineEnding +
          '  Matrix: T2DIntegerArray;'                                                                                                    + LineEnding +
          '  B: TBox;'                                                                                                                    + LineEnding +
          '  i: Int32;'                                                                                                                   + LineEnding +
          'begin'                                                                                                                         + LineEnding +
          '  B := GetTPABounds(TPA);'                                                                                                     + LineEnding +
          '  B.X1 -= 1;'                                                                                                                  + LineEnding +
          '  B.Y1 -= 1;'                                                                                                                  + LineEnding +
          '  B.X2 += 1;'                                                                                                                  + LineEnding +
          '  B.Y2 += 1;'                                                                                                                  + LineEnding +
          ''                                                                                                                              + LineEnding +
          '  SetLength(Matrix, B.Y2 - B.Y1 + 1, B.X2 - B.X1 + 1);'                                                                        + LineEnding +
          '  for i := 0 to High(TPA) do'                                                                                                  + LineEnding +
          '    Matrix[TPA[i].Y - B.Y1][TPA[i].X - B.X1] := 255;'                                                                          + LineEnding +
          ''                                                                                                                              + LineEnding +
          '  Result := Self.Recognize(Matrix, [255], Font, MaxWalk);'                                                                     + LineEnding +
          'end;'                                                                                                                          + LineEnding +
          ''                                                                                                                              + LineEnding +
          'function TSimpleOCR.Recognize(Color, Tolerance: Int32; B: TBox; Font: TFontSet; MaxWalk: Int32 = 40): String; overload;'       + LineEnding +
          'var'                                                                                                                           + LineEnding +
          '  TPA: TPointArray;'                                                                                                           + LineEnding +
          'begin'                                                                                                                         + LineEnding +
          '  if FindColorsTolerance(TPA, Color, B.X1, B.Y1, B.X2, B.Y2, Tolerance) then'                                                  + LineEnding +
          '    Result := Self.Recognize(TPA, Font, MaxWalk);'                                                                             + LineEnding +
          'end;'                                                                                                                          + LineEnding +
          ''                                                                                                                              + LineEnding +
          'procedure TFontSet.Load(Font: String; Space: Int32 = 4); override;'                                                            + LineEnding +
          'begin'                                                                                                                         + LineEnding +
          '  if not DirectoryExists(Font) then'                                                                                           + LineEnding +
          '    raise "Font directory does not exist: " + Font;'                                                                           + LineEnding +
          '  inherited();'                                                                                                                + LineEnding +
          '  if Length(FData) = 0 then'                                                                                                   + LineEnding +
          '    raise "Failed to load font: " + Font;'                                                                                     + LineEnding +
          'end;'
         );

end.
