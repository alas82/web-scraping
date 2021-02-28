unit main;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Dialogs, StdCtrls, LCLIntf,
  LCLType, Graphics, synacode, fphttpclient, regexpr,
  openssl, opensslsockets, strutils;
type
  { TForm1 }TForm1 = class(TForm)
    Button2: TButton;
    Edit1: TEdit;
    Label1: TLabel;
    Label2: TLabel;
    ListBox1: TListBox;
    procedure Button2Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure ListBox1Click(Sender: TObject);
    function GetLastPageNo(const anHTMLText: string): integer;
    procedure ListBox1DrawItem(Control: TWinControl; Index: integer;
      ARect: TRect; State: TOwnerDrawState);
  private
    procedure DoOnWriteStream(Sender: TObject; APosition: int64);
    procedure Download(AFrom, ATo: string);
    function FormatSize(aSize: int64): string;
    function get1webpage(url: string): string;
    function getrightfilename(x: string): string;
  public

  end;

var
  Form1: TForm1;


implementation

{$R *.lfm}
type

  { TDownloadStream }

  TOnWriteStream = procedure(Sender: TObject; APos: int64) of object;

  TDownloadStream = class(TStream)
  private
    FOnWriteStream: TOnWriteStream;
    FStream: TStream;
  public
    constructor Create(AStream: TStream);
    destructor Destroy; override;
    function Read(var Buffer; Count: longint): longint; override;
    function Write(const Buffer; Count: longint): longint; override;
    function Seek(Offset: longint; Origin: word): longint; override;
    procedure DoProgress;
  published
    property OnWriteStream: TOnWriteStream read FOnWriteStream write FOnWriteStream;
  end;


{ TForm1 }

{ TDownloadStream }

constructor TDownloadStream.Create(AStream: TStream);
begin
  inherited Create;
  FStream := AStream;
  FStream.Position := 0;
end;

destructor TDownloadStream.Destroy;
begin
  FStream.Free;
  inherited Destroy;
end;

function TDownloadStream.Read(var Buffer; Count: longint): longint;
begin
  Result := FStream.Read(Buffer, Count);
end;

function TDownloadStream.Write(const Buffer; Count: longint): longint;
begin
  Result := FStream.Write(Buffer, Count);
  DoProgress;
end;

function TDownloadStream.Seek(Offset: longint; Origin: word): longint;
begin
  Result := FStream.Seek(Offset, Origin);
end;

procedure TDownloadStream.DoProgress;
begin
  // fpercent:= Trunc((FStream.Position) / (FStream.Size) * 100);
  if Assigned(FOnWriteStream) then
    FOnWriteStream(Self, Self.Position);
end;

{ TForm1 }

procedure TForm1.Download(AFrom, ATo: string);
var
  DS: TDownloadStream;
  x: string;
  FHTTPClient: TFPHTTPClient;
begin
  FHTTPClient := TFPHTTPClient.Create(nil);
  DS := TDownloadStream.Create(TFileStream.Create(ATo, fmCreate));
  FHTTPClient.AllowRedirect := False;
  FHTTPClient.AddHeader('User-Agent', 'Wget/1.20.1 (linux-gnu)');
  try
    DS.FOnWriteStream := @DoOnWriteStream;
    try
      FHTTPClient.HTTPMethod('GET', AFrom, DS, [302, 200]);
      if FHTTPClient.ResponseStatusCode = 302 then
      begin
        x := FHTTPClient.GetHeader(FHTTPClient.ResponseHeaders, 'Location');
        x := StringReplace(x, ' ', '%20', [rfReplaceAll]);
      end;
      FHTTPClient.HTTPMethod('GET', x, DS, [200]);
    except
      on E: Exception do
      begin
        ShowMessage(e.Message);
      end;
    end;
  finally
    DS.Free;
    FHTTPClient.Free;

  end;

end;

function TForm1.FormatSize(aSize: int64): string;
const
  KB = 1024;
  MB = 1024 * KB;
  GB = 1024 * MB;
begin
  if aSize < KB then
    Result := FormatFloat('#,##0 Bytes', aSize)
  else if aSize < MB then
    Result := FormatFloat('#,##0.0 KB', aSize / KB)
  else if aSize < GB then
    Result := FormatFloat('#,##0.0 MB', aSize / MB)
  else
    Result := FormatFloat('#,##0.0 GB', aSize / GB);
end;

procedure TForm1.DoOnWriteStream(Sender: TObject; APosition: int64);
begin
  Label2.Caption := 'Downloading.... ' + FormatSize(APosition);
  Application.ProcessMessages;
end;

var
  targetDirectory: ansistring;
  baseurl, x1: string;
//--------------------------------------------------------------------------------------



procedure TForm1.ListBox1DrawItem(Control: TWinControl; Index: integer;
  ARect: TRect; State: TOwnerDrawState);
var
  aColor: TColor;                       //Background color
begin
  if (Index mod 2 = 0)                  //Index tells which item it is
  then
    aColor := $ffffff                //every second item gets white as the background color
  else
    aColor := $e1edf6;               //every second item gets pink background color
  if odSelected in State then
    aColor := $6aa8d4;  //If item is selected, then red as background color
  ListBox1.Canvas.Brush.Color := aColor;  //Set background color
  ListBox1.Canvas.FillRect(ARect);      //Draw a filled rectangle
  ListBox1.Canvas.TextRect(ARect, 2, ARect.Top + 2, ListBox1.Items[Index]);
  //Draw Itemtext
end;

procedure TForm1.Button2Click(Sender: TObject);      //search button
var
  page, bookname: ansistring;
  re: TRegExpr;
  n, n1, sum: integer;
  http1: TFPHTTPClient;
label
  here, sortlist;
begin
  Label2.Caption := 'Searching for your files......';
  ListBox1.Items.Clear;
  ListBox1.Enabled := False;
  form1.Cursor := crHourGlass;
  baseurl := 'https://www.pdfdrive.com/search?q=' + EncodeURL(Edit1.Text) +
    '&pagecount=&pubyear=&searchin=&more=true';
  http1 := TFPHttpClient.Create(nil);
  with http1 do
    try
      http1.AllowRedirect := True;
      page := http1.SimpleGet(baseUrl);// Find all book urls
    finally
      Free;
    end;
  n1 := GetLastPageNo(page);
  sum := 1;
  here:
    re := TRegExpr.Create('<a href="(.*?)" data-id="(.*?)".*?>');
  try
    if re.Exec(page) then
    begin
      while re.ExecNext do
      begin
        bookname := re.Match[1];
        if (RightStr(bookname, 4) = 'html') and (LeftStr(bookname, 1) = '/') then
          listbox1.items.add(bookname);
        Application.ProcessMessages;
      end;
    end;
  finally
    re.Free;
  end;
  baseurl := '';
  page := '';
  for n := 1 to n1 do
  begin
    sum := sum + n;
    if sum > n1 then
      goto sortlist;
    baseurl := ('https://www.pdfdrive.com/search?q=' + EncodeURL(
      Edit1.Text) + '&pagecount=&pubyear=&searchin=&page=' + IntToStr(sum));
    //page:=Getexplorer(baseurl);

    http1 := TFPHttpClient.Create(nil);
    with http1 do
      try
        http1.AllowRedirect := True;
        page := http1.SimpleGet(baseUrl);// Find all book urls
      finally
        Free;
      end;
    goto here;
  end;
  sortlist:
    Label2.Caption := 'You Got ' + IntToStr(ListBox1.Items.Count) +
      ' Books Enjoy downloading list below';
  ListBox1.Enabled := True;
  Form1.Cursor := crDefault;
end;

function TForm1.getrightfilename(x: string): string;
var
  xf: string;
  ndx, ndx2: integer;
begin
  ndx := x.IndexOf('/');
  ndx2 := x.IndexOf('-e', ndx);
  xf := x.Substring(ndx, ndx2 - ndx);
  xf := xf.Replace('-', ' ', [rfReplaceAll]);
  Result := xf.Replace('/', ' ', [rfReplaceAll]);

end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  targetDirectory := GetUserDir + 'downloads' + DirectorySeparator +
    'alaa' + DirectorySeparator;
  if not DirectoryExists(targetDirectory) then
    CreateDir(targetDirectory);
end;

function TForm1.GetLastPageNo(const anHTMLText: string): integer;    //new
var
  re1: TRegExpr;
begin
  Result := -1;
  re1 := TRegExpr.Create('&amp;page=(.*?)">');
  if re1.Exec(anHTMLText) then
    while re1.ExecNext do
      if StrToIntDef(re1.Match[1], 0) > Result then
        Result := StrToIntDef(re1.Match[1], 0);
  re1.Free;
end;


procedure TForm1.ListBox1Click(Sender: TObject);
var
  x2, x3: string;
begin
  Label2.Caption := 'Please be Patient while downloading your book';
  form1.Cursor := crHourGlass;
  ListBox1.Enabled := False;
  x1 := ListBox1.Items.Strings[ListBox1.ItemIndex];
  x3 := 'https://www.pdfdrive.com' + x1;
  x2 := get1webpage(x3);
  Download(x2, targetDirectory + getrightfilename(x1) + '.pdf');  // GetfileName(x1)
  x2 := '';
  Label2.Caption := 'Congratulations Done!';
  ListBox1.Enabled := True;
  form1.Cursor := crDefault;
  OpenDocument(targetDirectory);
end;

function tform1.get1webpage(url: string): string;          //required
var
  cli: TFPHTTPClient;
  html, previw, session: string;
  Mstream: TMemoryStream;
  ndx, ndx2: integer;
  sndx, sndx2: integer;
begin
  cli := TFPHTTPClient.Create(nil);
  Mstream := TMemoryStream.Create;
  cli.AllowRedirect := True;
  cli.AddHeader('User-Agent', 'Mozilla/5.0 (Compatible; fpweb)');
  cli.AddHeader('Accept',
    'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8');
  cli.AddHeader('Accept-Encoding', 'deflate');
  cli.AddHeader('Accept-Language', 'en-US,*');
  try
    cli.Get(url, Mstream);
    Mstream.Position := 0;
    SetLength(html, Mstream.Size);
    Mstream.ReadBuffer(html[1], Mstream.Size);
    if html.Contains('previewButtonMain') then
    begin
      ndx := html.IndexOf('preview?id=');
      ndx := html.IndexOf('=', ndx);
      ndx2 := html.IndexOf('&', ndx);
      previw := html.Substring(ndx, ndx2 - ndx);
      //------------
      sndx := html.IndexOf('session=');
      sndx := html.IndexOf('=', sndx);
      sndx2 := html.IndexOf('" data-download-page=', sndx);
      session := html.Substring(sndx, sndx2 - sndx);
      Result := 'https://www.pdfdrive.com/download.pdf?id' + previw + '&h' +
        session + '&u=cache&ext=pdf';
    end;
  except
    on E: EHttpclient do
    begin
      if IsConsole then
      else;
    end;
  end;
  Mstream.Free;
  cli.Free;
end;

end.
