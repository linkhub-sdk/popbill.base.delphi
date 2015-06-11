(*
*=================================================================================
* Unit for base module for Popbill API SDK. It include base functionality for
* RESTful web service request and parse json result. It uses Linkhub module
* to accomplish authentication APIs.
*
* http://www.popbill.com
* Author : Kim Seongjun (pallet027@gmail.com)
* Written : 2015-06-10

* Thanks for your interest. 
*=================================================================================
*)
{$IFDEF VER240}
{$DEFINE COMPILER15_UP}
{$ENDIF}
{$IFDEF VER250}
{$DEFINE COMPILER15_UP}
{$ENDIF}
{$IFDEF VER260}
{$DEFINE COMPILER15_UP}
{$ENDIF}
{$IFDEF VER270}
{$DEFINE COMPILER15_UP}
{$ENDIF}
{$IFDEF VER280}
{$DEFINE COMPILER15_UP}
{$ENDIF}
{$IFDEF VER290}
{$DEFINE COMPILER15_UP}
{$ENDIF}
unit Popbill;

interface

uses
        Windows, Messages,TypInfo, SysUtils, Classes ,ComObj,ActiveX,{$IFDEF COMPILER15_UP}Variants{$ENDIF},Linkhub;

const
        ServiceID_REAL = 'POPBILL';
        ServiceID_TEST = 'POPBILL_TEST';
        ServiceURL_REAL = 'https://popbill.linkhub.co.kr';
        ServiceURL_TEST = 'https://popbill_test.linkhub.co.kr';
        APIVersion = '1.0';
        CR = #$0d;
        LF = #$0a;
        CRLF = CR + LF;
type
        TResponse = Record
                code : LongInt;
                message : string;
        end;

        
        TJoinForm = Record
                LinkID          : string;
                CorpNum         : string;
                CEOName         : string;
                CorpName        : string;
                Addr            : string;
                ZipCode         : string;
                BizType         : string;
                BizClass        : string;
                ID              : string;
                PWD             : string;
                ContactName     : string;
                ContactTEL      : string;
                ContactHP       : string;
                ContactFAX      : string;
                ContactEmail    : string;
        end;

        TFile = class
        public
                FieldName       : string;
                FileName        : string;
                Data            : TStream;
        end;

        TFileList = Array Of TFile;

        TPopbillBaseService = class
        protected
                FToken     : TToken;
                FIsTest    : bool;
                FTokenCorpNum : String;
                FAuth      : TAuth;
                FScope     : Array Of String;
                procedure setIsTest(value : bool);

                function getSession_Token(CorpNum : String) : String;
                function httpget(url : String; CorpNum : String; UserID : String) : String;
                function httppost(url : String; CorpNum : String; UserID : String ; request : String) : String; overload;
                function httppost(url : String; CorpNum : String; UserID : String ; request : String; Action : String) : String; overload;
                function httppost(url : String; CorpNum : String; UserID : String ; FieldName,FileName : String; data: TStream) : String; overload;
                function httppost(url : String; CorpNum : String; UserID : String ; files : TFileList) : String; overload;
                function httppost(url : String; CorpNum : String; UserID : String ; form : String; files : TFileList) : String; overload;
        public
                constructor Create(LinkID : String; SecretKey : String);
                procedure AddScope(Scope : String);
                //팝빌 공통.
                //팝빌 연결 url.
                function GetPopbillURL(CorpNum : String; UserID : String; TOGO : String) : String;
                //연동회원 가입.
                function JoinMember(JoinInfo : TJoinForm) : TResponse;
                //가입여부 확인
                function CheckIsMember(CorpNum : String; LinkID : String) : TResponse;
                //회원 잔여포인트 확인.
                function GetBalance(CorpNum : String) : Double;
                //파트너 잔여포인트 확인.
                function GetPartnerBalance(CorpNum : String) : Double;

                function getServiceID() : String;
                
        published
                //TEST Mode. default is false.
                property IsTest : bool read FIsTest write setIsTest;
        end;

        EPopbillException  = class(Exception)
        private
                FCode : LongInt;
        public
                constructor Create(code : LongInt; Message : String);
        published
                property code : LongInt read FCode write FCode;
        end;

        procedure WriteStrToStream(const Stream: TStream; Value: AnsiString);
implementation
constructor EPopbillException.Create(code : LongInt; Message : String);
begin
        inherited Create(Message);
        FCode := code;
end;

constructor TPopbillBaseService.Create(LinkID : String; SecretKey : String);
begin
       FAuth := TAuth.Create(LinkID,SecretKey);
       setLength(FScope,1);
       FScope[0] := 'member';
end;

procedure TPopbillBaseService.AddScope(scope : String);
begin
        setLength(FScope,length(FScope)+1);
        FScope[length(FScope)-1] := scope;
end;

procedure TPopbillBaseService.setIsTest(value : bool);
begin
        FIsTest := value;;
end;

function TPopbillBaseService.getServiceID() : String;
begin
    if(FIsTest) then result := ServiceID_TEST
    else result := ServiceID_REAL;
end;

function TPopbillBaseService.getSession_Token(CorpNum : String) : String;
var
        noneOrExpired : bool;
        Expiration : TDateTime;
begin
        if FToken = nil then noneOrExpired := true
        else begin
                if FTokenCorpNum <> CorpNum then noneOrExpired := true
                else begin
                        Expiration := UTCToDate( FToken.expiration);
                        noneOrExpired := expiration < now;
                end;
        end;

        if noneOrExpired then
        begin

                try
                        FToken := FAuth.getToken(getServiceID(),CorpNum,FScope);//,'192.168.10.222');
                        FTokenCorpNum := CorpNum;
                except on le:ELinkhubException do
                        raise EPopbillException.Create(le.code,le.message);
                end;
        end;
        result := FToken.session_token;
end;


function TPopbillBaseService.httppost(url : String; CorpNum : String; UserID : String ; request : String) : String;
begin
        result := httppost(url,CorpNum,UserID,request,'');
end;

function TPopbillBaseService.httppost(url : String; CorpNum : String; UserID : String ; request : String; action:String) : String;
var
        http : olevariant;
        postdata : olevariant;
        response : string;
        sessiontoken : string;
     
begin

        if FIsTest then url := ServiceURL_TEST + url
             else url := ServiceURL_REAL + url;

        postdata := request;
        http:=createoleobject('WinHttp.WinHttpRequest.5.1');
        http.open('POST',url);

        if(CorpNum <> '') then
        begin
                sessiontoken := getSession_Token(CorpNum);
                HTTP.setRequestHeader('Authorization', 'Bearer ' + sessiontoken);
        end;
        if(action <> '') then
        begin
                HTTP.setRequestHeader('X-HTTP-Method-Override',action);
        end;
        
        HTTP.setRequestHeader('x-lh-version',APIVersion);

        if UserID <> '' then
        begin
                HTTP.setRequestHeader('x-pb-userid',UserID);
        end;

        HTTP.setRequestHeader('Content-Type','Application/json ;');

        http.send(postdata);
        http.WaitForResponse;


        response := http.responsetext;

        if HTTP.Status <> 200 then
        begin
                raise EPopbillException.Create(getJSonInteger(response,'code'),getJSonString(response,'message'));
        end;
        result := response;

end;
function TPopbillBaseService.httppost(url : String; CorpNum : String; UserID : String ; files : TFileList) : String;
begin
        result := httppost(url,CorpNum,UserID,'',files);
end;

function MemoryStreamToOleVariant(const Strm: TMemoryStream): OleVariant;
var 
        Data: PByteArray;
begin 
        Result := VarArrayCreate ([0, Strm.Size - 1], varByte);
        Data := VarArrayLock(Result);
        try
                Strm.Position := 0;
                Strm.ReadBuffer(Data^, Strm.Size);
        finally
                VarArrayUnlock(Result);
        end;
end;

function TPopbillBaseService.httppost(url : String; CorpNum : String; UserID : String ; form : String; files : TFileList) : String;
var
        HTTP: olevariant;
        postdata : olevariant;
        response : string;
        sessiontoken : string;
        Bound,s : WideString;
        tmp : {$IFDEF COMPILER15_UP}TArray<Byte>{$ELSE}Array of Byte{$ENDIF};
        i,intTemp : Integer;
        Stream: TMemoryStream;
begin
        Bound := '==POPBILL_DELPHI_SDK==';
        Stream := TMemoryStream.Create;

        if FIsTest then url := ServiceURL_TEST + url
             else url := ServiceURL_REAL + url;

        postdata := form;
        http:=createoleobject('WinHttp.WinHttpRequest.5.1');
        http.open('POST',url);

        if(CorpNum <> '') then
        begin
                sessiontoken := getSession_Token(CorpNum);
                HTTP.setRequestHeader('Authorization', 'Bearer ' + sessiontoken);
        end;

        HTTP.setRequestHeader('x-lh-version',APIVersion);

        if UserID <> '' then
        begin
                HTTP.setRequestHeader('x-pb-userid',UserID);
        end;

        if form <> '' then begin
                s := '--' + Bound + CRLF;
                s := s + 'content-disposition: form-data; name="form"' + CRLF;
                s := s + 'content-type: Application/json; charset=euc-kr' + CRLF + CRLF;
                s := s + form + CRLF;
                WriteStrToStream(Stream, s);
        end;                                                                                     

        for i:=0 to Length(files) -1 do begin

                // Start Of Part
                s := '--' + Bound + CRLF;
                s := s + 'content-disposition: form-data; name="' + files[i].FieldName + '";';
                s := s + ' filename="' + files[i].FileName +'"' + CRLF;
                s := s + 'Content-Type: Application/octet-stream' + CRLF + CRLF;

                {$IFDEF COMPILER15_UP}
                tmp := TEncoding.UTF8.GetBytes(s);
                {$ELSE}
                SetLength(tmp,Length(s)*3);
                intTemp := UnicodeToUtf8(@tmp[0], Length(tmp),PWideChar(s),Length(s));
                SetLength(tmp,intTemp-1);
                {$ENDIF}
                Stream.Write(tmp[0], length(tmp));

                Stream.CopyFrom(files[i].Data, 0);

                WriteStrToStream(Stream, CRLF);
        end;

        //End Of MultiPart
        WriteStrToStream(Stream, '--' + Bound + '--' + CRLF);


        HTTP.setRequestHeader('Content-Type','multipart/form-data; boundary=' + Bound);


        http.send(MemoryStreamToOleVariant(Stream));
        Stream.free;
        http.WaitForResponse;

        response := http.responsetext;

        if HTTP.Status <> 200 then
        begin
                raise EPopbillException.Create(getJSonInteger(response,'code'),getJSonString(response,'message'));
        end;
        result := response;


end;

function TPopbillBaseService.httppost(url : String; CorpNum : String; UserID : String ; FieldName,FileName : String; data: TStream) : String;
var
        files : TFileList;
begin
        SetLength(files,1);
        files[0] := TFile.Create;
        files[0].FieldName := FieldName;
        files[0].FileName := FileName;
        files[0].Data := data;

        result := httppost(url,CorpNum,UserID,files);
end;

function TPopbillBaseService.httpget(url : String; CorpNum : String; UserID : String) : String;
var
        HTTP: olevariant;
        response : string;
        sessiontoken : string;
begin

        if FIsTest then url := ServiceURL_TEST + url
             else url := ServiceURL_REAL + url;

        http:=createoleobject('WinHttp.WinHttpRequest.5.1');
        http.open('GET',url);

        if(CorpNum <> '') then
        begin
                sessiontoken := getSession_Token(CorpNum);
                HTTP.setRequestHeader('Authorization','Bearer ' + sessiontoken);
        end;


        HTTP.setRequestHeader('x-lh-version', APIVersion);

        if UserID <> '' then
        begin
                HTTP.setRequestHeader('x-pb-userid',UserID);
        end;

        http.send;
        http.WaitForResponse;

        response := http.responsetext;

        if HTTP.status <> 200 then
        begin
                raise EPopbillException.Create(getJSonInteger(response,'code'),getJSonString(response,'message'));
        end;
        result := response;

end;


function TPopbillBaseService.getPopbillURL(CorpNum : String; UserID : String; TOGO : String) : String;
var
        responseJson : String;
begin
        responseJson := httpget('/?TG=' + TOGO ,CorpNum,UserID);
        result := getJSonString(responseJson,'url');
end;

function TPopbillBaseService.JoinMember(JoinInfo : TJoinForm) : TResponse;
var
        requestJson : string;
        responseJson : string;
begin
        requestJson := '{';

        requestJson := requestJson + '"LinkID":"'+EscapeString(JoinInfo.LinkID)+'",';

        requestJson := requestJson + '"CorpNum":"'+EscapeString(JoinInfo.CorpNum)+'",';
        requestJson := requestJson + '"CEOName":"'+EscapeString(JoinInfo.CEOName)+'",';
        requestJson := requestJson + '"CorpName":"'+EscapeString(JoinInfo.CorpName)+'",';
        requestJson := requestJson + '"Addr":"'+EscapeString(JoinInfo.Addr)+'",';
        requestJson := requestJson + '"ZipCode":"'+EscapeString(JoinInfo.ZipCode)+'",';
        requestJson := requestJson + '"BizType":"'+EscapeString(JoinInfo.BizType)+'",';
        requestJson := requestJson + '"BizClass":"'+EscapeString(JoinInfo.BizClass)+'",';
        requestJson := requestJson + '"ContactName":"'+EscapeString(JoinInfo.ContactName)+'",';
        requestJson := requestJson + '"ContactEmail":"'+EscapeString(JoinInfo.ContactEmail)+'",';
        requestJson := requestJson + '"ContactTEL":"'+EscapeString(JoinInfo.ContactTEL)+'",';
        requestJson := requestJson + '"ContactHP":"'+EscapeString(JoinInfo.ContactHP)+'",';
        requestJson := requestJson + '"ContactFAX":"'+EscapeString(JoinInfo.ContactFAX)+'",';
        requestJson := requestJson + '"ID":"'+EscapeString(JoinInfo.ID)+'",';
        requestJson := requestJson + '"PWD":"'+EscapeString(JoinInfo.PWD)+'"';

        requestJson := requestJson + '}';

        responseJson := httppost('/Join','','',requestJson);

        result.code := getJSonInteger(responseJson,'code');
        result.message := getJSonString(responseJson,'message');

end;
function TPopbillBaseService.CheckIsMember(CorpNum : String; LinkID : String) : TResponse;
var
        responseJson : string;
begin
        responseJson := httpget('/Join?CorpNum=' + CorpNum + '&LID=' + LinkID,'','');

        result.code := getJSonInteger(responseJson,'code');
        result.message := getJSonString(responseJson,'message');
end;

function TPopbillBaseService.GetBalance(CorpNum : String) : Double;
begin
        result := FAuth.getBalance(getSession_Token(CorpNum),getServiceID());
end;

function TPopbillBaseService.GetPartnerBalance(CorpNum : String) : Double;
begin
        result := FAuth.getPartnerBalance(getSession_Token(CorpNum),getServiceID());
end;

procedure WriteStrToStream(const Stream: TStream; Value: AnsiString);
{$IFDEF CIL}
var
  buf: Array of Byte;
{$ENDIF}
begin
{$IFDEF CIL}
  buf := BytesOf(Value);
  Stream.Write(buf,length(Value));
{$ELSE}
  Stream.Write(PAnsiChar(Value)^, Length(Value));
{$ENDIF}
end;

end.
