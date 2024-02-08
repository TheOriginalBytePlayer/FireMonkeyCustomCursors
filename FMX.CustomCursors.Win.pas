{*******************************************************}
{                                                       }
{        Delphi FireMonkey Platform Extensions          }
{                                                       }
{        Written by Ken Schafer - released as is        }
{            with no warrantees or promises             }
{                                                       }
{               USE AT YOUR OWN RISK                    }
{                                                       }
{*******************************************************}

unit FMX.CustomCursors.Win;

interface
uses
  System.SysUtils, System.Types, System.UITypes, System.Rtti, System.Classes,
  System.IOUtils, System.Variants, FMX.Platform.win;

Type
  TCustomCursorPlatformWin = class(TInterfacedObject, IFMXCursorService)
  private
    FCursor: TCursor;
//    FCustomCursor: TCustomCursor;
  public
    procedure SetCursor(const ACursor: TCursor);
    function GetCursor: TCursor;
  end;

    TCursorInfo = record
       TheCursorIdent:Integer;
       TheCursor:HCURSOR;
    end;

    TCustomCursors = record
     private
       CursorInfo:Array of TCursorInfo;
       function GetCursors(CursorIdent: Integer): HCursor;
       procedure SetCursor(CursorIdent: Integer; const Value: HCursor);
       procedure ReleaseCursors;
     public
       procedure LoadCursor(CursorIdent:Integer;InCursorName:string; HotSpotX:Single=0;HotSpotY:Single=0); overload;
       procedure LoadCursor(CursorIdent:Integer;InCursorName:string; HotSpot:TPointF); overload;
       procedure LoadAnimatedCursor(CursorIdent:Integer;InCursorName:string;
         HotSpotX:Single=0;HotSpotY:Single=0);
       function HasCursor(CursorIdent:Integer):Boolean;
       property Cursors[CursorIdent:Integer]:HCursor read GetCursors write SetCursor;
    end;

  TCustomCursorCursorService = TCustomCursorPlatformWin;

var
  TrueCursorController:TCustomCursors;



implementation

uses
  System.math, FMX.Forms, FMX.CustomCursors;

{ TPlatformExtensionsWin }

procedure TCustomCursorPlatformWin.SetCursor(const ACursor: TCursor);
const
  CustomCursorMap: array [crSizeAll .. crNone] of PChar = (
    nil, nil, nil, nil, nil, IDC_SQLWAIT, IDC_MULTIDRAG, nil, nil, IDC_NODROP, IDC_DRAG, nil, nil, nil, nil, nil,
    nil, nil, nil, nil, nil, nil);

  CursorMap: array [crSizeAll .. crNone] of PChar = (
    IDC_SIZEALL, IDC_HAND, IDC_HELP, IDC_APPSTARTING, IDC_NO, nil, nil, IDC_SIZENS, IDC_SIZEWE, nil, nil, IDC_WAIT,
    IDC_UPARROW, IDC_SIZEWE, IDC_SIZENWSE, IDC_SIZENS, IDC_SIZENESW, IDC_SIZEALL, IDC_IBEAM, IDC_CROSS, IDC_ARROW, nil);

  function IsDefaultOrInvalidCursor(const ACursor: TCursor): Boolean;
  begin
    Result := (ACursor = crDefault) or not InRange(ACursor, crSizeAll, crNone);
  end;

var
  NewCursor: HCURSOR;

  function KeyIsDown(KeyInQuestion:Integer):Boolean;
begin
   result:=GetAsyncKeyState(KeyInQuestion) AND $FF00 <> 0;
end;

function vkLeftButton:Word;
begin
     if GetSystemMetrics(SM_SWAPBUTTON) <> 0 then
        result:=vkRButton
     else
        result:=vkLButton;
end;

begin
//kjs added key check
  if not (DragAndDropIsActive and KeyIsDown(vkLeftButton)) then
  begin
     if TrueCursorController.HasCursor(ACursor) then
     begin
          WinAPI.Windows.SetCursor(TrueCursorController.Cursors[ACursor]);
          exit;
     end;

    // We don't set cursor by default, when we create window. So we should use crArrow cursor by default.
    if IsDefaultOrInvalidCursor(ACursor) and not (csDesigning in Application.ComponentState) then
      FCursor := crArrow
    else
      FCursor := ACursor;

    if InRange(FCursor, crSizeAll, crNone) then
    begin
      if CustomCursorMap[FCursor] <> nil then
        NewCursor := LoadCursorW(HInstance, CustomCursorMap[FCursor])
      else
        NewCursor := LoadCursorW(0, CursorMap[FCursor]);
      Winapi.Windows.SetCursor(NewCursor);
    end;
  end;
end;

function TCustomCursorPlatformWin.GetCursor: TCursor;
begin
  Result := FCursor;
end;


function TCustomCursors.HasCursor(CursorIdent: Integer): Boolean;
var
   I:Integer;
begin
     for I := 0 to High(CursorInfo) do
      if CursorInfo[i].TheCursorIdent=CursorIdent then
        begin
          result:=true;
          exit;
        end;
     result:=False;
end;


procedure TCustomCursors.LoadAnimatedCursor(CursorIdent:Integer;InCursorName:string;
          HotSpotX:Single=0;HotSpotY:Single=0);
var
  CursorFile: String;
  TempFileName: array [0..MAX_PATH-1] of char;
  TempDir: String;
begin
  TempDir:=System.IOUtils.TPath.GetTempPath();
  if WinAPI.Windows.GetTempFileName(PWideChar(TempDir), '~', 0, TempFileName) = 0 then
     raise Exception.Create(SysErrorMessage(GetLastError));
  CursorFile := TempFileName;
  with TResourceStream.Create(hInstance, InCursorName, RT_ANICURSOR) do
   try
     SaveToFile(CursorFile);
   finally
     Free;
   end;
  Cursors[CursorIdent]:= LoadImage(0, PChar(CursorFile), IMAGE_CURSOR, 0, 0,
                           LR_DEFAULTSIZE or LR_LOADFROMFILE);
  DeleteFile(PChar(CursorFile));
  if Cursors[CursorIdent] = 0 then
     raise Exception.Create(SysErrorMessage(GetLastError));
end;

procedure TCustomCursors.LoadCursor(CursorIdent:Integer;InCursorName:string; HotSpot:TPointF);
begin
    LoadCursor(CursorIdent,InCursorName,Hotspot.X,Hotspot.Y);
end;

procedure TCustomCursors.LoadCursor(CursorIdent:Integer;InCursorName:string;HotSpotX:Single=0; HotSpotY:Single=0);
var
  TempFileName:TFileName;
  rStream:TResourceStream;
begin
   if CursorIdent < 0 then
      raise Exception.Create('Cursor Idents below zero are reserved for system cursors!');

   TempFileName:=System.IOUtils.TPath.GetTempFileName;
   Cursors[CursorIdent]:=WinAPI.Windows.LoadCursorW(hinstance,InCursorName);
   if (Cursors[CursorIdent]=0) and (FindResourceW(HInstance,PWideChar(InCursorName),RT_CURSOR) > 0) then
      rStream:=TResourceStream.Create(Hinstance,InCursorName,RT_CURSOR)
   else if (Cursors[CursorIdent]=0) and (FindResourceW(HInstance,PWideChar(InCursorName),RT_RCDATA) > 0) then
       rStream:=TResourceStream.Create(Hinstance,InCursorName,RT_RCDATA)
   else
     exit;
   rStream.SaveToFile(TempFileName);
   rStream.Free;
   Cursors[CursorIdent]:=WinAPI.Windows.LoadCursorFromFile(PWideChar(TempFileName));
   DeleteFile(PWideChar(TempFileName));

end;

function TCustomCursors.GetCursors(CursorIdent: Integer): HCursor;
var
   I:Integer;
begin
     for I := 0 to High(CursorInfo) do
      if CursorInfo[i].TheCursorIdent=CursorIdent then
        begin
          result:=CursorInfo[i].TheCursor;
          exit;
        end;
     result:=WinAPI.Windows.LoadCursor(0, 'IDC_ARROW');
end;

procedure TCustomCursors.SetCursor(CursorIdent: Integer; const Value: HCursor);
var
   I:Integer;
begin
     if CursorIdent < 0 then
        raise Exception.Create('Cursor Idents below zero are reserved for system cursors!');
     for I := 0 to High(CursorInfo) do
      if CursorInfo[i].TheCursorIdent=CursorIdent then
        begin
          CursorInfo[i].TheCursor:=Value;
          exit;
        end;
     SetLength(CursorInfo,Length(CursorInfo)+1);
     CursorInfo[High(CursorInfo)].TheCursorIdent:=CursorIdent;
     CursorInfo[High(CursorInfo)].TheCursor:=Value;
end;

procedure TCustomCursors.ReleaseCursors;
begin
  SetLength(CursorInfo,0);
end;

initialization
  SetLength(TrueCursorController.CursorInfo,0);


finalization
  TrueCursorController.ReleaseCursors;
end.
