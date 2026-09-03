unit invoice_pdf;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fppdf;

type
  { TInvoiceItem }
  TInvoiceItem = class(TCollectionItem)
  private
    fName: string;
    fPrice: Currency;
    fQuantity: Double;
    fUnitName: string;
  public
    function Amount: Currency;
    property Name: string read fName write fName;
    property Quantity: Double read fQuantity write fQuantity;
    property UnitName: string read fUnitName write fUnitName;
    property Price: Currency read fPrice write fPrice;
  end;

  { TBankDetails }
  TBankDetails = class
  private
    fAccount: string;
    fBankName: string;
    fBIC: string;
    fCorrAccount: string;
  public
    property BankName: string read fBankName write fBankName;
    property BIC: string read fBIC write fBIC;
    property CorrAccount: string read fCorrAccount write fCorrAccount;
    property Account: string read fAccount write fAccount;
  end;

  { TInvoiceCollection }
  TInvoiceCollection = class(TCollection)
  public
    constructor Create;
    function GetItem(Index: Integer): TInvoiceItem;
    property Items[Index: Integer]: TInvoiceItem read GetItem; default;
  end;

  { TParty }
  TParty = class
  private
    fName: string;
    fINN: string;
    fKPP: string;
    fAddress: string;
    fPhone: string;
  public
    property Name: string read fName write fName;
    property INN: string read fINN write fINN;
    property KPP: string read fKPP write fKPP;
    property Address: string read fAddress write fAddress;
    property Phone: string read fPhone write fPhone;
  end;

  { TInvoice }
  TInvoice = class
  private
    fDueDate: TDate;
    fNumber: Integer;
    fDate: TDate;
    fSupplier: TParty;
    fBuyer: TParty;
    fBank: TBankDetails;
    fItems: TInvoiceCollection;
    fCurrency: string;
    fWithoutVAT: Boolean;
    fPaymentPurpose: string;
    fBasis: string;
  public
    constructor Create;
    destructor Destroy; override;

    procedure AddItem(const aName: string; aQuantity: Double;
                      const aUnitName: string; aPrice: Currency);

    function TotalAmount: Currency;

    property Number: Integer read fNumber write fNumber;
    property Date: TDate read fDate write fDate;
    property Supplier: TParty read fSupplier;
    property Buyer: TParty read fBuyer;
    property Bank: TBankDetails read fBank;
    property Items: TInvoiceCollection read fItems;
    property Currency: string read fCurrency write fCurrency;
    property WithoutVAT: Boolean read fWithoutVAT write fWithoutVAT;
    property PaymentPurpose: string read fPaymentPurpose write fPaymentPurpose;
    property Basis: string read fBasis write fBasis;
    property DueDate: TDate read fDueDate write fDueDate;
  end;

  { TInvoicePDFGenerator }
  TInvoicePDFGenerator = class
  private
    fFontFilePath: string;
    fFontName: string;
    fPage: TPDFPage;
    fFont: Integer;
    fXLeft: Integer;
    fY: Integer;

    procedure DrawLine(X, Y, L: Integer);
    procedure WriteText(X, Y: Integer; const S: string; aSize: Integer);
    procedure WriteBigText(X, Y: Integer; const S: string);            
    procedure WriteTitleText(X, Y: Integer; const S: string);
    procedure WriteSmallText(X, Y: Integer; const S: string);

    procedure DrawRect(X, Y, W, H: Integer);
    procedure DrawCellText(X, Y: Integer; const Text: string; aFontSize: Integer = 10);

    procedure DrawTitle(aInvoice: TInvoice);
    procedure DrawBankDetails(aInvoice: TInvoice);
    procedure DrawSupplierBuyer(aInvoice: TInvoice);
    procedure DrawItemsTable(aInvoice: TInvoice);
    procedure DrawInvoiceSummary(aInvoice: TInvoice);
    procedure DrawTotals(aInvoice: TInvoice);
    procedure DrawPayerInfo(aInvoice: TInvoice);
    procedure DrawPaymentTerms(aInvoice: TInvoice);

  public
    constructor Create;
    function Generate(aInvoice: TInvoice): TMemoryStream;

    property FontFilePath: string read fFontFilePath write fFontFilePath;
    property FontName: string read fFontName write fFontName;
  end;

function InvoiceFullID(const AText: string; ADocNum: Integer; ADate: TDate): string;

implementation

var
  _dsplyFormatSettings: TFormatSettings;

const
  MARGIN_LEFT   = 15;
  MARGIN_TOP    = 12;

  CONTENT_WIDTH  = 180;

  ITEM_NO_WIDTH     = 9;
  ITEM_NAME_WIDTH   = 94;
  ITEM_QTY_WIDTH    = 17;
  ITEM_UNIT_WIDTH   = 14;
  ITEM_PRICE_WIDTH  = 23;
  ITEM_AMOUNT_WIDTH = 23;

  H1: String = '№'; H2: String = 'Товары (работы, услуги)'; H3: String = 'Кол-во'; H4: String = 'Ед.';
  H5: String = 'Цена'; H6: String = 'Сумма';

function InvoiceFullID(const aText: string; aDocNum: Integer; aDate: TDate): string;
begin
  Result := Format(aText, [aDocNum, FormatDateTime('dd.mm.yyyy', aDate)]);
end;

// ---------------------------------------------------------------------------
// Сумма прописью (рубли / копейки)
// ---------------------------------------------------------------------------

function SumInWords(Amount: Currency): string;
const
  aOnes: array[0..9] of string = ('', 'один', 'два', 'три', 'четыре', 'пять', 'шесть', 'семь', 'восемь', 'девять');
  aOnesF: array[0..9] of string = ('', 'одна', 'две', 'три', 'четыре', 'пять', 'шесть', 'семь', 'восемь', 'девять');
  aTeens: array[10..19] of string = ('десять', 'одиннадцать', 'двенадцать', 'тринадцать', 'четырнадцать',
    'пятнадцать', 'шестнадцать', 'семнадцать', 'восемнадцать', 'девятнадцать');
  aTens: array[2..9] of string = ('двадцать', 'тридцать', 'сорок', 'пятьдесят', 'шестьдесят',
    'семьдесят', 'восемьдесят', 'девяносто');
  aHundreds: array[1..9] of string = ('сто', 'двести', 'триста', 'четыреста', 'пятьсот',
    'шестьсот', 'семьсот', 'восемьсот', 'девятьсот');

  function GetTriplet(N: Integer; IsFemale: Boolean): string;
  var
    H, T, O: Integer;
  begin
    Result := '';
    H := N div 100;
    T := (N div 10) mod 10;
    O := N mod 10;
    if H > 0 then
      Result += aHundreds[H] + ' ';
    if T = 1 then
      Result += aTeens[N mod 100] + ' '
    else
    begin
      if T > 1 then
        Result += aTens[T] + ' ';
      if O > 0 then
        if IsFemale then
          Result += aOnesF[O] + ' '
        else
          Result += aOnes[O] + ' ';
    end;
  end;

  function GetEnding(N: Integer; const F1, F2, F5: string): string;
  var
    L1, L2: Integer;
  begin
    L2 := N mod 100;
    L1 := N mod 10;
    if (L2 >= 11) and (L2 <= 19) then
      Result := F5
    else if L1 = 1 then
      Result := F1
    else if (L1 >= 2) and (L1 <= 4) then
      Result := F2
    else
      Result := F5;
  end;

var
  aRub, aKop: Int64;
  aBill, aMill, aThous, aUnitN: Integer;
  S: string;
begin
  aRub := Trunc(Amount);
  aKop := Round(Frac(Amount) * 100);

  if aRub = 0 then
    S := 'ноль рублей '
  else
  begin
    S := '';
    aBill := aRub div 1000000000;
    aMill := (aRub div 1000000) mod 1000;
    aThous := (aRub div 1000) mod 1000;
    aUnitN := aRub mod 1000;

    if aBill > 0 then
      S += GetTriplet(aBill, False) + ' ' + GetEnding(aBill, 'миллиард', 'миллиарда', 'миллиардов') + ' ';
    if aMill > 0 then
      S += GetTriplet(aMill, False) + ' ' + GetEnding(aMill, 'миллион', 'миллиона', 'миллионов') + ' ';
    if aThous > 0 then
      S += GetTriplet(aThous, True) + ' ' + GetEnding(aThous, 'тысяча', 'тысячи', 'тысяч') + ' ';
    if aUnitN > 0 then
      S += GetTriplet(aUnitN, False) + ' ';
    S += GetEnding(aRub mod 100, 'рубль', 'рубля', 'рублей') + ' ';
  end;

  Result := Trim(S) + ' ' + Format('%.2d', [aKop]) + ' копеек';
end;

{ TInvoiceItem }

function TInvoiceItem.Amount: Currency;
begin
  Result := fQuantity * fPrice;
end;

{ TInvoiceCollection }

constructor TInvoiceCollection.Create;
begin
  inherited Create(TInvoiceItem);
end;

function TInvoiceCollection.GetItem(Index: Integer): TInvoiceItem;
begin
  Result := inherited Items[Index] as TInvoiceItem;
end;

{ TInvoice }

constructor TInvoice.Create;
begin
  inherited Create;
  fCurrency := 'руб.';
  fWithoutVAT := True;
  fDate := SysUtils.Date;
  fBuyer := TParty.Create;
  fSupplier := TParty.Create;
  fBank := TBankDetails.Create;
  fItems := TInvoiceCollection.Create;
end;

destructor TInvoice.Destroy;
begin
  fItems.Free;
  fBank.Free;
  fSupplier.Free;
  fBuyer.Free;
  inherited Destroy;
end;

procedure TInvoice.AddItem(const aName: string; aQuantity: Double;
  const aUnitName: string; aPrice: Currency);
var
  aItem: TInvoiceItem;
begin
  aItem := fItems.Add as TInvoiceItem;
  aItem.Name := aName;
  aItem.Quantity := aQuantity;
  aItem.UnitName := aUnitName;
  aItem.Price := aPrice;
end;

function TInvoice.TotalAmount: Currency;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to fItems.Count - 1 do
    Result += fItems[i].Amount;
end;

{ TInvoicePDFGenerator }

constructor TInvoicePDFGenerator.Create;
begin
  inherited Create;
  fFontName := 'Arial';
  fXLeft := MARGIN_LEFT;
end;

procedure TInvoicePDFGenerator.DrawLine(X, Y, L: Integer);
begin
  fPage.MoveTo(X, Y);
  fPage.DrawLine(X, Y, X + L, Y, 1, False);
  fPage.StrokePath;
end;

procedure TInvoicePDFGenerator.WriteText(X, Y: Integer; const S: string; aSize: Integer);
begin
  fPage.SetFont(fFont, aSize);
  fPage.WriteText(X, Y, S);
end;

procedure TInvoicePDFGenerator.WriteBigText(X, Y: Integer; const S: string);
begin
  WriteText(X, Y, S, 11);
end;

procedure TInvoicePDFGenerator.WriteTitleText(X, Y: Integer; const S: string);
begin
  WriteText(X, Y, S, 16);
end;

procedure TInvoicePDFGenerator.WriteSmallText(X, Y: Integer; const S: string);
begin
  WriteText(X, Y, S, 8);
end;

procedure TInvoicePDFGenerator.DrawRect(X, Y, W, H: Integer);
begin
  fPage.DrawRect(X, Y, W, -H, 0.6, False, True);
end;

procedure TInvoicePDFGenerator.DrawCellText(X, Y: Integer; const Text: string; aFontSize: Integer);
begin
  fPage.SetFont(fFont, aFontSize);
  fPage.WriteText(X + 2, Y + 5, Text);
end;

// ---------------------------------------------------------------------------
// Секции
// ---------------------------------------------------------------------------

procedure TInvoicePDFGenerator.DrawTitle(aInvoice: TInvoice);
var
  aInvoiceNo: string;
  X, Y: Integer;
begin
  aInvoiceNo := InvoiceFullID('Счет на оплату № %d от %s г.', aInvoice.Number, aInvoice.Date);
  WriteTitleText(fXLeft, fY, aInvoiceNo);
  X := fXLeft; Y := fY + 5;
  DrawLine(X, Y, CONTENT_WIDTH);
  fY += 16;
end;

procedure TInvoicePDFGenerator.DrawBankDetails(aInvoice: TInvoice);
const
  // Ширины колонок банковского блока.
  // Сумма каждой строки = 180 мм.
  aBankMainW   = 100;
  aBankLabelW  = 20;
  aBankValueW  = 60;

  aINNLabelW   = 20;
  aINNValueW   = 30;
  aKPPLabelW   = 20;
  aKPPValueW   = 30;
  aAccountLabelW = 20;
  aAccountValueW = 60;

  aRowBankH   = 18;
  aRowBankLabelH = aRowBankH - 10;
  aRowINNKPPH = 12;
  aRowReceiverH = 18;
  aAccountLabelH = aRowINNKPPH + aRowReceiverH;
  aAccountValueH = aRowINNKPPH + aRowReceiverH;
var
  Y: Integer;
  X: Integer;
begin
  Y := fY;

  // ========================================================================
  // Банк получателя
  //
  // ┌───────────────────────────────────────┬───────┬───────────────────────┐
  // │                                       │ БИК   │                       │
  // │          Банк получателя              ├───────┤      Значение         │
  // │                                       │ Сч. № │                       │
  // └───────────────────────────────────────┴───────┴───────────────────────┘
  //                 100 мм                    20 мм        60 мм
  // ========================================================================

  // Левая область: банк
  DrawRect(fXLeft, Y, aBankMainW, aRowBankH);
  DrawCellText(fXLeft, Y, aInvoice.Bank.BankName, 10);
  DrawCellText(fXLeft, Y + aRowBankLabelH, 'Банк получателя', 7);

  // БИК
  X := fXLeft + aBankMainW;
  DrawRect(X, Y, aBankLabelW, aRowBankH div 2);
  DrawCellText(X, Y, 'БИК', 7);
  DrawRect(X + aBankLabelW, Y, aBankValueW, aRowBankH div 2);
  DrawCellText(X + aBankLabelW, Y, aInvoice.Bank.BIC, 10);

  // Корреспондентский счёт
  DrawRect(X, Y + aRowBankH div 2, aBankLabelW, aRowBankH div 2);
  DrawCellText(X, Y + aRowBankH div 2, 'Сч. №', 7);
  DrawRect(X + aBankLabelW, Y + aRowBankH div 2, aBankValueW, aRowBankH div 2);
  DrawCellText(X + aBankLabelW, Y + aRowBankH div 2, aInvoice.Bank.CorrAccount, 10);

  Y += aRowBankH;

  // ========================================================================
  // ИНН / КПП / Расчётный счёт
  //
  // ┌────────┬──────────────┬────────┬──────────────┬────────┬──────────────┐
  // │  ИНН   │              │  КПП   │              │ Сч. №  │              │
  // └────────┴──────────────┴────────┴──────────────┴────────┴──────────────┘
  //    20          30          20          30          20          60
  // ========================================================================

  X := fXLeft;

  // ИНН
  DrawRect(X, Y, aINNLabelW, aRowINNKPPH);
  DrawCellText(X, Y, 'ИНН', 7);
  X += aINNLabelW;
  DrawRect(X, Y, aINNValueW, aRowINNKPPH);
  DrawCellText(X, Y, aInvoice.Supplier.INN, 9);

  // КПП
  X += aINNValueW;
  DrawRect(X, Y, aKPPLabelW, aRowINNKPPH);
  DrawCellText(X, Y, 'КПП', 7);
  X += aKPPLabelW;
  DrawRect(X, Y, aKPPValueW, aRowINNKPPH);
  DrawCellText(X, Y, aInvoice.Supplier.KPP, 9);

  // Расчётный счёт
  X += aKPPValueW;
  DrawRect(X, Y, aAccountLabelW, aAccountLabelH);
  DrawCellText(X, Y, 'Сч. №', 7);
  X += aAccountLabelW;
  DrawRect(X, Y, aAccountValueW, aAccountValueH);
  DrawCellText(X, Y, aInvoice.Bank.Account, 9);
  Y += aRowINNKPPH;

  // ========================================================================
  // Получатель
  //
  // ┌───────────────────────────────────────┬───────┬───────────────────────┐
  // │                                       │       │                       │
  // │          Получатель                   │       │                       │
  // │                                       │       │                       │
  // └───────────────────────────────────────┴───────┴───────────────────────┘
  // ========================================================================

  DrawRect(fXLeft, Y, aBankMainW, aRowReceiverH);
  DrawCellText(fXLeft, Y, aInvoice.Supplier.Name, 10);
  DrawCellText(fXLeft, Y + aRowBankLabelH, 'Получатель', 7);

  // Вертикальная часть справа.
  // Продолжаем колонку "Сч. №" из строки выше.
  X := fXLeft + aBankMainW;
  //DrawRect(X, Y, aBankLabelW, aRowReceiverH);
  //DrawRect(X + aBankLabelW, Y, aBankValueW, aRowReceiverH);
  fY := Y + aRowReceiverH + 10;
end;

procedure TInvoicePDFGenerator.DrawSupplierBuyer(aInvoice: TInvoice);
const
  LABEL_WIDTH = 28;   // мм — колонка подписей
  LINE_HEIGHT = 5;    // мм — межстрочный для 11pt
var
  aXValue: Integer;
  aMaxChars: Integer;

  function BuildPartyText(const aParty: TParty; aIsSupplier: Boolean): string;
  begin
    Result := aParty.Name;
    if aParty.INN <> '' then
      Result += ', ИНН ' + aParty.INN;
    if aParty.KPP <> '' then
      Result += ', КПП ' + aParty.KPP;
    if aParty.Address <> '' then
      Result += ', ' + aParty.Address;
    if aIsSupplier and (aParty.Phone <> '') then
      Result += ', тел.: ' + aParty.Phone;
  end;

  procedure DrawBlock(const ALabelLine1, ALabelLine2, AValue: string);
  var
    aYStart: Integer;
    aLabelLines, i: Integer;
    aWrapped: string;
    aSL: TStringList;
    aValueLines: Integer;
  begin
    aYStart := fY;

    // --- Подпись на 1–2 строки (мелким шрифтом) ---
    WriteSmallText(fXLeft, aYStart, ALabelLine1);
    if ALabelLine2 <> '' then
    begin
      WriteSmallText(fXLeft, aYStart + LINE_HEIGHT, ALabelLine2);
      aLabelLines := 2;
    end
    else
      aLabelLines := 1;

    // --- Перенос значения через SysUtils.WrapText ---
    aWrapped := SysUtils.WrapText(AValue, aMaxChars);

    aSL := TStringList.Create;
    try
      aSL.Text := aWrapped;               // разбивает по #13/#10/#13#10 корректно
      aValueLines := aSL.Count;
      if aValueLines = 0 then
        aValueLines := 1;

      for i := 0 to aSL.Count - 1 do
        WriteBigText(aXValue, aYStart + i * LINE_HEIGHT, aSL[i]);
    finally
      aSL.Free;
    end;

    // --- Сдвиг fY ---
    if aLabelLines > aValueLines then
      fY := aYStart + aLabelLines * LINE_HEIGHT + 3
    else
      fY := aYStart + aValueLines * LINE_HEIGHT + 3;
  end;

begin
  aXValue := fXLeft + LABEL_WIDTH;

  // Расчёт aMaxChars для SysUtils.WrapText.
  // Для Arial 11pt средняя ширина символа ≈ 2.3 мм.
  // CONTENT_WIDTH - LABEL_WIDTH - 2 ≈ 150 мм → примерно 65 символов.
  // Если перенос работает раньше/позже нужного — подкрутить коэффициент 2.0.
  aMaxChars := Round((CONTENT_WIDTH - LABEL_WIDTH - 2) / 1.7);
  if aMaxChars < 20 then
    aMaxChars := 50; // защита от деления на ноль при странных константах

  // Поставщик
  DrawBlock('Поставщик', '(Исполнитель):',
            BuildPartyText(aInvoice.Supplier, True));

  // Покупатель
  DrawBlock('Покупатель', '(Заказчик):',
            BuildPartyText(aInvoice.Buyer, False));

  // Основание
  if aInvoice.Basis <> '' then
    DrawBlock('Основание:', '', aInvoice.Basis);
end;

procedure TInvoicePDFGenerator.DrawItemsTable(aInvoice: TInvoice);
const
  HEADER_HEIGHT = 8;
  ROW_MIN_HEIGHT = 7;
  LINE_HEIGHT = 4.5;
  NAME_MAX_COL = 65; // подбор под ширину 94 мм и шрифт 10pt
var
  i, j: Integer;
  Y, RowHeight: Integer;
  aItem: TInvoiceItem;
  aNameWrapped: string;
  aNameLines: TStringList;
  aColX: array[0..6] of Integer;
  aPriceStr, aAmountStr, aQtyStr: string;
begin
  if AInvoice.Items.Count = 0 then Exit;

  // X-координаты границ колонок
  aColX[0] := fXLeft;
  aColX[1] := aColX[0] + ITEM_NO_WIDTH;
  aColX[2] := aColX[1] + ITEM_NAME_WIDTH;
  aColX[3] := aColX[2] + ITEM_QTY_WIDTH;
  aColX[4] := aColX[3] + ITEM_UNIT_WIDTH;
  aColX[5] := aColX[4] + ITEM_PRICE_WIDTH;
  aColX[6] := aColX[5] + ITEM_AMOUNT_WIDTH; // = 195

  Y := fY;

  // --- Заголовок ---
  fPage.SetFont(fFont, 10);
  for i := 0 to 5 do
    DrawRect(aColX[i], Y, aColX[i+1] - aColX[i], HEADER_HEIGHT);

  fPage.WriteText(aColX[0] + 2, Y + 5, H1);
  fPage.WriteText(aColX[1] + 2, Y + 5, H2);
  fPage.WriteText(aColX[2] + 2, Y + 5, H3);
  fPage.WriteText(aColX[3] + 2, Y + 5, H4);
  fPage.WriteText(aColX[4] + 2, Y + 5, H5);
  fPage.WriteText(aColX[5] + 2, Y + 5, H6);

  Y += HEADER_HEIGHT;

  // --- Строки с товарами ---
  aNameLines := TStringList.Create;
  try
    for i := 0 to AInvoice.Items.Count - 1 do
    begin
      aItem := AInvoice.Items[i];

      // Перенос наименования по словам
      aNameWrapped := SysUtils.WrapText(aItem.Name, NAME_MAX_COL);
      aNameLines.Text := aNameWrapped;
      if aNameLines.Count = 0 then
        aNameLines.Add(aItem.Name);

      // Высота строки по самой высокой ячейке (обычно по наименованию)
      RowHeight := Round(aNameLines.Count * LINE_HEIGHT + 3);
      if RowHeight < ROW_MIN_HEIGHT then
        RowHeight := ROW_MIN_HEIGHT;

      // Рамки ячеек
      for j := 0 to 5 do
        DrawRect(aColX[j], Y, aColX[j+1] - aColX[j], RowHeight);

      fPage.SetFont(fFont, 10);

      // № п/п
      fPage.WriteText(aColX[0] + 2, Y + 5, IntToStr(i + 1));

      // Наименование (многострочное)
      for j := 0 to aNameLines.Count - 1 do
        fPage.WriteText(aColX[1] + 2, Y + 5 + Round(j * LINE_HEIGHT), aNameLines[j]);

      // Кол-во
      aQtyStr := FormatFloat('0.###', aItem.Quantity, _dsplyFormatSettings);
      fPage.WriteText(aColX[2] + 2, Y + 5, aQtyStr);

      // Ед. изм.
      fPage.WriteText(aColX[3] + 2, Y + 5, aItem.UnitName);

      // Цена (приближенно по правому краю ячейки)
      aPriceStr := FormatFloat('#,##0.00', aItem.Price, _dsplyFormatSettings);
      fPage.WriteText(aColX[4] + ITEM_PRICE_WIDTH - Round(Length(aPriceStr) * 1.8) - 2, Y + 5, aPriceStr);

      // Сумма (приближенно по правому краю ячейки)
      aAmountStr := FormatFloat('#,##0.00', aItem.Amount, _dsplyFormatSettings);
      fPage.WriteText(aColX[5] + ITEM_AMOUNT_WIDTH - Round(Length(aAmountStr) * 1.8) - 2, Y + 5, aAmountStr);

      Y += RowHeight;
    end;
  finally
    aNameLines.Free;
  end;

  fY := Y + 8; // отступ после таблицы
end;

// ---------------------------------------------------------------------------
// Итоги под таблицей
// ---------------------------------------------------------------------------

procedure TInvoicePDFGenerator.DrawInvoiceSummary(aInvoice: TInvoice);
var
  aTotalStr: string;
  aXRight: Integer;
begin
  aXRight := fXLeft + CONTENT_WIDTH;
  aTotalStr := FormatFloat('#,##0.00', aInvoice.TotalAmount, _dsplyFormatSettings);

  // --- Правый блок ---
  WriteBigText(aXRight - 85, fY, 'Итого:');
  WriteBigText(aXRight - 30, fY, aTotalStr);
  fY += 6;

  if aInvoice.WithoutVAT then
  begin
    WriteBigText(aXRight - 85, fY, 'Без налога (НДС)');
    WriteBigText(aXRight - 30, fY, '-');
  end
  else
  begin
    WriteBigText(aXRight - 85, fY, 'В т.ч. НДС');
    WriteBigText(aXRight - 30, fY, '-'); // при необходимости посчитай НДС отдельно
  end;
  fY += 6;

  WriteBigText(aXRight - 85, fY, 'Всего к оплате:');
  WriteBigText(aXRight - 30, fY, aTotalStr);
  fY += 10;

  // --- Левый блок ---
  WriteBigText(fXLeft, fY, Format('Всего наименований %d, на сумму %s %s.',
    [aInvoice.Items.Count, aTotalStr, aInvoice.Currency]));
  fY += 6;

  WriteBigText(fXLeft, fY, SumInWords(aInvoice.TotalAmount));
  fY += 10;
end;

procedure TInvoicePDFGenerator.DrawTotals(aInvoice: TInvoice);
var
  aTotalStr: string;
begin
  aTotalStr := FormatFloat('#,##0.00', aInvoice.TotalAmount, _dsplyFormatSettings) + ' ' + aInvoice.Currency;

  WriteBigText(fXLeft, fY, 'Сумма платежа: ' + aTotalStr);
  fY += 16;

  if aInvoice.WithoutVAT then
    WriteBigText(fXLeft, fY, 'НДС не облагается')
  else
    WriteBigText(fXLeft, fY, 'В т.ч. НДС');

  fY += 20;
end;

procedure TInvoicePDFGenerator.DrawPayerInfo(aInvoice: TInvoice);
begin
  WriteBigText(fXLeft, fY, 'Плательщик: ' + aInvoice.Buyer.Name);
  fY += 15;

  if aInvoice.Buyer.INN <> '' then
  begin
    WriteBigText(fXLeft, fY, 'ИНН: ' + aInvoice.Buyer.INN);
    fY += 15;
  end;

  if aInvoice.Buyer.KPP <> '' then
  begin
    WriteBigText(fXLeft, fY, 'КПП: ' + aInvoice.Buyer.KPP);
    fY += 15;
  end;
end;

procedure TInvoicePDFGenerator.DrawPaymentTerms(aInvoice: TInvoice);
var
  aDueDateStr: string;
begin
  // Строка со сроком оплаты
  if aInvoice.DueDate > 0 then
  begin
    aDueDateStr := FormatDateTime('dd.mm.yyyy', aInvoice.DueDate);
    WriteSmallText(fXLeft, fY, 'Оплатить не позднее ' + aDueDateStr);
    fY := fY + 6;
  end;

  // Три предложения условий
  WriteSmallText(fXLeft, fY, 'Оплата данного счета означает согласие с условиями поставки товара.');
  fY += 6;

  WriteSmallText(fXLeft, fY,
    'Уведомление об оплате обязательно, в противном случае не гарантируется наличие товара на складе.');
  fY += 6;

  WriteSmallText(fXLeft, fY,
    'Товар отпускается по факту прихода денег на р/с Поставщика, самовывозом, при наличии доверенности и паспорта.');
  fY += 10;
end;

function TInvoicePDFGenerator.Generate(aInvoice: TInvoice): TMemoryStream;
var
  aDoc: TPDFDocument;
  aSection: TPDFSection;
begin
  if aInvoice = nil then
    raise Exception.Create('TInvoicePDFGenerator.Generate: AInvoice is nil');

  Result := TMemoryStream.Create;
  aDoc := TPDFDocument.Create(nil);
  try
    aDoc.Options := [poPageOriginAtTop];
    aDoc.DefaultPaperType := ptA4;
    aDoc.DefaultOrientation := ppoPortrait;

    aDoc.StartDocument;

    aSection := aDoc.Sections.AddSection;

    fPage := aDoc.Pages.AddPage;
    fPage.UnitOfMeasure := uomMillimeters;
    fPage.PaperType := ptA4;
    fPage.Orientation := ppoPortrait;

    aSection.AddPage(fPage);

    // Шрифт
    if fFontFilePath <> '' then
      fFont := aDoc.AddFont(fFontFilePath, fFontName)
    else
      fFont := aDoc.AddFont(fFontName);

    fXLeft := MARGIN_LEFT;
    fY := MARGIN_TOP;

    DrawBankDetails(aInvoice);
    DrawTitle(aInvoice);
    DrawSupplierBuyer(aInvoice);
    DrawItemsTable(aInvoice);
    DrawInvoiceSummary(aInvoice);
    DrawPaymentTerms(aInvoice);
    DrawLine(fXLeft, fY, CONTENT_WIDTH);

    aDoc.SaveToStream(Result);
  finally
    aDoc.Free;
  end;

  Result.Position := 0;
end;

initialization
  _dsplyFormatSettings := DefaultFormatSettings;
  _dsplyFormatSettings.ThousandSeparator := ' ';
  _dsplyFormatSettings.DecimalSeparator := ',';
  _dsplyFormatSettings.DateSeparator := '.';
  _dsplyFormatSettings.ShortDateFormat := 'dd/mm/yyyy';

  Assert(ITEM_NO_WIDTH + ITEM_NAME_WIDTH + ITEM_QTY_WIDTH + ITEM_UNIT_WIDTH + ITEM_PRICE_WIDTH + ITEM_AMOUNT_WIDTH
    = CONTENT_WIDTH);

end.
