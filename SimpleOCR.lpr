library SimpleOCR;
{==============================================================================]
  Copyright (c) 2021, Jarl `slacky` Holta
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

procedure TSimpleOCR_DrawText(const Params: PParamArray; const Result: Pointer); cdecl;
begin
  P2DIntegerArray(Result)^ := PSimpleOCR(Params^[0])^.DrawText(PString(Params^[1])^, PFontSet(Params^[2])^);
end;

procedure TSimpleOCR_LocateText(const Params: PParamArray; const Result: Pointer); cdecl;
begin
  PSingle(Result)^ := PSimpleOCR(Params^[0])^.LocateText(P2DIntegerArray(Params^[1])^, PString(Params^[2])^, PFontSet(Params^[3])^, PCompareRules(Params^[4])^, PBox(Params^[5])^);
end;

procedure TSimpleOCR_LocateTextEx(const Params: PParamArray; const Result: Pointer); cdecl;
begin
  PBoolean(Result)^ := PSimpleOCR(Params^[0])^.LocateText(P2DIntegerArray(Params^[1])^, PString(Params^[2])^, PFontSet(Params^[3])^, PCompareRules(Params^[4])^, PSingle(Params^[5])^);
end;

procedure TSimpleOCR_Recognize(const Params: PParamArray; const Result: Pointer); cdecl;
begin
  PString(Result)^ := PSimpleOCR(Params^[0])^.Recognize(P2DIntegerArray(Params^[1])^, PCompareRules(Params^[2])^, PFontSet(Params^[3])^, PBoolean(Params^[4])^, PInt32(Params^[5])^);
end;

initialization
  addGlobalType('packed record'                      + LineEnding +
                '  Character: Char;'                 + LineEnding +
                '  ImageWidth, ImageHeight: Int32;'  + LineEnding +
                '  Width, Height: Int32;'            + LineEnding +
                '  HasShadow: Boolean;'              + LineEnding +
                '  CharacterBounds: TBox;'           + LineEnding +
                '  CharacterPoints: TPointArray;'    + LineEnding +
                '  ShadowPoints: TPointArray;'       + LineEnding +
                '  BackgroundPoints: TPointArray;'   + LineEnding +
                'end;',
                'TFontChar');

  addGlobalType('packed record'                    + LineEnding +
                '  Name: String;'                  + LineEnding +
                '  Data: array of TFontChar;'      + LineEnding +
                '  Count: Int32;'                  + LineEnding +
                '  SpaceWidth: Int32;'             + LineEnding +
                '  MaxWidth: Int32;'               + LineEnding +
                '  MaxHeight: Int32;'              + LineEnding +
                'end;',
                'TFontSet');

  addGlobalType('packed record'                    + LineEnding +
                '  Color, Tolerance: Int32;'       + LineEnding +
                '  UseShadow: Boolean;'            + LineEnding +
                '  ShadowMaxValue: Int32;'         + LineEnding +
                '  Threshold: Boolean;'            + LineEnding +
                '  ThresholdAmount: Int32;'        + LineEnding +
                '  ThresholdInvert: Boolean;'      + LineEnding +
                '  UseShadowForColor: Boolean;'    + LineEnding +
                '  MinCharacterMatch: Int32;'      + LineEnding +
                'end;',
                'TCompareRules');

  addGlobalType('packed record'                    + LineEnding +
                '  FontData: TFontSet;'            + LineEnding +
                '  Client: T2DIntegerArray;'       + LineEnding +
                '  Width: Int32;'                  + LineEnding +
                '  Height: Int32;'                 + LineEnding +
                'end;',
                'TSimpleOCR');

  addGlobalFunc('procedure TFontSet.Load(constref Font: String; constref Space: Int32 = 4); native;', @TFontSet_Load);

  addGlobalFunc('function TSimpleOCR.DrawText(constref Text: String; constref FontSet: TFontSet): T2DIntegerArray; native;', @TSimpleOCR_DrawText);

  addGlobalFunc('function TSimpleOCR.LocateText(constref Matrix: T2DIntegerArray; constref Text: String; constref Font: TFontSet; constref Filter: TCompareRules; out Bounds: TBox): Single; overload; native;', @TSimpleOCR_LocateText);
  addGlobalFunc('function TSimpleOCR.LocateText(constref Matrix: T2DIntegerArray; constref Text: String; constref Font: TFontSet; constref Filter: TCompareRules; constref MinMatch: Single = 1): Boolean; overload; native;', @TSimpleOCR_LocateTextEx);
  addGlobalFunc('function TSimpleOCR.Recognize(constref Matrix: T2DIntegerArray; constref Filter: TCompareRules; constref Font: TFontSet; constref IsStatic: Boolean = False; constref MaxWalk: Int32 = 40): String; overload; native;', @TSimpleOCR_Recognize);

  addCode('function TSimpleOCR.Recognize(constref B: TBox; constref Filter: TCompareRules; constref Font: TFontSet; constref IsStatic: Boolean = False; constref MaxWalk: Int32 = 40): String; overload;' + LineEnding +
          'begin'                                                                                                                                                                                         + LineEnding +
          '  Result := Self.Recognize(GetColorsMatrix(B.X1, B.Y1, B.X2, B.Y2), Filter, Font, IsStatic, MaxWalk);'                                                                                         + LineEnding +
          'end;'                                                                                                                                                                                          + LineEnding +
          ''                                                                                                                                                                                              + LineEnding +
          'function TSimpleOCR.RecognizeNumber(constref B: TBox; constref Filter: TCompareRules; constref Font: TFontSet; constref IsStatic: Boolean = False; constref MaxWalk: Int32 = 40): Int64;'      + LineEnding +
          'var'                                                                                                                                                                                           + LineEnding +
          '  Text: String;'                                                                                                                                                                               + LineEnding +
          '  Character: Char;'                                                                                                                                                                            + LineEnding +
          'begin'                                                                                                                                                                                         + LineEnding +
          '  for Character in Self.Recognize(B, Filter, Font, IsStatic, MaxWalk) do'                                                                                                                      + LineEnding +
          '    case Character of'                                                                                                                                                                         + LineEnding +
          '      #48..#57: Text += Character;'                                                                                                                                                            + LineEnding +
          '           #79: Text += #48;'                                                                                                                                                                  + LineEnding +
          '    end;'                                                                                                                                                                                      + LineEnding +
          ''                                                                                                                                                                                              + LineEnding +
          '  if (Text <> "") then'                                                                                                                                                                        + LineEnding +
          '    Result := StrToInt(Text);'                                                                                                                                                                 + LineEnding +
          'end;'                                                                                                                                                                                          + LineEnding +
          ''                                                                                                                                                                                              + LineEnding +
          'function TSimpleOCR.Recognize(constref TPA: TPointArray; constref Font: TFontSet; constref MaxWalk: Int32 = 40): String; overload;'                                                            + LineEnding +
          'var'                                                                                                                                                                                           + LineEnding +
          '  Matrix: T2DIntegerArray;'                                                                                                                                                                    + LineEnding +
          '  B: TBox;'                                                                                                                                                                                    + LineEnding +
          '  I: Int32;'                                                                                                                                                                                   + LineEnding +
          'begin'                                                                                                                                                                                         + LineEnding +
          '  B := GetTPABounds(TPA);'                                                                                                                                                                     + LineEnding +
          ''                                                                                                                                                                                              + LineEnding +
          '  SetLength(Matrix, B.Y2 - B.Y1 + 1, B.X2 - B.X1 + 1);'                                                                                                                                        + LineEnding +
          '  for I := 0 to High(TPA) do'                                                                                                                                                                  + LineEnding +
          '    Matrix[TPA[I].Y - B.Y1][TPA[I].X - B.X1] := 255;'                                                                                                                                          + LineEnding +
          ''                                                                                                                                                                                              + LineEnding +
          '  Result := Self.Recognize(Matrix, [255], Font, False, MaxWalk);'                                                                                                                              + LineEnding +
          'end;'                                                                                                                                                                                          + LineEnding +
          ''                                                                                                                                                                                              + LineEnding +
          'function TSimpleOCR.LocateText(constref B: TBox; constref Text: String; constref Font: TFontSet; constref Filter: TCompareRules; out Bounds: TBox): Single; overload;'                         + LineEnding +
          'begin'                                                                                                                                                                                         + LineEnding +
          '  Result := Self.LocateText(GetColorsMatrix(B.X1, B.Y1, B.X2, B.Y2), Text, Font, Filter, Bounds);'                                                                                             + LineEnding +
          '  if Result then'                                                                                                                                                                              + LineEnding +
          '  begin'                                                                                                                                                                                       + LineEnding +
          '    Bounds.X1 += B.X1;'                                                                                                                                                                        + LineEnding +
          '    Bounds.Y1 += B.Y1;'                                                                                                                                                                        + LineEnding +
          '    Bounds.X2 += B.X1;'                                                                                                                                                                        + LineEnding +
          '    Bounds.Y2 += B.Y1;'                                                                                                                                                                        + LineEnding +
          '  end;'                                                                                                                                                                                        + LineEnding +
          'end;'                                                                                                                                                                                          + LineEnding +
          ''                                                                                                                                                                                              + LineEnding +
          'function TSimpleOCR.LocateText(constref B: TBox; constref Text: String; constref Font: TFontSet; constref Filter: TCompareRules; constref MinMatch: Single = 1): Boolean; overload;'           + LineEnding +
          'begin'                                                                                                                                                                                         + LineEnding +
          '  Result := Self.LocateText(GetColorsMatrix(B.X1, B.Y1, B.X2, B.Y2), Text, Font, Filter, MinMatch);'                                                                                           + LineEnding +
          'end;'                                                                                                                                                                                          + LineEnding +
          ''                                                                                                                                                                                              + LineEnding +
          'procedure TFontSet.Load(constref Font: String; constref Space: Int32 = 4); override;'                                                                                                          + LineEnding +
          'begin'                                                                                                                                                                                         + LineEnding +
          '  if not DirectoryExists(Font) then'                                                                                                                                                           + LineEnding +
          '    raise "Font directory does not exist: " + Font;'                                                                                                                                           + LineEnding +
          '  inherited();'                                                                                                                                                                                + LineEnding +
          '  if Length(Self.Data) = 0 then'                                                                                                                                                               + LineEnding +
          '    raise "Failed to load font: " + Font;'                                                                                                                                                     + LineEnding +
          'end;'
         );

end.
