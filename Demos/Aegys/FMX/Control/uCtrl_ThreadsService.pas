unit uCtrl_ThreadsService;

{
 Project Aegys Remote Support.

   Created by Gilberto Rocha da Silva in 04/05/2017 based on project Allakore, has by objective to promote remote access
 and other resources freely to all those who need it, today maintained by a beautiful community. Listing below our
 higly esteemed collaborators:

  Gilberto Rocha da Silva (XyberX) (Creator of Aegys Project/Main Developer/Admin)
  Wendel Rodrigues Fassarella (wendelfassarella) (Creator of Aegys FMX/CORE Developer)
  Rai Duarte Jales (Ra� Duarte) (Aegys Server Developer)
  Roniery Santos Cardoso (Aegys Developer)
  Alexandre Carlos Silva Abade (Aegys Developer)
  Mobius One (Aegys Developer)
}

interface

uses
  System.Classes, System.Win.ScktComp, uConstants, System.SyncObjs, VCL.Forms, Windows;

type
  TThreadBase = class(TThread)
  private
    FTipo: IDThreadType;
    arrAcessos: array of TCustomWinSocket;
    FProtocolo: string;
  public
    scClient: TCustomWinSocket;
    constructor Create(ASocket: TCustomWinSocket; AProtocolo: string); overload; virtual;
    function GetAcesso(AHandle: Integer): TCustomWinSocket;
    function LengthAcessos: Integer;
    procedure Execute; override;
    procedure RemoverAcesso(AHandle: Integer);
    procedure SetAcesso(ASocket: TCustomWinSocket);
    procedure ThreadTerminate(ASender: TObject); virtual;
  end;

  TThreadConexaoDefinidor = class(TThread)
  private
    scClient: TCustomWinSocket;
  public
    constructor Create(ASocket: TCustomWinSocket); overload;
    procedure Execute; override;
  end;

  TThreadConexaoPrincipal = class(TThreadBase)
  public
    constructor Create(ASocket: TCustomWinSocket; AProtocolo: string); override;
    procedure Execute; override;
    procedure LimparAcessos;
    procedure ThreadTerminate(ASender: TObject); override;
  end;

  TThreadConexaoAreaRemota = class(TThreadBase)
  public
    constructor Create(ASocket: TCustomWinSocket; AProtocolo: string); override;
  end;

  TThreadConexaoTeclado = class(TThreadBase)
  public
    constructor Create(ASocket: TCustomWinSocket; AProtocolo: string); override;
  end;

  TThreadConexaoArquivos = class(TThreadBase)
  public
    constructor Create(ASocket: TCustomWinSocket; AProtocolo: string); override;
  end;

 Procedure Delay(msecs : Cardinal);

implementation

{ TThreadConexaoDefinidor }

uses System.SysUtils, uCtrl_Conexoes, uDMServer, Vcl.Dialogs;

{ TThreadConexaoDefinidor }

Procedure Delay(msecs : Cardinal);
Var
 FirstTickCount: Cardinal;
Begin
 FirstTickCount := GetTickCount;
 Repeat
  Application.ProcessMessages;
 Until ((GetTickCount - FirstTickCount) >= msecs);
End;

constructor TThreadConexaoDefinidor.Create(ASocket: TCustomWinSocket);
begin
  inherited Create(True);
  scClient := ASocket;
  FreeOnTerminate := True;
  Resume;
end;

procedure TThreadConexaoDefinidor.Execute;
var
 xBuffer,
 xBufferTemp,
 xValue,
 xID,
 xMAC,
 xHD,
 xUser,
 xSenha,
 xSenhaGerada  : String;
 iPosition   : Integer;
begin
  inherited;

  while (Not (Terminated)) do
  begin
    Sleep(FOLGAPROCESSAMENTO);

    if (scClient = nil)
      or not(scClient.Connected)
      or not(Assigned(DMServer)) then
      Break;

    if scClient.ReceiveLength < 1 then
      Continue;

    xBuffer := scClient.ReceiveText;

    iPosition := Pos('<|MAINSOCKET|>', xBuffer);
    if iPosition > 0 then
    Begin
     If Pos('<|MAC|>', xBuffer) > 0 Then
      Begin
       xValue := xBuffer;
       Delete(xValue, 1, Pos('<|MAC|>', xValue)+ 6);
       xMAC := xValue;
       xMAC := Copy(xMAC, 1, Pos('<|>', xMAC) - 1);
       Delete(xValue, 1, Pos('<|>', xValue) + 2);
       Delete(xValue, 1, Pos('<|HD|>', xValue)+ 5);
       xHD := xValue;
       xHD := Copy(xHD, 1, Pos('<|>', xHD) - 1);
       Delete(xValue, 1, Pos('<|>', xValue) + 2);
       Delete(xValue, 1, Pos('<|USER|>', xValue) + 7);
       xUser := xValue;
       xUser := Copy(xUser, 1, Pos('<|>', xUser) - 1);
       Delete(xValue, 1, Pos('<|>', xValue) + 2);

       Delete(xValue, 1, Pos('<|SENHADEFINIDA|>', xValue)+ 16);
       xSenha := xValue;
       xSenha := Copy(xSenha, 1, Pos('<|>', xSenha) - 1);
       Delete(xValue, 1, Pos('<|>', xValue) + 2);

       Delete(xValue, 1, Pos('<|SENHAGERADA|>', xValue)+ 14);
       xSenhaGerada := xValue;
       xSenhaGerada := Copy(xSenhaGerada, 1, Pos('<|>', xSenha) - 1);
       xValue := '';
       DMServer.Conexoes.AdicionarConexao(IntToStr(scClient.Handle), XMac, XHD, xUser, XSenha);
      End;
//     Else
//      DMServer.Conexoes.AdicionarConexao(IntToStr(scClient.Handle));
     DMServer.Conexoes.RetornaItemPorConexao(IntToStr(scClient.Handle)).CriarThread(ttPrincipal, scClient);
     Break;
    End;

    iPosition := Pos('<|DESKTOPSOCKET|>', xBuffer);
    if iPosition > 0 then
    begin
      xBufferTemp := xBuffer;
      Delete(xBufferTemp, 1, iPosition + (Length('<|DESKTOPSOCKET|>') -1));
      xID := Copy(xBufferTemp, 1, Pos('<|END|>', xBufferTemp) - 1);
      DMServer.Conexoes.RetornaItemPorID(xID).CriarThread(ttAreaRemota, scClient);
      Break;
    end;

    iPosition := Pos('<|KEYBOARDSOCKET|>', xBuffer);
    if iPosition > 0 then
    begin
      xBufferTemp := xBuffer;
      Delete(xBufferTemp, 1, iPosition + 17);
      xID := Copy(xBufferTemp, 1, Pos('<|END|>', xBufferTemp) - 1);
      DMServer.Conexoes.RetornaItemPorID(xID).CriarThread(ttTeclado, scClient);
      Break;
    end;

    iPosition := Pos('<|FILESSOCKET|>', xBuffer);
    if iPosition > 0 then
    begin
      xBufferTemp := xBuffer;
      Delete(xBufferTemp, 1, Pos('<|FILESSOCKET|>', xBuffer) + 14);
      xID := Copy(xBufferTemp, 1, Pos('<|END|>', xBufferTemp) - 1);
      DMServer.Conexoes.RetornaItemPorID(xID).CriarThread(ttArquivos, scClient);
      Break;
    end;
  end;
end;

{ TThreadBase }

function TThreadBase.LengthAcessos: Integer;
begin
  Result := Length(arrAcessos);
end;

procedure TThreadBase.RemoverAcesso(AHandle: Integer);
var
  i: Integer;
begin
  for i := Low(arrAcessos) to High(arrAcessos) do
  begin
    if (Assigned(arrAcessos[i])) and (AHandle = arrAcessos[i].Handle) then
    begin
      if LengthAcessos = 1 then
        scClient.SendText('<|DISCONNECTED|>');
      arrAcessos[i] := nil;
    end;
  end;
end;

constructor TThreadBase.Create(ASocket: TCustomWinSocket; AProtocolo: string);
begin
  inherited Create(True);
  FProtocolo := AProtocolo;
  scClient := ASocket;
  FreeOnTerminate := True;
  OnTerminate := ThreadTerminate;
  Resume;
end;

procedure TThreadBase.Execute;
var
  xBuffer: string;
  i: Integer;
begin
  inherited;

  while (Not (Terminated)) do
  begin
    Sleep(FOLGAPROCESSAMENTO);
    Try
     if (scClient = nil) Then
      Break;
     if not(scClient.Connected)
       or (Terminated)
       or not(Assigned(DMServer)) then
       Break;
     if scClient.ReceiveLength < 1 then
       Continue;
     xBuffer := scClient.ReceiveText;
     for i := Low(arrAcessos) to High(arrAcessos) do
     begin
       if (Assigned(arrAcessos[i])) and (arrAcessos[i].Connected) then
       begin
         while arrAcessos[i].SendText(xBuffer) < 0 do
           Sleep(FOLGAPROCESSAMENTO);
       end;
     end;
    Except
     //log de erros
    End;
  end;
end;

function TThreadBase.GetAcesso(AHandle: Integer): TCustomWinSocket;
var
  i: Integer;
begin
  Result := nil;
  for i := Low(arrAcessos) to High(arrAcessos) do
  begin
    if (Assigned(arrAcessos[i])) and (AHandle = arrAcessos[i].Handle) then
    begin
      Result := arrAcessos[i];
      Break;
    end;
  end;
end;

procedure TThreadBase.SetAcesso(ASocket: TCustomWinSocket);
var
  i: Integer;
  bAchou: Boolean;
begin
  bAchou := False;
  for i := Low(arrAcessos) to High(arrAcessos) do
  begin
    if (Assigned(arrAcessos[i])) and (arrAcessos[i].Handle = ASocket.Handle) then
      bAchou := True;
  end;

  if not bAchou then
  begin
    i := Length(arrAcessos) + 1;
    SetLength(arrAcessos, i);
    arrAcessos[High(arrAcessos)] := ASocket;
  end;
 Application.ProcessMessages;
end;

procedure TThreadBase.ThreadTerminate(ASender: TObject);
begin
  if (Assigned(DMServer)) and (not Terminated) then
    DMServer.Conexoes.RetornaItemPorConexao(FProtocolo).LimparThread(FTipo);
end;

{ TThreadConexaoPrincipal }

constructor TThreadConexaoPrincipal.Create(ASocket: TCustomWinSocket; AProtocolo: string);
begin
  FTipo := ttPrincipal;
  inherited;
end;

procedure TThreadConexaoPrincipal.Execute;
var
  xBuffer,
  xValue,
  xBufferTemp,
  xID,
  xIDAcesso,
  xSenhaAcesso: string;
  iPosition: Integer;
  FConexao, FConexaoAcesso: TConexao;
  i: Integer;
  vCriticalSection : TCriticalSection;
begin
  FConexao := DMServer.Conexoes.RetornaItemPorConexao(FProtocolo);

  while scClient.SendText('<|ID|>' + FConexao.ID + '<|>' + FConexao.Senha + '<|>' + FConexao.SenhaGerada + '<|END|>') < 0 do
    Begin
     Sleep(FOLGAPROCESSAMENTO);
     Application.ProcessMessages;
    End;

  while (Not (Terminated)) do
  begin
    Sleep(FOLGAPROCESSAMENTO);

    if (scClient = nil)
      or not(scClient.Connected)
      or (Terminated)
      or not(Assigned(DMServer)) then
      Break;

    if scClient.ReceiveLength < 1 then
      Continue;

    xBuffer := scClient.ReceiveText;

    iPosition := Pos('<|FINDID|>', xBuffer);
    if iPosition > 0 then
    begin
      xBufferTemp := xBuffer;
      Delete(xBufferTemp, 1, iPosition + 9);
      xIDAcesso := Copy(xBufferTemp, 1, Pos('<|END|>', xBufferTemp) - 1);

      if DMServer.Conexoes.VerificaID(xIDAcesso) then
      begin
        while scClient.SendText('<|IDEXISTS!REQUESTPASSWORD|>') < 0 do
          Sleep(FOLGAPROCESSAMENTO);
      end
      else
      begin
        while scClient.SendText('<|IDNOTEXISTS|>') < 0 do
          Sleep(FOLGAPROCESSAMENTO);
      end;
    end;

    if xBuffer.Contains('<|PONG|>') then
      FConexao.PingFinal := GetTickCount - FConexao.PingInicial;

    iPosition := Pos('<|CHECKIDPASSWORD|>', xBuffer);
    if iPosition > 0 then
    begin
      xIDAcesso := '';
      xSenhaAcesso := '';

      xBufferTemp := xBuffer;
      Delete(xBufferTemp, 1, iPosition + 18);
      iPosition := Pos('<|>', xBufferTemp);
      xIDAcesso := Copy(xBufferTemp, 1, iPosition - 1);

      Delete(xBufferTemp, 1, iPosition + 2);
      xSenhaAcesso := Copy(xBufferTemp, 1, Pos('<|END|>', xBufferTemp) - 1);

      if (DMServer.Conexoes.VerificaIDSenha(xIDAcesso, xSenhaAcesso)) then
      begin
        while scClient.SendText('<|ACCESSGRANTED|>') < 0 do
          Sleep(FOLGAPROCESSAMENTO);
      end
      else
      begin
        while scClient.SendText('<|ACCESSDENIED|>') < 0 do
          Sleep(FOLGAPROCESSAMENTO);
      end;
    end;
   iPosition := Pos('<|GETMONITORCOUNT|>', xBuffer);
   if iPosition > 0 then
    Begin
     xID := '';
     xIDAcesso := '';
     xBufferTemp := xBuffer;
     Delete(xBufferTemp, 1, iPosition + Length('<|GETMONITORCOUNT|>') -1);
     iPosition := Pos('<|>', xBufferTemp);
     xID := Copy(xBufferTemp, 1, iPosition - 1);
     Delete(xBufferTemp, 1, iPosition + 2);
     xIDAcesso := Copy(xBufferTemp, 1, Pos('<|END|>', xBufferTemp) - 1);
     FConexaoAcesso := nil;
     FConexaoAcesso := DMServer.Conexoes.RetornaItemPorID(xIDAcesso);
     FConexaoAcesso.ThreadPrincipal.scClient.SendText('<|GETMONITORCOUNT|>' + xID + '<|END|>');
    End;
   iPosition := Pos('<|CHANGEMONITOR|>', xBuffer);
   if iPosition > 0 then
    Begin
     xID := '';
     xIDAcesso := '';
     xBufferTemp := xBuffer;
     Delete(xBufferTemp, 1, iPosition + Length('<|CHANGEMONITOR|>') -1);
     iPosition := Pos('<|>', xBufferTemp);
     xID := Copy(xBufferTemp, 1, iPosition - 1);
     Delete(xBufferTemp, 1, iPosition + 2);
     xIDAcesso := Copy(xBufferTemp, 1, Pos('<|END|>', xBufferTemp) - 1);
     FConexaoAcesso := nil;
     FConexaoAcesso := DMServer.Conexoes.RetornaItemPorID(xID);
     FConexaoAcesso.ThreadPrincipal.scClient.SendText('<|CHANGEMONITOR|>' + xIDAcesso + '<|END|>');
    End;
   iPosition := Pos('<|MONITORS|>', xBuffer);
   if iPosition > 0 then
    Begin
     xID := '';
     xIDAcesso := '';
     xBufferTemp := xBuffer;
     Delete(xBufferTemp, 1, iPosition + Length('<|MONITORS|>') -1);
     iPosition := Pos('<|>', xBufferTemp);
     xID := Copy(xBufferTemp, 1, iPosition - 1);
     Delete(xBufferTemp, 1, iPosition + 2);
     xIDAcesso := Copy(xBufferTemp, 1, Pos('<|END|>', xBufferTemp) - 1);
     FConexaoAcesso := nil;
     FConexaoAcesso := DMServer.Conexoes.RetornaItemPorID(xID);
     FConexaoAcesso.ThreadPrincipal.scClient.SendText('<|MONITORS|>' + xIDAcesso + '<|END|>');
    End;
    iPosition := Pos('<|RELATION|>', xBuffer);
    if iPosition > 0 then
    begin
      xID := '';
      xIDAcesso := '';
      xValue    := '';
      xBufferTemp := xBuffer;
      If Pos('<|BESTQ|>', xBufferTemp) > 0 Then
       Begin
        xValue := Copy(xBufferTemp, Pos('<|BESTQ|>', xBufferTemp) + 9, 1);
        Delete(xBufferTemp, Pos('<|BESTQ|>', xBufferTemp), 19);
       End;
      Delete(xBufferTemp, 1, iPosition + 11);
      iPosition      := Pos('<|>', xBufferTemp);
      xID            := Copy(xBufferTemp, 1, iPosition - 1);
      Delete(xBufferTemp, 1, iPosition + 2);
      xIDAcesso      := Copy(xBufferTemp, 1, Pos('<|>', xBufferTemp) - 1);
      FConexao       := Nil;
      FConexaoAcesso := Nil;
      // RECONNECT SOCKET CLIENT
      FConexao       := DMServer.Conexoes.RetornaItemPorID(xID);
      FConexaoAcesso := DMServer.Conexoes.RetornaItemPorID(xIDAcesso);
      Application.Processmessages;
      FConexao.ThreadPrincipal.SetAcesso(FConexaoAcesso.SocketPrincipal);
      FConexaoAcesso.ThreadPrincipal.SetAcesso(FConexao.SocketPrincipal);
      If Assigned(FConexaoAcesso.SocketAreaRemota) Then
       If Assigned(FConexao.ThreadAreaRemota) Then
        FConexao.ThreadAreaRemota.SetAcesso(FConexaoAcesso.SocketAreaRemota);
      If Assigned(FConexao.SocketAreaRemota) Then
       If Assigned(FConexaoAcesso.ThreadAreaRemota) Then
        FConexaoAcesso.ThreadAreaRemota.SetAcesso(FConexao.SocketAreaRemota);
      If Assigned(FConexaoAcesso.SocketTeclado) Then
       If Assigned(FConexao.ThreadTeclado) Then
        FConexao.ThreadTeclado.SetAcesso(FConexaoAcesso.SocketTeclado);
      If Assigned(FConexaoAcesso.SocketArquivos) Then
       If Assigned(FConexao.ThreadArquivos) Then
        FConexao.ThreadArquivos.SetAcesso(FConexaoAcesso.SocketArquivos);
      If Assigned(FConexao.SocketArquivos) Then
       If Assigned(FConexaoAcesso.ThreadArquivos) Then
        FConexaoAcesso.ThreadArquivos.SetAcesso(FConexao.SocketArquivos);
      Synchronize(Procedure
                  Begin
                   If Assigned(FConexaoAcesso.ThreadPrincipal) Then
                    If Assigned(FConexaoAcesso.ThreadPrincipal.scClient) Then
                     Begin
                      FConexaoAcesso.ThreadPrincipal.scClient.SendText('<|ACCESSING|>');
                      Application.Processmessages;
                      If xValue <> '' Then
                       FConexaoAcesso.ThreadAreaRemota.scClient.SendText('<|GETFULLSCREENSHOT|><|BESTQ|>' + xValue + '<|END|>')
                      Else
                       FConexaoAcesso.ThreadAreaRemota.scClient.SendText('<|GETFULLSCREENSHOT|>');
                     End;
                  End);
    end;

    // Stop relations
    if xBuffer.Contains('<|STOPACCESS|>') then
    begin
      LimparAcessos;
      //wendel: erro aqui, quando eu envio o disconnect para quem fechou o acesso, quem ainda est� acessando perde as imagens e n�o volta mais
//      scClient.SendText('<|DISCONNECTED|>');
    end;

    // Redirect commands
    iPosition := Pos('<|REDIRECT|>', xBuffer);
    if iPosition > 0 then
    begin
      xBufferTemp := xBuffer;
      Delete(xBufferTemp, 1, iPosition + 11);

      if (Pos('<|FOLDERLIST|>', xBufferTemp) > 0) then
      begin
        while (scClient.Connected) and (Not (Terminated)) do
        begin
          Sleep(FOLGAPROCESSAMENTO); // Avoids using 100% CPU

          if (Pos('<|END_FOLDERLIST|>', xBufferTemp) > 0) then
            Break;

          xBufferTemp := xBufferTemp + scClient.ReceiveText;
        end;
      end;

      if (Pos('<|FILESLIST|>', xBufferTemp) > 0) then
      begin
        while (scClient.Connected) and (Not (Terminated)) do
        begin
          Sleep(FOLGAPROCESSAMENTO); // Avoids using 100% CPU

          if (Pos('<|END_FILESLIST|>', xBufferTemp) > 0) then
            Break;

          xBufferTemp := xBufferTemp + scClient.ReceiveText;
        end;
      end;
      if (Pos('<|GETFILES|>', xBufferTemp) > 0) then
      begin
        while (scClient.Connected) and (Not (Terminated)) do
        begin
          Sleep(FOLGAPROCESSAMENTO); // Avoids using 100% CPU

          if (Pos('<|END_GETFILES|>', xBufferTemp) > 0) then
            Break;

          xBufferTemp := xBufferTemp + scClient.ReceiveText;
        end;
      end;

      for i := Low(arrAcessos) to High(arrAcessos) do
      begin
        if (Assigned(arrAcessos[i])) and (arrAcessos[i].Connected) then
        begin
          while arrAcessos[i].SendText(xBuffer) < 0 do
            Sleep(FOLGAPROCESSAMENTO);
        end;
      end;
    end;
  end;
end;

procedure TThreadConexaoPrincipal.LimparAcessos;
var
  i: Integer;
  Conexao: TConexao;
begin
  for i := Low(arrAcessos) to High(arrAcessos) do
  begin
    if Assigned(arrAcessos[i]) then
    begin
      Conexao := DMServer.Conexoes.RetornaItemPorHandle(arrAcessos[i].Handle);
      if Assigned(Conexao) then
      begin
        Conexao.ThreadPrincipal.RemoverAcesso(scClient.Handle);
        arrAcessos[i] := nil;
      end;
    end;
  end;
  SetLength(arrAcessos, 0);
end;

procedure TThreadConexaoPrincipal.ThreadTerminate(ASender: TObject);
var
  Conexao: TConexao;
  i: Integer;
begin
  if Assigned(DMServer) then
  begin
    LimparAcessos;

    Conexao := DMServer.Conexoes.RetornaItemPorConexao(FProtocolo);

    if not Terminated then
      Conexao.LimparThread(ttPrincipal);

    DMServer.Conexoes.RemoverConexao(Conexao.Protocolo);
  end;
end;

{ TThreadConexaoAreaRemota }

constructor TThreadConexaoAreaRemota.Create(ASocket: TCustomWinSocket; AProtocolo: string);
begin
  FTipo := ttAreaRemota;
  inherited;
end;

{ TThreadConexaoTeclado }

constructor TThreadConexaoTeclado.Create(ASocket: TCustomWinSocket; AProtocolo: string);
begin
  FTipo := ttTeclado;
  inherited;
end;

{ TThreadConexaoArquivos }

constructor TThreadConexaoArquivos.Create(ASocket: TCustomWinSocket; AProtocolo: string);
begin
  FTipo := ttArquivos;
  inherited;
end;

end.
