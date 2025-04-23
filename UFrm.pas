{------------------------------------------------------------------------------
Component Installer app
Developed by Rodrigo Depine Dalpiaz (digao dalpiaz)
Delphi utility app to auto-install component packages into IDE

https://github.com/digao-dalpiaz/CompInstall

Please, read the documentation at GitHub link.
------------------------------------------------------------------------------}

unit UFrm;

interface

uses Vcl.Forms, Vcl.ExtCtrls, Vcl.StdCtrls, Vcl.ComCtrls, Vcl.Buttons,
  Vcl.Controls, System.Classes, System.IOUtils,
  //
  Vcl.Graphics, UDefinitions;

type
  TFrm = class(TForm)
    LbComponentName: TLabel;
    EdCompName: TEdit;
    LbDelphiVersion: TLabel;
    EdDV: TComboBox;
    Ck64bit: TCheckBox;
    LbInstallLog: TLabel;
    BtnInstall: TBitBtn;
    BtnExit: TBitBtn;
    M: TRichEdit;
    LbVersion: TLabel;
    LbDigaoDalpiaz: TLinkLabel;
    LbComponentVersion: TLabel;
    EdCompVersion: TEdit;
    lnklbl1: TLinkLabel;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure BtnExitClick(Sender: TObject);
    procedure BtnInstallClick(Sender: TObject);
    procedure LbDigaoDalpiazLinkClick(Sender: TObject; const Link: string;
      LinkType: TSysLinkType);
    procedure FormShow(Sender: TObject);
  private
    D: TDefinitions;
    DefLoaded: Boolean;
  public
    procedure LoadDefinitions;
    procedure SetNewPackageVersion;
    procedure SetButtons(bEnabled: Boolean);
    procedure Log(const A: string; bBold: Boolean = True; Color: TColor = clBlack);
  end;

var
  Frm: TFrm;
  G_NewVersion : string;

implementation

{$R *.dfm}

uses System.SysUtils, Vcl.Dialogs, System.UITypes,
  Winapi.Windows, Winapi.Messages, Winapi.ShellAPI,
  UCommon, UProcess, UGitHub, UDelphiVersionCombo;

procedure TFrm.Log(const A: string; bBold: Boolean = True; Color: TColor = clBlack);
begin
  //log text at RichEdit control, with some formatted rules

  M.SelStart := Length(M.Text);

  if bBold then
    M.SelAttributes.Style := [fsBold]
  else
    M.SelAttributes.Style := [];

  M.SelAttributes.Color := Color;

  M.SelText := A+#13#10;

  SendMessage(M.Handle, WM_VSCROLL, SB_BOTTOM, 0); //scroll to bottom
end;

procedure TFrm.LoadDefinitions;
begin
  if G_NewVersion <> '' then
  begin
    if Assigned(D) then
    begin
      Log('Write Updated Component Version to INI File...');
      SetNewPackageVersion;
    end;
  end;
  if Assigned(D) then D.Free;

  DefLoaded := False;

  D := TDefinitions.Create;
  try
    D.LoadIniFile(TPath.Combine(TPath.GetAppPath, INI_FILE_NAME));

    EdCompName.Text := D.CompName;
    EdCompVersion.Text := D.CompVersion;

    TDelphiVersionComboLoader.Load(EdDV, D.DelphiVersions);

    Ck64bit.Visible := D.HasAny64bit;

    DefLoaded := True;
  except
    on E: Exception do
      Log('Error loading component definitions: '+E.Message, True, clRed);
  end;
end;

procedure TFrm.FormCreate(Sender: TObject);
begin
  ReportMemoryLeaksOnShutdown := True;

  AppDir := ExtractFilePath(Application.ExeName);
  G_NewVersion := '';
  LoadDefinitions;
end;

procedure TFrm.FormDestroy(Sender: TObject);
begin
  D.Free;
  TDelphiVersionComboLoader.Clear(EdDV);
end;

procedure TFrm.FormShow(Sender: TObject);
begin
  if DefLoaded then
    CheckGitHubUpdate(D.GitHubRepository, D.CompVersion);
end;

procedure TFrm.LbDigaoDalpiazLinkClick(Sender: TObject; const Link: string;
  LinkType: TSysLinkType);
begin
  ShellExecute(0, '', PChar(Link), '', '', SW_SHOWNORMAL);
end;

procedure TFrm.BtnExitClick(Sender: TObject);
begin
  Close;
end;

procedure TFrm.BtnInstallClick(Sender: TObject);
var
  P: TProcess;
  LDelphiVersion : string;
begin
  if not DefLoaded then
    raise Exception.Create('Component definitions are not loaded');

  M.Clear; //clear log

  if EdDV.ItemIndex=-1 then
  begin
    MessageDlg('Select one Delphi version', mtError, [mbOK], 0);
    EdDV.SetFocus;
    Exit;
  end;

  //check if Delphi IDE is running
  if FindWindow('TAppBuilder', nil)<>0 then
  begin
    MessageDlg('Please, close Delphi IDE first!', mtError, [mbOK], 0);
    Exit;
  end;

  SetButtons(False);
  Refresh;
  // Here we know about the selected Delphi Version
  //LDelphiVersion := EdDV.Items[EdDV.ItemIndex]; // Long Delphi Name, not Tag from INI File
  //LDelphiVersion := TDelphiVersionItem(EdDV.Items.Objects[EdDV.ItemIndex]).InternalNumber;  // Version 23.0 for Delphi 12
  LDelphiVersion := TDelphiVersionItem(EdDV.Items.Objects[EdDV.ItemIndex]).Iniver;

  // Reload Packages to get version specific sections

  Log('Reload Packages to get Delphi Version specific Settings with Delphi suffix: ' + LDelphiVersion);
  D.ReloadPackages(TPath.Combine(TPath.GetAppPath,INI_FILE_NAME),LDelphiVersion);

  P := TProcess.Create(D,
    TDelphiVersionItem(EdDV.Items.Objects[EdDV.ItemIndex]).InternalNumber,
    Ck64bit.Checked and Ck64bit.Visible);

  P.Start;
end;

procedure TFrm.SetButtons(bEnabled: Boolean);
begin
  BtnInstall.Enabled := bEnabled;
  BtnExit.Enabled := bEnabled;
end;

procedure TFrm.SetNewPackageVersion;
begin
  if D.AutoUpdateIniFile then
  begin
    if D.CompVersion <> G_NewVersion then
    begin
      D.UpdatedVersion := G_NewVersion;
      G_NewVersion := '';
    end;
  end;
end;

end.
