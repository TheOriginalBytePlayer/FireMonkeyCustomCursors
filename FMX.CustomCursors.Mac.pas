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

unit FMX.CustomCursors.Mac;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Rtti, System.Classes,
  System.IOUtils, System.Variants,System.Generics.Collections,
  FMX.Platform.Mac , FMX.Types, MacAPI.AppKit, Macapi.ObjectiveC,
    Macapi.Helpers, Macapi.CoreGraphics, Macapi.ImageIO,  Macapi.CocoaTypes,
    Macapi.CoreFoundation, Posix.StdLib, Macapi.Foundation;


Type
    TCustomCursors = record
     public
       procedure LoadCursor(CursorIdent:Integer;InCursorName:string; HotSpotX:Single=0;HotSpotY:Single=0); overload;
       procedure LoadCursor(CursorIdent:Integer;InCursorName:string; HotSpot:TPointF); overload;
       procedure LoadAnimatedCursor(CursorIdent:Integer;InCursorName:string; HotSpotX:Single=0;HotSpotY:Single=0);
       function HasCursor(CursorIdent:Integer):Boolean;
    end;

type
  {KJS MOVED PUBLIC}
  TCustomCursor = class
  private
    FImage: NSImage;
    FImgSourceRef: CGImageSourceRef;
    FCursor: NSCursor;
{KJS ADDED VARIABLE}
    FCursorIdent:Integer;
    fHotSpot:TPoint;
    function CGPointHotSpot: CGPoint;
  public
    constructor Create(const ABytes: Pointer; const ALength: NSUInteger;HotSpot: PPoint = nil); overload;
    constructor Create(const inResourceName:String;const inResourceStream:TResourceStream); overload;
    destructor Destroy; override;
    property Cursor: NSCursor read FCursor;
{KJS ADDED PROPERTY}
    property CursorIndex:Integer read FCursorIdent;
  end;

  TCustomCursorPlatformCocoa = class(TInterfacedObject, IFMXCursorService)
  private
    FCursor: TCursor;
    FCustomCursor: TCustomCursor;
  public
    procedure SetCursor(const ACursor: TCursor);
    function GetCursor: TCursor;
  end;


  TCustomCursorCursorService = TCustomCursorPlatformCocoa;


var
   TrueCursorController:TCustomCursors;


implementation

uses  FMX.CustomCursors;


{KJS ADDED}
const
  RT_CURSORGROUP = PChar(12);
  RT_CURSOR      = PChar(1);

type
  TRawCursorData = class
    private
       FCursorIdent:Integer;
       fHotSpot:TPoint;
       fResourceName:String;
       FResourceStream:TResourceStream;
  public
    constructor CreateFromResource(ResourceName:string; HotSpot: PPoint = Nil); overload;
    constructor CreateFromResource(ResourceID:Integer; HotSpot: PPoint = Nil); overload;
    destructor Destroy; override;
    function CustomCursor:TCustomCursor;
  end;


  TCustomCursorList = TObjectList<TRawCursorData>;

  TCustomCursorCollection = class
   strict private
      ListOfCursors:TCustomCursorList;
      fLastCursorFound:TRawCursorData;
      fLastIdentSearched:Integer;
      function FindCursor(CursorIdent:Integer):TRawCursorData;
      procedure InternalAddCursorFromResource(CursorIdent:Integer;ResourceName:string;HotSpot: PPoint = Nil);
      function getCursor(CursorIdent: Integer): TCustomCursor;
   public
      class procedure AddCursorFromResource(CursorIdent, ResourceID: Integer; HotSpot: TPoint); overload; static;
      class procedure AddCursorFromResource(CursorIdent,ResourceID:Integer;HotSpot: PPoint = Nil); overload; static;
      class procedure AddCursorFromResource(CursorIdent: Integer; ResourceName: string; HotSpot: TPoint); overload; static;
      class procedure AddCursorFromResource(CursorIdent:Integer;ResourceName:string;HotSpot: PPoint = Nil); overload; static;
      constructor create;
      destructor Destroy; override;
      function HasCursor(CursorIdent:Integer):Boolean;
      property CreateCursor[CursorIdent:Integer]:TCustomCursor read getCursor; default;
  end;

var
  CustomCursorCollection:TCustomCursorCollection;


  function TCustomCursors.HasCursor(CursorIdent: Integer): Boolean;
begin
   result:=Assigned(CustomCursorCollection) and CustomCursorCollection.HasCursor(CursorIdent);
end;

procedure TCustomCursors.LoadAnimatedCursor(CursorIdent:Integer;InCursorName:string;
          HotSpotX:Single=0;HotSpotY:Single=0);
begin
     raise Exception.Create('Animated Cursors are not implemented for the Mac');
end;


procedure TCustomCursors.LoadCursor(CursorIdent:Integer;InCursorName:string; HotSpot:TPointF);
begin
    LoadCursor(CursorIdent,InCursorName,Hotspot.X,Hotspot.y);
end;


procedure TCustomCursors.LoadCursor(CursorIdent:Integer;InCursorName:string;HotSpotX:Single=0; HotSpotY:Single=0);
begin
   if CursorIdent < 0 then
      raise Exception.Create('Cursor Idents below zero are reserved for system cursors!');
    TCustomCursorCollection.AddCursorFromResource(CursorIdent,InCursorName,Point(Round(HotSpotX),Round(HotSpotY)));
end;

{ TCursorInfo }

function TCustomCursor.CGPointHotSpot:CGPoint;
begin
   result:=CGPointMake(fHotSpot.X,fHotSpot.y);
end;

constructor TCustomCursor.Create(const ABytes: Pointer; const ALength: NSUInteger;HotSpot: PPoint);

function CGImageToNSImage(cgImage: CGImageRef): NSImage;
var
  imageSize: NSSize;
begin
  imageSize.width := CGImageGetWidth(cgImage);
  imageSize.height := CGImageGetHeight(cgImage);
  Result := TNSImage.Wrap(TNSImage.Alloc.initWithCGImage(cgImage, imageSize));
end;

var
  X,Y:Double;
begin
//  inherited Create;
  var EndChar:=PAnsiChar(ABytes);
  Inc(EndChar,ALength);
  if (PAnsiChar(ABytes)^='{') and (EndChar^='}') then
   begin
      var UString:UTF8String;
      SetLength(UString,ALength);
      System.Move(ABytes^,UString[1],ALength);
      var Url := CFURLCreateWithFileSystemPath(nil, CFStringCreateWithCString(nil, MarshaledAString(UString), kCFStringEncodingUTF8), kCFURLPOSIXPathStyle, False);
      var image := CGImageSourceCreateWithURL(URL,nil);
      var Properties := TNSDictionary.Wrap(CGImageSourceCopyPropertiesAtIndex(Image, 0, nil));
      FImage := CGImageToNSImage(image);
      if Properties <> nil then
       begin
         var hotspotValue := TNSNumber.Wrap(Properties.objectForKey((StrToNSStr('hotspotX') as ILocalObject).GetObjectID));
          if hotspotValue <> nil then
            X := hotspotValue.doubleValue;
         hotspotValue := TNSNumber.Wrap(Properties.objectForKey((StrToNSStr('hotspotY') as ILocalObject).GetObjectID));
          if hotspotValue <> nil then
            Y := hotspotValue.doubleValue;
         fHotSpot:=PointF(X,Y).Round;
         Properties.release;
        end;
       CFRelease(Url);
   end
  else
   begin
      var FData := TNSData.Wrap(TNSData.Alloc.initWithBytes(ABytes, ALength));
      FImage := TNSImage.Wrap(TNSImage.Alloc.initWithData(FData));
      if Assigned(HotSpot) then
        fHotSpot:=HotSpot^
      else
        fHotSpot:=PointF(FImage.size.Width/2,FImage.size.Height/2).Round;
      FData.release;
   end;
  FCursor := TNSCursor.Wrap(TNSCursor.Alloc.initWithImage(FImage, CGPointHotSpot));
end;

constructor TCustomCursor.Create(const inResourceName:String;const inResourceStream:TResourceStream);

function CGImageToNSImage(cgImage: CGImageRef): NSImage;
var
  imageSize: NSSize;
begin
  imageSize.width := CGImageGetWidth(cgImage);
  imageSize.height := CGImageGetHeight(cgImage);
  Result := TNSImage.Wrap(TNSImage.Alloc.initWithCGImage(cgImage, imageSize));
end;

var
  X,Y:Double;
begin
  inherited Create;
  if assigned(inResourceStream) and (inResourceStream.Size > 0) then
   begin
        inResourceStream.Position:=0;
         var Provider := CGDataProviderCreateWithData(nil, inResourceStream.Memory, inResourceStream.Size, nil);
         if Provider <> nil then
          try
            FImgSourceRef := CGImageSourceCreateWithDataProvider(Provider, nil);
            if FImgSourceRef <> nil then
              begin
                   var FData := TNSData.Wrap(TNSData.Alloc.initWithBytes(inResourceStream.Memory, inResourceStream.Size));
                   FImage := TNSImage.Wrap(TNSImage.Alloc.initWithData(FData));
                   fHotSpot:=PointF(FImage.size.Width/2,FImage.size.Height/2).Round;
                   FCursor := TNSCursor.Wrap(TNSCursor.Alloc.initWithImage(FImage, CGPointHotSpot));
                   FData.release;
                   var Properties := TNSDictionary.Wrap(CGImageSourceCopyPropertiesAtIndex(FImgSourceRef, 0, nil));
                    if Properties <> nil then
                    begin
                         var hotspotValue := TNSNumber.Wrap(Properties.objectForKey((NSStr('hotspotX') as ILocalObject).GetObjectID));
                          if hotspotValue <> nil then
                            fHotSpot.X := Round(hotspotValue.doubleValue);
                         hotspotValue := TNSNumber.Wrap(Properties.objectForKey((NSStr('hotspotY') as ILocalObject).GetObjectID));
                          if hotspotValue <> nil then
                            fHotSpot.Y := Round(hotspotValue.doubleValue);
                        Properties.Release
                    end;

              end;
            finally
              CGDataProviderRelease(Provider);
            end;
   end
  else
   begin
     var UString:UTF8String:=UTF8Encode(inResourceName);
      var Url := CFURLCreateWithFileSystemPath(nil, CFStringCreateWithCString(nil, MarshaledAString(UString), kCFStringEncodingUTF8), kCFURLPOSIXPathStyle, False);
      FImgSourceRef:= CGImageSourceCreateWithURL(URL,nil);
      var Properties := TNSDictionary.Wrap(CGImageSourceCopyPropertiesAtIndex(FImgSourceRef, 0, nil));
      FImage := CGImageToNSImage(FImgSourceRef);
      if Properties <> nil then
       begin
         var hotspotValue := TNSNumber.Wrap(Properties.objectForKey((StrToNSStr('hotspotX') as ILocalObject).GetObjectID));
          if hotspotValue <> nil then
            X := hotspotValue.doubleValue;
         hotspotValue := TNSNumber.Wrap(Properties.objectForKey((StrToNSStr('hotspotY') as ILocalObject).GetObjectID));
          if hotspotValue <> nil then
            Y := hotspotValue.doubleValue;
         fHotSpot:=PointF(X,Y).Round;
         Properties.release;
        end;
       CFRelease(Url);
   end;
  FCursor := TNSCursor.Wrap(TNSCursor.Alloc.initWithImage(FImage, CGPointHotSpot));
end;

destructor TCustomCursor.Destroy;
begin
  FCursor.release;
  FImage.release;
  CFRelease(FImgSourceRef);
//KJS ADDDED
//  inherited destroy;
end;


{ TCustomCursorCollection }

class procedure TCustomCursorCollection.AddCursorFromResource(CursorIdent:Integer;ResourceID: Integer;
  HotSpot: PPoint);
begin
    AddCursorFromResource(CursorIdent,IntToStr(ResourceID),HotSpot);
end;

class procedure TCustomCursorCollection.AddCursorFromResource(CursorIdent:Integer;ResourceID: Integer;
  HotSpot: TPoint);
begin
    AddCursorFromResource(CursorIdent,IntToStr(ResourceID),@HotSpot);
end;

class procedure TCustomCursorCollection.AddCursorFromResource(CursorIdent:Integer;ResourceName: string;HotSpot: TPoint);
begin
    if not Assigned(CustomCursorCollection) then
       CustomCursorCollection:=TCustomCursorCollection.Create;

   CustomCursorCollection.InternalAddCursorFromResource(CursorIdent,ResourceName,@HotSpot);
end;

class procedure TCustomCursorCollection.AddCursorFromResource(CursorIdent:Integer;ResourceName: string;HotSpot: PPoint);
begin
   if not Assigned(CustomCursorCollection) then
      CustomCursorCollection:=TCustomCursorCollection.Create;

   CustomCursorCollection.InternalAddCursorFromResource(CursorIdent,ResourceName,HotSpot);
end;



procedure TCustomCursorCollection.InternalAddCursorFromResource(CursorIdent:Integer;ResourceName: string;
  HotSpot: PPoint);
var
  CursorToAdd:TRawCursorData;
begin
  if HasCursor(CursorIdent) then
     raise Exception.Create('Cursor with Ident '+IntToStr(CursorIdent)+' already exists!');

  CursorToAdd:=TRawCursorData.CreateFromResource(ResourceName,HotSpot);
  CursorToAdd.FCursorIdent:=CursorIdent;
  ListOfCursors.Add(CursorToAdd);
end;

constructor TCustomCursorCollection.create;
begin
  inherited Create;
  ListOfCursors:=TCustomCursorList.Create;
  ListOfCursors.ownsObjects:=true;
  fLastCursorFound:=Nil;
  fLastIdentSearched:=0;
  var FCursorService:IFMXCursorService;
end;

destructor TCustomCursorCollection.Destroy;
begin
  ListOfCursors.Free;
  inherited;
end;

function TCustomCursorCollection.FindCursor(CursorIdent:Integer):TRawCursorData;
var
  I: Integer;
begin
   try
       if (fLastIdentSearched=CursorIdent) and Assigned(FLastCursorFound) then
          exit;

       for I := 0 to ListofCursors.Count-1 do
         if ListofCursors.Items[i].FCursorIdent=CursorIdent then
          begin
             fLastIdentSearched:=CursorIdent;
             FLastCursorFound:=ListofCursors.Items[i];
             exit;
          end;
       fLastIdentSearched:=0;
       FLastCursorFound:=Nil;
   finally
     result:=fLastCursorFound;
    end;
end;

function TCustomCursorCollection.GetCursor(CursorIdent: Integer): TCustomCursor;
var
  RawData:TRawCursorData;
begin
  result:=Nil;
  if not HasCursor(CursorIdent) then
    exit;

   RawData:=FindCursor(CursorIdent);
   if assigned(RawData) then
      result:=TCustomCursor.Create(RawData.fResourceName,RawData.FResourceStream);
end;


function TCustomCursorCollection.HasCursor(CursorIdent: Integer): Boolean;
begin
      result:=FindCursor(CursorIdent) <> nil;
end;


{ TRawCursorData }

constructor TRawCursorData.CreateFromResource(ResourceID: Integer; HotSpot: PPoint);
begin
  CreateFromResource(IntToStr(ResourceID),HotSpot);
end;

type
  TCursorGroupHeader = packed record
     Reserved:WORD;
     ResType:WORD;
     ResCount:WORD;
  end;
   TResourceStructure = packed record
      Width:Word;
      Height:Word;
      Planes:Word;
      BitCount:Word;
      BytesInRes:Word;
      IconCursorId:Word;
    end;

constructor TRawCursorData.CreateFromResource(ResourceName: string; HotSpot: PPoint);
var
  rh:TResourceHandle;
  IsRTCursor:Boolean;
  GroupHeader:TCursorGroupHeader;
  ResData:TResourceStructure;
begin
  //try loading the RCDATA
  rh:=FindResource(HInstance,PChar(ResourceName),RT_RCDATA);
  if rh=0 then
  begin
    //try loading it from Startup Directory
      var AppBundle:NSBundle;
      AppBundle:=TNSBundle.Wrap(TNSBundle.OCClass.mainBundle);

      var PNGResourceName:=UTF8ToString(AppBundle.bundlePath.UTF8String)+'/Contents/Resources/Startup/'+ResourceName+'.PNG';
      //if it's not there iwth a PNG extension try a cursor extension
      if not FileExists(PNGResourceName) and FileExists(ChangeFileExt(PNGResourceName,'.cur')) then
        PNGResourceName:=ChangeFileExt(PNGResourceName,'.cur');
      if FileExists(PNGResourceName) then
      begin
          inherited Create;
          fResourceName:=PNGResourceName;
          //this sets it to load it from the file and;
          FResourceStream:=Nil;
      end
     else
      begin
         rh:=FindResource(HInstance,PChar(ResourceName),RT_CURSORGROUP);
         if rh <> 0 then
          begin
            {$IFDEF DEBUG}
              Raise Exception.Create('CURSORS IN Resources MUST BE stored at RCDATA '+
                 'to be readable on the Mac and "'+ResourceName+'" is stored as a Cursor Group');
            {$ENDIF DEBUG}
            {
              var LocalStream:=TResourceStream.Create(HInstance,ResourceName,RT_CURSORGROUP);
                  LocalStream.Position:=0;
                  LocalStream.Read(GroupHeader,SizeOf(TCursorGroupHeader));
                  for var ResCount := 0 to Pred(Groupheader.ResCount) do
                     begin
                        LocalStream.Read(ResData,sizeof(ResData));
                        var ResourceType:NativeInt:=GroupHeader.ResType;
                        var CursorID:NativeInt:=ResData.IconCursorID+1;
                        try
                          FreeAndNil(LocalStream);
                          LocalStream:=TResourceStream.CreateFromID(hInstance,CursorID,PChar(ResourceType));
                          LocalStream.Position:=0;
                          inherited Create;
                          fResourceStream:=LocalStream;
                          Exit;
                        except
                           //fail quiety;
                        end;
                     end;
                  LocalStream.Free;}
          end
{$IFDEF DEBUG}
         else
              Raise Exception.Create('Failed to Find Desired Cursor: "'+ResourceName+'"');

{$ENDIF}
      end;
  end
else
   begin
     inherited Create;
     fResourceStream:=TResourceStream.Create(HInstance,ResourceName,RT_RCDATA);
     FResourceStream.Position:=0;
   end
end;

function TRawCursorData.CustomCursor: TCustomCursor;
begin
      result:=TCustomCursor.Create(fResourceName,FResourceStream);
end;

destructor TRawCursorData.Destroy;
begin
   if Assigned(FResourceStream) then
      FResourceStream.Free;
   inherited;
end;

{ TCustomCursorPlatformCocoa }

function TCustomCursorPlatformCocoa.GetCursor: TCursor;
begin
  Result := FCursor;
end;

procedure TCustomCursorPlatformCocoa.SetCursor(const ACursor: TCursor);
const
  SizeNWSECursor: array [0..192] of byte = (
    $89, $50, $4E, $47, $0D, $0A, $1A, $0A, $00, $00, $00, $0D, $49, $48, $44, $52, $00, $00, $00, $10, $00, $00, $00, $10, $08, $06, $00, $00, $00, $1F, $F3, $FF, $61, $00, $00, $00, $88, $49, $44, $41,
    $54, $78, $9C, $AC, $93, $4B, $0A, $C0, $20, $0C, $44, $45, $8A, $69, $D7, $5D, $7B, $00, $0F, $98, $EB, $6B, $15, $8C, $44, $F1, $1B, $3A, $20, $BA, $D0, $E7, $4C, $A2, $4A, $FD, $A1, $30, $D1, $36,
    $20, $4D, $69, $00, $40, $59, $8B, $00, $FC, $B0, $08, $60, $8C, $A9, $6E, $BF, $A2, $44, $0E, $08, $82, $88, $EA, $8D, $DA, $02, $78, $EF, $43, $0B, $63, $31, $EE, $29, $80, $67, $26, $88, $D6, $BA,
    $82, $58, $6B, $97, $69, $CA, $A6, $91, $93, $AD, $16, $3F, $51, $23, $48, $8A, $D9, $44, $EB, $8B, $AA, $3F, $2B, $F0, $3A, $4F, $16, $41, $A8, $C5, $47, $00, $96, $F7, $DC, $81, $73, $AE, $FB, $C8,
    $44, $0E, $C4, $1F, $6D, $A5, $0F, $00, $00, $FF, $FF, $03, $00, $FD, $DF, $FC, $72, $CD, $04, $2F, $27, $00, $00, $00, $00, $49, $45, $4E, $44, $AE, $42, $60, $82
  );
  SizeNESWCursor: array [0..211] of byte = (
    $89, $50, $4E, $47, $0D, $0A, $1A, $0A, $00, $00, $00, $0D, $49, $48, $44, $52, $00, $00, $00, $10, $00, $00, $00, $10, $08, $06, $00, $00, $00, $1F, $F3, $FF, $61, $00, $00, $00, $9B, $49, $44, $41,
    $54, $78, $9C, $9C, $93, $51, $0E, $C0, $10, $0C, $86, $3D, $88, $CC, $F3, $0E, $E3, $2A, $2E, $E2, $04, $6E, $E0, $C5, $5D, $DC, $4D, $4C, $93, $CD, $1A, $46, $AD, $7F, $D2, $14, $49, $3F, $D5, $96,
    $10, $0B, $95, $52, $48, $23, $55, $D6, $DA, $03, $80, $EB, $ED, $17, $20, $E7, $CC, $06, $1C, $29, $A5, $96, $85, $52, $AA, $79, $12, $A0, $AB, $62, $8C, $BC, $27, $9C, $55, $21, $84, $21, $18, $45,
    $CD, $01, $52, $4A, $E1, $9C, $FB, $0C, $F6, $DE, $F7, $5D, $79, $0B, $85, $4F, $26, $37, $C3, $42, $0E, $33, $70, $6F, $86, $14, $B7, $AB, $8D, $01, $5F, $85, $32, $C6, $C0, $42, $93, $00, $DC, $A2,
    $27, $D8, $5A, $0B, $DD, $58, $8F, $EC, $2C, $03, $18, $1E, $54, $13, $FE, $13, $B6, $01, $33, $ED, $02, $78, $5F, $B5, $EA, $02, $00, $00, $FF, $FF, $03, $00, $27, $CE, $7B, $C4, $F5, $A4, $B6, $D6,
    $00, $00, $00, $00, $49, $45, $4E, $44, $AE, $42, $60, $82
  );
  SizeAllCursor: array [0..174] of byte = (
    $89, $50, $4E, $47, $0D, $0A, $1A, $0A, $00, $00, $00, $0D, $49, $48, $44, $52, $00, $00, $00, $10, $00, $00, $00, $10, $08, $06, $00, $00, $00, $1F, $F3, $FF, $61, $00, $00, $00, $09, $70, $48, $59,
    $73, $00, $00, $0B, $13, $00, $00, $0B, $13, $01, $00, $9A, $9C, $18, $00, $00, $00, $61, $49, $44, $41, $54, $78, $9C, $AC, $53, $CB, $0A, $00, $20, $0C, $1A, $F4, $FF, $DF, $6C, $10, $74, $68, $0F,
    $17, $65, $E0, $A9, $74, $BA, $36, $03, $60, $04, $FB, $94, $6F, $28, $D9, $6C, $2C, $30, $91, $96, $DC, $89, $5C, $91, $99, $48, $95, $19, $49, $84, $E3, $2A, $13, $F0, $55, $B2, $CA, $C1, $49, $D5,
    $B0, $D2, $81, $17, $A5, $99, $3B, $04, $AB, $AF, $02, $DF, $11, $24, $4D, $94, $7C, $A3, $64, $90, $24, $A3, $2C, $59, $A6, $EB, $75, $9E, $00, $00, $00, $FF, $FF, $03, $00, $3A, $00, $A6, $5B, $CC,
    $0B, $A4, $58, $00, $00, $00, $00, $49, $45, $4E, $44, $AE, $42, $60, $82
  );
  WaitCursor: array [0..124] of byte = (
    $89, $50, $4E, $47, $0D, $0A, $1A, $0A, $00, $00, $00, $0D, $49, $48, $44, $52, $00, $00, $00, $10, $00, $00, $00, $10, $08, $06, $00, $00, $00, $1F, $F3, $FF, $61, $00, $00, $00, $44, $49, $44, $41,
    $54, $78, $9C, $62, $60, $C0, $0E, $FE, $E3, $C0, $44, $83, $21, $6E, $C0, $7F, $5C, $80, $18, $43, $70, $6A, $26, $D6, $10, $BA, $19, $80, $D3, $10, $6C, $0A, $C9, $33, $00, $59, $03, $45, $5E, $C0,
    $65, $00, $94, $4D, $5A, $38, $10, $B2, $1D, $C5, $10, $1C, $98, $68, $30, $84, $0C, $00, $00, $00, $00, $FF, $FF, $03, $00, $A9, $31, $25, $E9, $C0, $2C, $FB, $9B, $00, $00, $00, $00, $49, $45, $4E,
    $44, $AE, $42, $60, $82
  );
  HelpCursor: array [0..238] of byte = (
    $89, $50, $4E, $47, $0D, $0A, $1A, $0A, $00, $00, $00, $0D, $49, $48, $44, $52, $00, $00, $00, $12, $00, $00, $00, $12, $08, $06, $00, $00, $00, $56, $CE, $8E, $57, $00, $00, $00, $B6, $49, $44, $41,
    $54, $78, $9C, $A4, $94, $3B, $12, $80, $20, $0C, $44, $69, $6C, $6D, $6C, $BC, $83, $8D, $B5, $F7, $E0, $FE, $37, $01, $89, $93, $8C, $61, $F9, $18, $21, $33, $19, $15, $C9, $73, $B3, $46, $9D, $83,
    $88, $31, $52, $36, $03, $F7, $17, $C5, $1A, $E2, $BD, $0F, $74, $89, $49, $EB, $9F, $30, $06, $05, $81, $70, $51, $D0, $6B, $66, $18, $15, $49, $01, $9F, $9F, $29, $77, $BD, $CE, $F7, $E8, $B8, $98,
    $40, $1A, $D6, $00, $ED, $05, $4C, $79, $94, $B5, $C1, $80, $0B, $40, $D2, $1A, $A9, $5D, $BB, $AA, $30, $1B, $1E, $5D, $29, $B7, $AE, $57, $FC, $A4, $23, $ED, $CF, $D4, $00, $A4, $AF, $08, $D5, $C1,
    $5B, $FC, $0F, $11, $D0, $34, $44, $83, $A6, $20, $4E, $08, $EF, $A7, $61, $32, $B7, $0A, $A9, $F8, $53, $CE, $8E, $05, $E4, $CA, $21, $1C, $F2, $A7, $A6, $68, $BC, $3D, $F0, $28, $53, $64, $F9, $11,
    $48, $3C, $83, $59, $83, $FC, $8D, $85, $8B, $B7, $2F, $C8, $0D, $00, $00, $FF, $FF, $03, $00, $A5, $D1, $28, $C9, $B0, $25, $E3, $01, $00, $00, $00, $00, $49, $45, $4E, $44, $AE, $42, $60, $82
  );
var
  C: NSCursor;
  AutoReleasePool: NSAutoreleasePool;
  NewCustomCursor: TCustomCursor;
begin
  AutoReleasePool := TNSAutoreleasePool.Create;
  try
    NewCustomCursor := nil;
    case ACursor of
      crCross: C := TNSCursor.Wrap(TNSCursor.OCClass.crosshairCursor);
      crArrow, crDefault: C := TNSCursor.Wrap(TNSCursor.OCClass.arrowCursor);
      crIBeam: C := TNSCursor.Wrap(TNSCursor.OCClass.IBeamCursor);
      crSizeNS: C := TNSCursor.Wrap(TNSCursor.OCClass.resizeUpDownCursor);
      crSizeWE: C := TNSCursor.Wrap(TNSCursor.OCClass.resizeLeftRightCursor);
      crUpArrow: C := TNSCursor.Wrap(TNSCursor.OCClass.resizeUpCursor);
      crDrag, crMultiDrag:  C := TNSCursor.Wrap(TNSCursor.OCClass.dragCopyCursor);
      crHSplit: C := TNSCursor.Wrap(TNSCursor.OCClass.resizeLeftRightCursor);
      crVSplit: C := TNSCursor.Wrap(TNSCursor.OCClass.resizeUpDownCursor);
      crNoDrop, crNo: C := TNSCursor.Wrap(TNSCursor.OCClass.operationNotAllowedCursor);
      crHandPoint: C := TNSCursor.Wrap(TNSCursor.OCClass.pointingHandCursor);
      crAppStart, crSQLWait, crHourGlass: NewCustomCursor := TCustomCursor.Create(@WaitCursor[0], Length(WaitCursor));
      crHelp:  NewCustomCursor := TCustomCursor.Create(@HelpCursor[0], Length(HelpCursor));
      crSizeNWSE: NewCustomCursor := TCustomCursor.Create(@SizeNWSECursor[0], Length(SizeNWSECursor));
      crSizeNESW: NewCustomCursor := TCustomCursor.Create(@SizeNESWCursor[0], Length(SizeNESWCursor));
      crSizeAll: NewCustomCursor := TCustomCursor.Create(@SizeAllCursor[0], Length(SizeAllCursor));
//KJS ADDED
      crNone:{do nothing but don't process else!};
    else
{KJS ADDED FOR CUSTOM CURSORS} // Need to create it because is goign to Free it!
      if CustomCursorCollection.HasCursor(ACursor) then
         NewCustomCursor:=CustomCursorCollection[ACursor]
      else {KJS END ADD}
       begin
         C := TNSCursor.Wrap(TNSCursor.OCClass.arrowCursor);
       end;
    end;
    if ACursor = crNone then
      TNSCursor.OCClass.setHiddenUntilMouseMoves(True)
    else
    begin
      TNSCursor.OCClass.setHiddenUntilMouseMoves(False);
      // Remove old custom cursor
      if FCustomCursor <> nil then
        FreeAndNil(FCustomCursor);
      // Set new custom cursor
      if NewCustomCursor <> nil then
      begin
        FCustomCursor := NewCustomCursor;
        C := FCustomCursor.Cursor;
      end;
      C.&set;
    end;
    FCursor := ACursor;
  finally
    AutoReleasePool.release;
  end;
end;

initialization
 if not Assigned(CustomCursorCollection) then
    CustomCursorCollection:=TCustomCursorCollection.Create;

finalization

 if Assigned(CustomCursorCollection) then
  CustomCursorCollection.Free;


end.
