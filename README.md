# PDFInvoiceGenerator

Генератор счетов на оплату в формате PDF для **Free Pascal / Lazarus**.

## Описание

Библиотека для программного формирования счетов на оплату в PDF согласно общепринятому российскому шаблону. Использует встроенный в FPC модуль `fppdf` (пакет **fcl-pdf**), не требует внешних зависимостей.

## Требования

*   Free Pascal Compiler ≥ 3.0
*   Модуль `fppdf` из поставки FCL (пакет `fcl-pdf`)
*   Lazarus — опционально (можно использовать и в консольном приложении)

## Установка

```bash
git clone https://github.com/Al-Muhandis/PDFInvoiceGenerator.git
```
Добавьте пакет `pdf_invoice_generator.lpk` в зависимости проекта (в Lazarus IDE) или укажите путь к `src/invoice_pdf.pas`, если используется только FPC.

## Быстрый старт

```pascal
uses
  invoice_pdf, SysUtils, Classes;

var
  Invoice: TInvoice;
  Generator: TInvoicePDFGenerator;
  Stream: TMemoryStream;
begin
  Invoice := TInvoice.Create;
  try
    // --- Шапка счёта ---
    Invoice.Number   := 101;
    Invoice.Date     := EncodeDate(2026, 10, 3);
    Invoice.DueDate  := EncodeDate(2026, 10, 17);
    Invoice.Currency := '₽';
    Invoice.WithoutVAT := True;
    Invoice.Basis := 'Договор № Д‑101/2026 от 25.09.2026, акт выполненных работ № А‑101 от 02.10.2026';

    // --- Банковские реквизиты ---
    Invoice.Bank.BankName    := 'ПАО «Банк Пример»';
    Invoice.Bank.BIC         := '044525111';
    Invoice.Bank.CorrAccount := '30101810200000000111';
    Invoice.Bank.Account     := '40702810100000001234';

    // --- Поставщик ---
    Invoice.Supplier.Name    := 'ООО «ТехноСофт»';
    Invoice.Supplier.INN     := '7701234567';
    Invoice.Supplier.KPP     := '770101001';
    Invoice.Supplier.Address := '125009, г. Москва, ул. Тверская, д. 1, оф. 105';
    Invoice.Supplier.Phone   := '+7 (495) 123-45-67';

    // --- Покупатель ---
    Invoice.Buyer.Name    := 'ИП Смирнов Алексей Петрович';
    Invoice.Buyer.INN     := '502712345678';
    Invoice.Buyer.Address := '140000, Московская обл., г. Люберцы, ул. Юбилейная, д. 7, кв. 12';

    // --- Позиции (услуги) ---
    Invoice.AddItem('Разработка модуля интеграции API',         1, 'усл. ед.', 45000.00);
    Invoice.AddItem('Настройка веб-формы на сайте',             2, 'усл. ед.', 12000.00);
    Invoice.AddItem('Консультация по UX и правкам ТЗ',          3, 'час',       3500.00);

    // --- Генерация PDF ---
    Generator := TInvoicePDFGenerator.Create;
    try
      Stream := Generator.Generate(Invoice);
      try
        Stream.SaveToFile('invoice_101.pdf');
        WriteLn('Счёт сохранён: invoice_101.pdf');
      finally
        Stream.Free;
      end;
    finally
      Generator.Free;
    end;
  finally
    Invoice.Free;
  end;
end.
```

## Настройка шрифта
По умолчанию используется шрифт Arial (встроенный в fcl-pdf). Для подключения собственного TTF укажите полный путь и наименование. В репозитарии добавлены шрифты для генерации в примере.

## Лицензия
Распространяется под лицензией MIT. См. файл LICENSE.