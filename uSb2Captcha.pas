unit uSb2Captcha;
{-----------------------------------------------------------------------------
 Unit Name: uSb2Captcha
 Author:    Salih BAÐCI
 Date:      27-Ara-2020
-----------------------------------------------------------------------------}
interface

  uses SysUtils, Classes, Controls, REST.Types, REST.Client, Data.Bind.Components, Data.Bind.ObjectScope, DateUtils, Dialogs;

  type
  TSb2Captcha = class(TComponent)
  strict private
    FClient : TRESTClient;
    FRequest : TRESTRequest;
    FResponse: TRESTResponse;
    FApiKey: String;
    FImgBase64: String;
    FCaptchaId: String;
  private
    procedure SbSleepMessages(const ASleepTime:Cardinal);
  public
    constructor Create(AOwner:TComponent); override;
    destructor Destroy;override;
    function GetCaptchaBase64:String;
    function SetReport(const ASuccess:Boolean):Boolean;
  published
    property ApiKey: String read FApiKey write FApiKey;
    property ImgBase64: String read FImgBase64 write FImgBase64;
    property CaptchaId:String read FCaptchaId;
  end;


implementation

{ TSb2Captcha }

constructor TSb2Captcha.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FClient := TRESTClient.Create(Self);
  FRequest := TRESTRequest.Create(Self);
  FResponse := TRESTResponse.Create(Self);
  with FRequest do
  begin
    AssignedValues := [TAssignedValue.rvConnectTimeout,TAssignedValue.rvReadTimeout];
    ConnectTimeout := 15000;
    Client := FClient;
    Response := FResponse;
  end;
end;

destructor TSb2Captcha.Destroy;
begin
  FResponse.Free;
  FRequest.Free;
  FClient.Free;
  inherited;
end;

function TSb2Captcha.GetCaptchaBase64:String;
var
  xCnt : Integer;
begin
  Result := '';
  FCaptchaId := '';
  FClient.BaseURL := 'https://2captcha.com/in.php';
  with FRequest do
  begin
    Params.Clear;
    Params.AddItem('key',FApiKey,pkGETorPOST);
    Params.AddItem('method','base64',pkGETorPOST);
    Params.AddItem('body',FImgBase64,pkREQUESTBODY);
    Method := rmPOST;
  end;
  try
    FRequest.Execute;
    if (FResponse.Status.Success) and (Copy(FResponse.Content,1,2) = 'OK') then
    begin
      FCaptchaId := Copy(FResponse.Content,Succ(Pos('|',FResponse.Content)),MaxInt);
      FClient.BaseURL := 'https://2captcha.com/res.php';
      with FRequest do
      begin
        Params.Clear;
        Params.AddItem('key',FApiKey,pkGETorPOST);
        Params.AddItem('action','get',pkGETorPOST);
        Params.AddItem('id',FCaptchaId,pkGETorPOST);
        Method := rmGET;
      end;
      xCnt := 0;
      while xCnt <= 20 do // max 1 minute control
      begin
        SbSleepMessages(3000); // 3 second
        FRequest.Execute;
        if (FResponse.Status.Success) and (Copy(FResponse.Content,1,2) = 'OK') then
        begin
          Result := Copy(FResponse.Content,Succ(Pos('|',FResponse.Content)),MaxInt);
          Break;
        end
        else if not FResponse.Status.Success then
        begin
          Result := Format('Error: %s',[FResponse.Content]);
          Break;
        end;
        Inc(xCnt);
      end;
      if Result = '' then
        Result := Format('Error: %s',['Timeout 60 second']);
    end
    else
      Result := Format('Error: %s',[FResponse.Content]);
  except
    on e:Exception do
    begin
      Result := Format('Error: %s',[e.Message]);
    end;
  end;
end;

procedure TSb2Captcha.SbSleepMessages(const ASleepTime: Cardinal);
var
  xStart : TDateTime;
begin
  xStart := Now;
  while MilliSecondsBetween(Now,xStart) < ASleepTime do
  begin
    Sleep(1);
  end;
end;

function TSb2Captcha.SetReport(const ASuccess: Boolean):Boolean;
begin
  if FCaptchaId = '' then
    Exit(False);

  FClient.BaseURL := 'https://2captcha.com/res.php';
  with FRequest do
  begin
    Params.Clear;
    Params.AddItem('key',FApiKey,pkGETorPOST);
    if ASuccess then
      Params.AddItem('action','reportgood',pkGETorPOST)
    else
      Params.AddItem('action','reportbad',pkGETorPOST);
    Params.AddItem('id',FCaptchaId,pkGETorPOST);
    Method := rmGET;
  end;

  try
    FRequest.Execute;
    Result := (FResponse.Status.Success) and (Copy(FResponse.Content,1,2) = 'OK');
  except
    Result := False;
  end;
end;

end.
