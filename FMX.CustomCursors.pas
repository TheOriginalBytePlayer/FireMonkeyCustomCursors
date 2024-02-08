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

unit FMX.CustomCursors;

interface
uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, FMX.Types, FMX.Controls;

type

    TCustomCursors = record
     public
       procedure LoadCursor(CursorIdent:Integer;InCursorName:string; HotSpotX:Single=0;HotSpotY:Single=0); overload;
       procedure LoadCursor(CursorIdent:Integer;InCursorName:string; HotSpot:TPointF); overload;
       procedure LoadAnimatedCursor(CursorIdent:Integer;InCursorName:string; HotSpotX:Single=0;HotSpotY:Single=0);
       function HasCursor(CursorIdent:Integer):Boolean;
    end;

var
   ScreenCursors:TCustomCursors;

procedure ReplaceCursorHandler;

implementation

uses
   System.IOUtils, FMX.Platform,
  {$IFDEF MSWINDOWS}
    FMX.CustomCursors.Win;
  {$ELSEIF DEFINED(MACOS)}
     FMX.CustomCursors.Mac;
  {$ENDIF}

procedure ReplaceCursorHandler;
begin
   var  MyCustomService := TCustomCursorCursorService.Create;
   var FoundService:=false;
     while not FoundService do
      begin
          try
              FoundService:=TPlatformServices.Current.GetPlatformService(IFMXCursorService) <> Nil;
          except
              //is expected, so fail silently!
              Sleep(200);
          end;
      end;

     TPlatformServices.Current.RemovePlatformService(IFMXCursorService);
     TPlatformServices.Current.AddPlatformService(IFMXCursorService,  MyCustomService);
end;


function TCustomCursors.HasCursor(CursorIdent: Integer): Boolean;
begin
    result:=TrueCursorController.HasCursor(CursorIdent);
end;

procedure TCustomCursors.LoadAnimatedCursor(CursorIdent: Integer;
  InCursorName: string; HotSpotX, HotSpotY: Single);
begin
    TrueCursorController.LoadAnimatedCursor(CursorIdent,InCursorName, HotSpotX,HotSpotY);
end;

procedure TCustomCursors.LoadCursor(CursorIdent:Integer;InCursorName:string; HotSpot:TPointF);
begin
    TrueCursorController.LoadCursor(CursorIdent,InCursorName,Hotspot.X,Hotspot.Y);
end;

procedure TCustomCursors.LoadCursor(CursorIdent:Integer;InCursorName:string;HotSpotX:Single=0; HotSpotY:Single=0);
begin
    TrueCursorController.LoadCursor(CursorIdent,InCursorName,HotSpotX,HotSpotY);
end;

end.
