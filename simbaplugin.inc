// Helpers

type
  PParamArray = ^TParamArray;
  TParamArray = array[Word] of Pointer;

var
  SimbaImports: record
    Functions: array of record Header: String; Method: Pointer; end;
    Types: array of record Str: String; Name: String; end;
    Code: String;
  end;

  OldMemoryManager: TMemoryManager;

procedure addGlobalFunc(Header: String; Method: Pointer);
begin
  with SimbaImports do
  begin
    SetLength(Functions, Length(Functions) + 1);

    Functions[High(Functions)].Header := Header;
    Functions[High(Functions)].Method := Method;
  end;
end;

procedure addGlobalType(Str: String; Name: String);
begin
  with SimbaImports do
  begin
    SetLength(Types, Length(Types) + 1);

    Types[High(Types)].Str := Str;
    Types[High(Types)].Name := Name;
  end;
end;

procedure addCode(Code: TStringArray);
begin
  SimbaImports.Code := SimbaImports.Code + String.Join(LineEnding, Code);
end;

// Exports

function GetTypeCount(): Int32; cdecl;
begin
  Result := Length(SimbaImports.Types);
end;

function GetTypeInfo(Index: Int32; var Name, Str: PChar): Int32; cdecl;
begin
  with SimbaImports do
  begin
    StrPCopy(Name, Types[Index].Name);
    StrPCopy(Str, Types[Index].Str);
  end;

  Result := Index;
end;

function GetFunctionCount: Int32; cdecl;
begin
  Result := Length(SimbaImports.Functions);
end;

function GetFunctionInfo(Index: Int32; var Method: Pointer; var Header: PChar): Int32; cdecl;
begin
  with SimbaImports do
  begin
    StrPCopy(Header, Functions[Index].Header);

    Method := Functions[Index].Method;
  end;

  Result := Index;
end;

function GetCodeLength: Int32; cdecl;
begin
  Result := Length(SimbaImports.Code);
end;

procedure GetCode(var Code: PChar); cdecl;
begin
  StrPCopy(Code, SimbaImports.Code);
end;

function GetPluginABIVersion: Int32; cdecl;
begin
  Result := 2;
end;

procedure SetPluginMemManager(MemoryManager: TMemoryManager); cdecl;
begin
  GetMemoryManager(OldMemoryManager);
  SetMemoryManager(MemoryManager);
end;

procedure OnDetach(Data: Pointer); cdecl;
begin
  SetMemoryManager(OldMemoryManager);
end;

exports GetTypeCount;
exports GetTypeInfo;
exports GetFunctionCount;
exports GetFunctionInfo;
exports GetCodeLength;
exports GetCode;
exports GetPluginABIVersion;
exports SetPluginMemManager;
exports OnDetach;
