(*
*=================================================================================
* Unit for base module for Popbill API SDK. It include base functionality for
* RESTful web service request and parse json result. It uses Linkhub module
* to accomplish authentication APIs.
*
* This module uses synapse library.( http://www.ararat.cz/synapse/doku.php/ )
* It's full open source library, free to use include commercial application.
* If you wish to donate that, visit their site.
* So, before using this module, you need to install synapse by user self.
* You can refer their site or detailed infomation about installation is available
* from below our site. We appreciate your visiting.
*
* For strongly secured communications, this module uses SSL/TLS with OpenSSL.
* So You need two dlls (libeay32.dll and ssleay32.dll) from OpenSSL. You can
* get it from Fulgan. ( http://indy.fulgan.com/SSL/ ) We recommend i386_win32 version.
* And also, dlls must be released with your executions. That's the drawback of this
* module, but we acommplished higher security level against that.
*
* http://www.popbill.com
* Author : Kim Seongjun (pallet027@gmail.com)
* Written : 2014-03-22

* Thanks for your interest. 
*=================================================================================
*)
unit Popbill;

interface

uses
        Windows, Messages,TypInfo, SysUtils,synautil,synachar, Classes, HTTPSend , ssl_openssl,Linkhub;
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
                        FToken := FAuth.getToken(getServiceID(),CorpNum,FScope);//,'192.168.0.222');
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
        HTTP: THTTPSend;
        response : string;
        sessiontoken : string;
     
begin

        if FIsTest then url := ServiceURL_TEST + url
             else url := ServiceURL_REAL + url;

        HTTP := THTTPSend.Create;
        HTTP.Sock.SSLDoConnect;

        if(CorpNum <> '') then
        begin
                sessiontoken := getSession_Token(CorpNum);
                HTTP.Headers.Add('Authorization: Bearer ' + sessiontoken);
        end;
        if(action <> '') then
        begin
                HTTP.Headers.Add('X-HTTP-Method-Override: '+action);
        end;
        
        try
                HTTP.Headers.Add('x-lh-version: ' + APIVersion);

                if UserID <> '' then
                begin
                        HTTP.Headers.Add('x-pb-userid: ' + UserID);
                end;

                HTTP.MimeType := 'Application/json ; Charset=euc-kr';
               
                HTTP.Document.CopyFrom(TStringStream.Create(request),0);

                if HTTP.HTTPMethod('POST', url) then
                begin
                        if HTTP.ResultCode <> 200 then
                        begin
                                response := StreamToString(HTTP.Document);
                                raise EPopbillException.Create(getJSonInteger(response,'code'),getJSonString(response,'message'));
                        end;
                        result := StreamToString(HTTP.Document);

                end
                else
                begin
                    if HTTP.ResultCode <> 200 then
                    begin
                        raise EPopbillException.Create(-99999999,HTTP.ResultString);
                    end;
                end;

        finally
                HTTP.Free;
        end;
end;
function TPopbillBaseService.httppost(url : String; CorpNum : String; UserID : String ; files : TFileList) : String;
begin
        result := httppost(url,CorpNum,UserID,'',files);
end;

function TPopbillBaseService.httppost(url : String; CorpNum : String; UserID : String ; form : String; files : TFileList) : String; 
var
        HTTP: THTTPSend;
        response : string;
        sessiontoken : string;
        Bound,s : WideString;
        tmp : {$IFDEF COMPILER15_UP}TArray<Byte>{$ELSE}Array of Byte{$ENDIF};
        i,intTemp : Integer;
begin

        if FIsTest then url := ServiceURL_TEST + url
             else url := ServiceURL_REAL + url;

        HTTP := THTTPSend.Create;
        HTTP.Sock.SSLDoConnect;

        if(CorpNum <> '') then
        begin
                sessiontoken := getSession_Token(CorpNum);
                HTTP.Headers.Add('Authorization: Bearer ' + sessiontoken);
        end;

        try

                HTTP.Headers.Add('x-lh-version: ' + APIVersion);

                if UserID <> '' then
                begin
                        HTTP.Headers.Add('x-pb-userid: ' + UserID);
                end;

                Bound := IntToHex(Random(MaxInt), 8) + '_DELPHI_SDK';

                if form <> '' then begin
                        s := '--' + Bound + CRLF;
                        s := s + 'content-disposition: form-data; name="form"' + CRLF;
                        s := s + 'content-type: Application/json; charset=euc-kr' + CRLF + CRLF;
                        s := s + form + CRLF;
                        WriteStrToStream(HTTP.Document, s);
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
                        HTTP.Document.Write(tmp[0], length(tmp));

                        HTTP.Document.CopyFrom(files[i].Data, 0);

                        WriteStrToStream(HTTP.Document, CRLF);
                end;
                
                //End Of MultiPart
                WriteStrToStream(HTTP.Document, '--' + Bound + '--' + CRLF);

                HTTP.MimeType := 'multipart/form-data; boundary=' + Bound;
                

                if HTTP.HTTPMethod('POST', url) then
                begin
                        if HTTP.ResultCode <> 200 then
                        begin
                                response := StreamToString(HTTP.Document);
                                raise EPopbillException.Create(getJSonInteger(response,'code'),getJSonString(response,'message'));
                        end;
                        result := StreamToString(HTTP.Document);

                end
                else
                begin
                    if HTTP.ResultCode <> 200 then
                    begin
                        raise EPopbillException.Create(-99999999,HTTP.ResultString);
                    end;
                end;

        finally
                HTTP.Free;
        end;
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
        HTTP: THTTPSend;
        response : string;
        sessiontoken : string;
begin

        if FIsTest then url := ServiceURL_TEST + url
             else url := ServiceURL_REAL + url;

        HTTP := THTTPSend.Create;
        HTTP.Sock.SSLDoConnect;

        if(CorpNum <> '') then
        begin
                sessiontoken := getSession_Token(CorpNum);
                HTTP.Headers.Add('Authorization: Bearer ' + sessiontoken);
        end;

        try
                HTTP.Headers.Add('x-lh-version: ' + APIVersion);

                if UserID <> '' then
                begin
                        HTTP.Headers.Add('x-pb-userid: ' + UserID);
                end;

                if HTTP.HTTPMethod('GET', url) then
                begin
                        if HTTP.ResultCode <> 200 then
                        begin
                                response := StreamToString(HTTP.Document);
                                raise EPopbillException.Create(getJSonInteger(response,'code'),getJSonString(response,'message'));
                        end;
                        result := StreamToString(HTTP.Document);

                end
                else
                begin
                    if HTTP.ResultCode <> 200 then
                    begin
                        raise EPopbillException.Create(-99999999,HTTP.ResultString);
                    end;
                end;

        finally
                HTTP.Free;
        end;
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

end.
