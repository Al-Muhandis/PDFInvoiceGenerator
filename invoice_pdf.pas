
unit invoice_pdf;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fppdf
  ;

type

  TPayerType = (pteUnknown, pteIndividual, pteEntity);

  { TInvoicePDFGenerator }

  TInvoicePDFGenerator = class
  private
    fCurrency: String;
    fFontFilePath: String;
    fFontName: String;
    fPayeeBankBIC: Int64;
    fPayeeBankName: String;
    fPayeeINN: Int64;
    fPayeeKPP: Int64;
    fPayerEmail: String;
    fPayerINN: String;
    fPayerKPP: String;
    fPayerName: String;
    fPayerPhone: String;
    fPayerTypeEnum: TPayerType;
    fPrice: Integer;
    fAcc, fCorrAcc: String;
    fDocNum: Integer;
    fPayeeName: String;
    fPaymentName: String;
    fPage: TPDFPage;
    fXBlockIndent, fXBlockIndent2: Integer;
    fY: Integer;
    procedure DrawLine(X, Y, L: Integer);
    function GetPayerType: String;
    procedure SetPayerType(aValue: String);
    procedure WriteText(X, Y: Integer; const S: string; aFont, aSize: Integer);
    procedure WriteBigText(X, Y: Integer; const S: string; aFont: Integer);
    procedure WriteSmallText(X, Y: Integer; const S: string; aFont: Integer);
    procedure WriteInfoBlockWithLine(const aInfoValue, aInfoName: String; aFont: Integer);
    procedure WriteInfoBlockWithLine(const aInfoValue1, aInfoName1, aInfoValue2, aInfoName2: String; aFont: Integer);
  public
    function Generate: TMemoryStream;
    property DocNum: Integer read fDocNum write fDocNum;
    property PayeeName: String read fPayeeName write fPayeeName;
    property PayeeINN: Int64 read fPayeeINN write fPayeeINN;
    property PayeeKPP: Int64 read fPayeeKPP write fPayeeKPP;
    property PayeeBankName: String read fPayeeBankName write fPayeeBankName;
    property PayeeBankBIC: Int64 read fPayeeBankBIC write fPayeeBankBIC;
    property PaymentName: String read fPaymentName write fPaymentName;
    property PayerType: String read GetPayerType write SetPayerType; 
    property PayerTypeEnum: TPayerType read fPayerTypeEnum write fPayerTypeEnum;
    property PayerName: String read fPayerName write fPayerName;
    property PayerEmail: String read fPayerEmail write fPayerEmail;
    property PayerPhone: String read fPayerPhone write fPayerPhone;
    property PayerINN: String read fPayerINN write fPayerINN;
    property PayerKPP: String read fPayerKPP write fPayerKPP;
    property PayeeBankCorrAcc: String read fCorrAcc write fCorrAcc;
    property PayeeBankAcc: String read fAcc write fAcc;
    property Price: Integer read fPrice write fPrice;
    property Currency: String read fCurrency write fCurrency;
    property FontFilePath: String read fFontFilePath write fFontFilePath;
    property FontName: String read fFontName write fFontName;
  end;

function InvoiceFullID(const aText: String; aDocNum: Integer; aDate: TDate): String;

implementation

var
  _dsplyFormatSettings: TFormatSettings;

function StringToPayerType(const aPayerType: String): TPayerType;
begin
  case aPayerType of
    'individual': Result:=pteIndividual;
    'entity'    : Result:=pteEntity;
  else
    Result:=pteUnknown;
  end;
end;

function PayerTypeToString(aPayerType: TPayerType): String;
begin
  case aPayerType of
    pteIndividual: Result:='Individual';
    pteEntity    : Result:='Entity';
  else
    Result:=EmptyStr;
  end;
end;

function CurrencyToStr(aSum: Integer; const aCurrency: String): String;
begin
  if aSum<>0 then
    Result:=FormatFloat('#,##0 ', aSum, _dsplyFormatSettings)+aCurrency
  else
    Result:=EmptyStr;
end;

function InvoiceFullID(const aText: String; aDocNum: Integer; aDate: TDate): String;
begin
  Result:=Format(aText, [aDocNum, FormatDateTime('dd.mm.yyyy', aDate)]);
end;

{ TInvoicePDFGenerator }

procedure TInvoicePDFGenerator.DrawLine(X, Y, L: Integer);
begin
  fPage.MoveTo(X, Y);
  fPage.DrawLine(X,Y, x+L, Y, 0.5, False);
  fPage.StrokePath;
end;

function TInvoicePDFGenerator.GetPayerType: String;
begin
  Result:=PayerTypeToString(fPayerTypeEnum);
end;

procedure TInvoicePDFGenerator.SetPayerType(aValue: String);
begin
  fPayerTypeEnum:=StringToPayerType(aValue);
end;

procedure TInvoicePDFGenerator.WriteText(X, Y: Integer; const S: string; aFont, aSize: Integer);
begin
  fPage.SetFont(aFont, aSize);
  fPage.WriteText(X, Y, S);
end;

procedure TInvoicePDFGenerator.WriteBigText(X, Y: Integer; const S: string; aFont: Integer);
begin
  WriteText(X, Y, S, aFont, 12);
end;

procedure TInvoicePDFGenerator.WriteSmallText(X, Y: Integer; const S: string; aFont: Integer);
begin
  WriteText(X, Y, S, aFont, 9);
end;

procedure TInvoicePDFGenerator.WriteInfoBlockWithLine(const aInfoValue, aInfoName: String; aFont: Integer);
begin
  WriteBigText(fXBlockIndent, fY, aInfoValue, aFont); fY -= 2;
  DrawLine(fXBlockIndent, fY, 140); fY -= 3;
  WriteSmallText(fXBlockIndent+5, fY, aInfoName, aFont); fY -= 8;
end;

procedure TInvoicePDFGenerator.WriteInfoBlockWithLine(const aInfoValue1, aInfoName1, aInfoValue2, aInfoName2: String;
  aFont: Integer);
begin
  WriteBigText(fXBlockIndent, fY, aInfoValue1, aFont); WriteBigText(fXBlockIndent2, fY, aInfoValue2, aFont);  fY -= 2;
  DrawLine(fXBlockIndent, fY, 60); DrawLine(fXBlockIndent2, fY, 60); fY -= 3;
  WriteSmallText(fXBlockIndent+5, fY, aInfoName1, aFont); WriteSmallText(fXBlockIndent2+5, fY, aInfoName2, aFont); fY -= 8;
end;

function TInvoicePDFGenerator.Generate: TMemoryStream;
var
  aDoc: TPDFDocument;
  aFont: Integer;
  aSection: TPDFSection;
  aInvoiceNo, aInvoiceNum: string;
begin
  Result := TMemoryStream.Create;
  aDoc := TPDFDocument.Create(nil);
  try
    aDoc.StartDocument;
    aSection := aDoc.Sections.AddSection;
    fPage := aDoc.Pages.AddPage;
    aSection.AddPage(fPage);

    if fFontFilePath.IsEmpty then
      aFont := aDoc.AddFont(fFontName)
    else
      aFont := aDoc.AddFont(fFontFilePath, fFontName);
    fY := Round(fPage.GetPaperHeight) - 10;

    aInvoiceNo := InvoiceFullID('Счет на оплату № %d от %s г.', DocNum, Date);
    WriteBigText(40, fY, aInvoiceNo, aFont); fY -= 16;

    fXBlockIndent:=40;
    fXBlockIndent2:=120;
    WriteInfoBlockWithLine(PayeeBankName, 'Банк получателя', aFont);
    WriteInfoBlockWithLine(PayeeBankBIC.ToString, 'БИК банка получателя', PayeeBankCorrAcc,
      'Номер корр.счета банка получателя', aFont);
    WriteInfoBlockWithLine(PayeeINN.ToString, 'ИНН получателя', PayeeKPP.ToString, 'КПП получателя', aFont);
    WriteInfoBlockWithLine(PayeeBankAcc, 'Счет получателя платежа', aFont);
    WriteInfoBlockWithLine(PayeeName, 'Получатель платежа', aFont);
    aInvoiceNum:=Format(PaymentName, [InvoiceFullID('№ %d от %s г.', DocNum, Date)]);
    WriteInfoBlockWithLine(aInvoiceNum, 'Наименование платежа', aFont);

    fY -= 8;
    WriteBigText(fXBlockIndent+40, fY, Format('Сумма платежа: %s', [CurrencyToStr(fPrice, fCurrency)]), aFont);  fY -= 8;
    WriteBigText(fXBlockIndent+40, fY, 'НДС не облагается', aFont);  fY -= 8;

    fY -= 8;

    WriteBigText(fXBlockIndent+5,  fY, 'Плательщик: ' + PayerName, aFont); fY -= 8;
    if fPayerTypeEnum=pteEntity then
    begin
      WriteBigText(fXBlockIndent+5,  fY, 'ИНН плательщика: ' + PayerINN, aFont); fY -= 8;
      WriteBigText(fXBlockIndent+5,  fY, 'КПП плательщика: ' + PayerKPP, aFont); fY -= 8;
    end;
    WriteBigText(fXBlockIndent+5,  fY, 'Email: ' + PayerEmail, aFont);
    WriteBigText(fXBlockIndent2+5, fY, 'Тел.: +' + PayerPhone, aFont); fY -= 12;

    aDoc.SaveToStream(Result);
  finally
    aDoc.Free;
  end;
  Result.Position := 0;
end;

initialization

  _dsplyFormatSettings:=DefaultFormatSettings;
  _dsplyFormatSettings.ThousandSeparator := ' ';
  _dsplyFormatSettings.DecimalSeparator := ',';
  _dsplyFormatSettings.DateSeparator:='.';
  _dsplyFormatSettings.ShortDateFormat:='dd/mm/yyyy';

end.

