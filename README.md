# FireMonkeyCustomCursors
A couple of units to enable custom cursors in FireMonkey -- works both Windows AND Mac
with the same cursors in a resource file (so long as they're saved at RCDATA, see note
below)!

No warrantees or guarantees about the usability, fitness etc. 
USE ENTIRELY AT YOUR OWN RISK -- I TAKE NO RESPONSIBILITY 

To use these functions you need to do FIVE things:[Uploading FMX.CustomCursors.Win.pas…]()


1) In your application project, add FMX.CustomCursors.pas to your uses clause
2) Add the line ReplaceCursorHandler; before Application.Initialize;
3) Make sure your cursors are stored in a resource file as RCDATA *NOT* RCCURSOR
4) Include the FMX.CustomCursors.pas in your application's mainform
5) In The application's mainform unit, load your cursors using the syntax:

  const
    crMyCursor = 5;

initialization
  ScreenCursors.loadCursor(crMyCursor,'CR_RESOURCENAME',<OptionalHotPointX>,<OptionalHotPointY>);

NOTE: That it will ONLY use the passed HotPoints if it can't read the HotPoint within the cursor, 
which it should be able to do for both Mac and Windows using Window's CUR files

If you find this useful, please buy my novel "An Otherwise Perfect Plan: A Novel of Mystery,
Love, and of Chocolate that Defies Description" (
