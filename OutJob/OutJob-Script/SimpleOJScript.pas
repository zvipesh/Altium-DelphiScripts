{ SimpleOJScript.pas
  Usage:
     Script (.pas file) must be part of a board project (does not need to be in same folder)
     .pas & .dfm must be in same folder.
     Add script to OutJob Reports Output/Scripts Output..
     Set Names & paths as usual: RMB Configure, Change Generate.

 Summary
     Example of OutJob script interaction.
     Supports the Configure Change & Generate functions of OutJob.

     ONLY supports use of FIXED output filenames; NO container or type or parameter names.

     Change: supports Open & Add outputs to project & custom output paths & filename
     Configure: supports passing source document static/stored parameter thru' to Generate
     Main code block can be tested outside OutJob by using DirectCall()

Notes:
    Scripts in same project then all have public fn()s & procedures.
    So can can keep this code separate (reusable) from main working script.
    The code is separated by function as much as possible?
    OutJob functions are self contained at bottom apart from one call to get SourceDocument via form UI.
    Configure form is potentially not required but there is no other source doc picking mechanism
    Can't see a way to display the chosen source document yet.
    Could be expanded to add other parameters
    Can test the form UI by removing (dummy : boolean) parameter & calling direct outside of OutJob.
    May or may not need the Script project to run outside of OutJob (which is in a project)

    ONLY supports use of FIXED output filenames; NO container or type or parameter names.


B.L. Miller
21/08/2018  v0.1  intial
15/12/2018  v0.2  add outjob entry points WIP..
17/07/2019  v0.3  Tidy up parameters, pass sourcedoc to Generate() fn.
18/07/2019  v0.4  Added Configure form
18/03/2020  v0.41 Fix missing user parameter when Configure is not run (at least once) before Generate
18/03/2020  v0.42 Attempt support for relative path ticked in Change.
20/03/2020  v0.43 Add text to Summary & Notes.
09/04/2020  v0.44 Change from fn to proc form of methods for ParameterList.
..............................................................................}

Interface    // not sure this is not just ignored in delphiscript.
type
    TFormPickFromList = class(TForm)
    ButtonExit        : TButton;
    ComboBoxFiles     : TComboBox;
    procedure FormPickFromListCreate(Sender: TObject);
    procedure ButtonExitClick(Sender: TObject);
end;

Const
    cDefaultReportFileName   = 'OJScript-Report.txt';    //default output report name.
    cSourceFileNameParameter = 'SourceFileName';         // Parameter Name to store static data from configure
    cSourceFileName          = 'dummy.PcbDoc';

Var
    WS               : IWorkspace;
    Doc              : IDocument;
    FilePath         : WideString;
    Prj              : IBoardProject;
    Board            : IPCB_Board;
    PrjReport        : TStringList;
    FormPickFromList : TFormPickFromList;

{..............................................................................}

Procedure ReportPCBStuff (SourceFileName : WideString, const ReportFileName : WideString, const AddToProject : boolean, const OpenOutputs : boolean);
var
    ReportDocument : IServerDocument;
    I              : Integer;

Begin
    WS  := GetWorkspace;
    if WS = Nil Then Exit;
    Prj := WS.DM_FocusedProject;
    if Prj = Nil then exit;

//    PrimDoc := Prj.DM_PrimaryImplementationDocument;
//    if Primdoc = Nil then
//        exit
//    else
//        Board := PCBServer.GetPCBBoardByPath(PrimDoc.DM_FullPath);
//    if Board = Nil then exit;
    BeginHourGlass(crHourGlass);

    for I := 0 to (Prj.DM_LogicalDocumentCount - 1) do
    begin
        Doc := Prj.DM_LogicalDocuments(I);
        if Doc.DM_FileName = SourceFilename then
        begin
            break;
        end;
    end;

    PrjReport  := TStringList.Create;
    PrjReport.Add('Information:');
    PrjReport.Add('  Project : ' + Prj.DM_ProjectFileName);
    FilePath := ExtractFilePath(Prj.DM_ProjectFullPath);
    PrjReport.Add('  Path    : ' + FilePath);

    if (Doc.DM_FileName = SourceFileName) then
    begin
        PrjReport.Add('  SourceFileName : ' + SourceFileName);

        if (Doc.DM_DocumentKind = cDocKind_Pcb)then
        begin
            Board := PCBServer.GetPCBBoardByPath(Doc.DM_FullPath);
            if Board = Nil then
                Board := PCBServer.LoadPCBBoardByPath(Doc.DM_FullPath);
            PrjReport.Add('  Board   : ' + Board.FileName);
            PrjReport.Add('');
        end;

        if (Doc.DM_DocumentKind = cDocKind_Sch)then
        begin

            PrjReport.Add('  do something SchDoc-ish');

        end;
    end
    else
    begin
        PrjReport.Add(' Source Doc NOT found');
    end;

    PrjReport.Add('===========  EOF  ==================================');

    FilePath := ExtractFilePath(ReportFileName);
    if not DirectoryExists(FilePath) then
        DirectoryCreate(FilePath);

    PrjReport.SaveToFile(ReportFileName);

    EndHourGlass;

    if AddToProject then Prj.DM_AddSourceDocument(ReportFileName);
    if OpenOutputs then
    begin
        ReportDocument := Client.OpenDocument('Text', ReportFileName);
        If ReportDocument <> Nil Then
            Client.ShowDocument(ReportDocument);
    end;
End;

procedure DirectCall;      // test outside of OutJob
var
    FileName : WideString;
begin
    If PCBServer = Nil Then Exit;
    Board := PCBServer.GetCurrentPCBBoard;
    If Board = Nil Then Exit;

    FilePath := ExtractFilePath(Board.FileName) + 'Script_Direct_Output\';
    FileName := ExtractFileName(Board.FileName);
    ReportPCBStuff(FileName, FilePath + cDefaultReportFileName, true, true);
end;

procedure SetupComboBoxFromProject(ComboBox : TComboBox; Prj : IProject);
var
    i : integer;
begin
    ComboBox.Items.Clear;
    for i := 0 to (Prj.DM_LogicalDocumentCount - 1) Do
    begin
        Doc := Prj.DM_LogicalDocuments(i);
//        If Doc.DM_DocumentKind = cDocKind_Pcb Then
        ComboBoxFiles.Items.Add(Doc.DM_FileName);
    end;
end;

function PickSourceDoc(const dummy : boolean) : WideString;
begin
    FormPickFromList.ShowModal;
    Result:= FormPickFromList.ComboBoxFiles.Items(ComboBoxFiles.ItemIndex);
    if Result = '' then
        Result := GetWorkSpace.DM_FocusedProject.DM_PrimaryImplementationDocument.DM_FileName;
end;

procedure testform(dummy : boolean);      // test the Form events work by removing dummy parameter
var
   FName : WideString;
begin
    FormPickFromList.ShowModal;
    FName := FormPickFromList.ComboBoxFiles.Items(ComboBoxFiles.ItemIndex);
    ShowMessage('picked ' + FName);
end;

procedure TFormPickFromList.FormPickFromListCreate(Sender: TObject);
var
    Prj : IProject; 

begin
    Prj := GetWorkSpace.DM_FocusedProject;
    SetupComboBoxFromProject(ComboBoxFiles, Prj);
end;

Procedure TFormPickFromList.ButtonExitClick(Sender: TObject);
Begin
    Close;
End;


// ------------  OutJob entry points   ----------------------------------------------
// OutJob RMB menu Configure
// seems to pass in focused PcbDoc filename.
Function Configure(Parameter : String) : String;
var
    ParamList      : TParameterList;
    SourceFileName : WideString;

begin
    ParamList := TParameterList.Create;
    ParamList.ClearAllParameters;
    ParamList.SetState_FromString(Parameter);

    SourceFileName := PickSourceDoc(false);
    ParamList.SetState_AddOrReplaceParameter(cSourceFileNameParameter, SourceFileName, true);

    Result := ParamList.GetState_ToString;
    ParamList.Destroy;
end;

// OutJob Output Container "change"
Function PredictOutputFileNames(Parameter : String) : String;
var
    ParamList    : TParameterList;
    bValue       : boolean;
    TargetFolder : WideString;
    TargetFN     : WideString;
    TargetPrefix : WideString;

begin
    // Parameter == TargetFolder=   TargetFileName=    TargetPrefix=   OpenOutputs=(boolean)   AddToProject=(boolean)
    ParamList := TParameterList.Create;
    ParamList.ClearAllParameters;
    ParamList.SetState_FromString(Parameter);

    TargetFolder := '';
    ParamList.GetState_ParameterAsString('TargetFolder', TargetFolder);
    TargetPrefix := '';
    ParamList.GetState_ParameterAsString('TargetPrefix', TargetPrefix);
    TargetFN := '';
    ParamList.GetState_ParameterAsString('TargetFileName', TargetFN);

    ParamList.Destroy;

    if TargetFN = '' then TargetFN := cDefaultReportFileName;
    Result := TargetFN;
end;

// OutJob Generate Output Button
Function Generate(Parameter : String) : String;
// Parameter == TargetFolder=   TargetFileName=    TargetPrefix=   OpenOutputs=(boolean)   AddToProject=(boolean)
var
    ParamList  : TParameterList;
    SourceFileName : WideString;
    TargetFolder   : WideString;
    TargetFN       : WideString;
    TargetPrefix   : WideString;
    tmpstr         : WideString;
    I              : integer;
    AddToProject   : boolean;
    OpenOutputs    : boolean;

begin
    ParamList := TParameterList.Create;
    ParamList.ClearAllParameters;
    ParamList.SetState_FromString(Parameter);

    TargetFolder := '';
    ParamList.GetState_ParameterAsString('TargetFolder', TargetFolder);
    TargetFN := '';
    ParamList.GetState_ParameterAsString('TargetFileName', TargetFN);

    TargetPrefix := '';
    ParamList.GetState_ParameterAsString('TargetPrefix', TargetPrefix);

    OpenOutputs := false;
    tmpstr := 'false';
    ParamList.GetState_ParameterAsString('OpenOutputs', tmpstr);
    Str2Bool(tmpstr, OpenOutputs);

    AddToProject := false;
    tmpstr := 'false';
    ParamList.GetState_ParameterAsString('AddToProject', tmpstr);
    Str2Bool(tmpstr, AddToProject);

    ParamList.GetState_ParameterAsString(cSourceFileNameParameter, SourceFileName);
    if SourceFileName = '' then
        ParamList.SetState_AddOrReplaceParameter(cSourceFileNameParameter, cSourceFileName, true);

    ParamList.Destroy;

    if TargetFolder = '' then
        TargetFolder := ExtractFilePath( GetWorkspace.DM_FocusedProject );
// if output filename is NOT changed from default then Parameter TargetFileName = ''  dumb yeah.
    if TargetFN = '' then
        TargetFN := cDefaultReportFileName;

// if TargetFd contains '.\' then is encoded as resolved relative path.
    tmpstr := TargetFolder;
    I := ansipos('.\', TargetFolder);
    if I > 3 then
    begin
        SetLength(tmpstr, I - 1);
        Delete(TargetFolder, 1, I + 1);
        tmpstr := tmpstr + TargetFolder;
        TargetFolder := tmpstr;
    end;

    TargetFN := TargetFolder + TargetFN;
    ReportPCBStuff(SourceFileName, TargetFN, AddToProject, OpenOutputs);

//   Parameter := 'simple string returned';
   Result := 'done';  //'simple string returned';
end;

