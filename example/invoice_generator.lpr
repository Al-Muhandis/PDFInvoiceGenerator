program invoice_generator;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  Classes, SysUtils, CustApp,
  invoice_pdf
  ;

type
  { TGeneratorApp }
  TGeneratorApp = class(TCustomApplication)
  protected
    procedure DoRun; override;
  private
    procedure GenerateTestInvoice(const aOutputFile: string);
    procedure WriteHelp; virtual;
  public
    constructor Create(TheOwner: TComponent); override;
  end;

const
  _UsrShrFnts = '../share/FreeSans.ttf';

{ TGeneratorApp }

constructor TGeneratorApp.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  StopOnException := True;
  CaseSensitiveOptions := False;
end;

procedure TGeneratorApp.WriteHelp;
begin
  WriteLn('PDF Invoice Generator - тестовая утилита');
  WriteLn;
  WriteLn('Использование:');
  WriteLn('  ', ExeName, ' [options]');
  WriteLn;
  WriteLn('Опции:');
  WriteLn('  -h, --help          Показать эту справку');
  WriteLn('  -o, --output FILE   Имя выходного PDF (по умолчанию: schet_test.pdf)');
  WriteLn('  -n, --number N      Номер счёта (по умолчанию: 8)');
  WriteLn;
  WriteLn('Пример:');
  WriteLn('  ', ExeName, ' -o schet_8.pdf');
  WriteLn('  ', ExeName, ' --number 15 --output test_15.pdf');
end;

procedure TGeneratorApp.GenerateTestInvoice(const aOutputFile: string);
var
  aInvoice: TInvoice;
  aGenerator: TInvoicePDFGenerator;
  aStream: TMemoryStream;
  aDocNum: Integer;
begin
  aDocNum := StrToIntDef(GetOptionValue('n', 'number'), 8);

  WriteLn('Формирование тестового счёта № ', aDocNum, ' ...');

  aInvoice := TInvoice.Create;
  try
    aInvoice.Number := aDocNum;
    aInvoice.Date := EncodeDate(2026, 3, 2);
    aInvoice.DueDate := EncodeDate(2026, 9, 3);  // Оплатить не позднее 03.09.2026

    // Поставщик
    aInvoice.Supplier.Name := 'ООО «ЧОП «ЧеКо»';
    aInvoice.Supplier.INN  := '5040146069';
    aInvoice.Supplier.KPP  := '504001001';

    // Банковские реквизиты
    aInvoice.Bank.BankName    := 'АО «АЛЬФА БАНК»';
    aInvoice.Bank.BIC         := '044525593';
    aInvoice.Bank.CorrAccount := '30101810200000000593';
    aInvoice.Bank.Account     := '40702810202110001527';

    // Покупатель
    aInvoice.Buyer.Name := 'ООО «СПЕЦИАЛИЗИРОВАННЫЙ ЗАСТРОЙЩИК «СТРОЙ-САД Премьер»»';
    aInvoice.Buyer.INN  := '7724103362';
    aInvoice.Buyer.KPP  := '502701001';

    aInvoice.Basis := 'Договор оферты №493/2 от 31.08.2026 (https://github.com/Al-Muhandis/PDFInvoiceGenerator)';

    // Позиция
    aInvoice.AddItem(
      'Охранные услуги по соглашению № 4 от 01.05.23 к Договору № 1-2017 от 31.10.17 за февраль 2026 года',
      1,
      '',
      500000.00
    );

    aInvoice.WithoutVAT := True;
    aInvoice.Currency := 'руб.';

    // === Генерация ===
    aGenerator := TInvoicePDFGenerator.Create;
    try
      // Раскомментируйте и укажите путь к TTF с кириллицей, если нужно:
      // aGenerator.FontFilePath := '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf';
      // aGenerator.FontName := 'DejaVuSans';
      aGenerator.FontFilePath:=_UsrShrFnts;
      aGenerator.FontName:='FreeSans';

      aStream := aGenerator.Generate(aInvoice);
      try
        aStream.SaveToFile(aOutputFile);
        WriteLn('Готово: ', ExpandFileName(aOutputFile));
        WriteLn('Сумма: ', FormatFloat('#,##0.00', aInvoice.TotalAmount), ' ', aInvoice.Currency);
      finally
        aStream.Free;
      end;
    finally
      aGenerator.Free;
    end;
  finally
    aInvoice.Free;
  end;
end;

procedure TGeneratorApp.DoRun;
var
  ErrorMsg: string;
  OutputFile: string;
begin
  ErrorMsg := CheckOptions('ho:n:', 'help output: number:');
  if ErrorMsg <> '' then
  begin
    ShowException(Exception.Create(ErrorMsg));
    Terminate;
    Exit;
  end;

  if HasOption('h', 'help') then
  begin
    WriteHelp;
    Terminate;
    Exit;
  end;

  // Имя выходного файла
  if HasOption('o', 'output') then
    OutputFile := GetOptionValue('o', 'output')
  else
    OutputFile := 'schet_test.pdf';

  try
    GenerateTestInvoice(OutputFile);
  except
    on E: Exception do
    begin
      WriteLn('Ошибка: ', E.Message);
      ExitCode := 1;
    end;
  end;

  Terminate;
end;

var
  Application: TGeneratorApp;

{$R *.res}

begin
  Application := TGeneratorApp.Create(nil);
  Application.Title := 'PDF Invoice Generator (test)';
  Application.Run;
  Application.Free;
end.
