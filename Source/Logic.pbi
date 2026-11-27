; Copyright (C) CheshirCa 2026 https://t.me/cheshircanest
; Non-commercial use only. See LICENSE for complete terms.

; ============================================================
;  Logic.pbi 
;  Интерфейс (Main.pb) вызывает только эти процедуры и
;  работает только с этими структурами.
;  Пока внутри демо-данные, чтобы интерфейс был живым.
;  Для отключения демо: #DEMO_DATA = #False
; ============================================================

#DEMO_DATA = #False

; ---- Тип записи ----
#KIND_EXPENSE = 0       ; расход (подписка)
#KIND_INCOME  = 1       ; приход (зарплата, аванс...)
#KIND_SAVINGS = 2       ; платёж из ранее отложенных средств

; ---- Периодичность (порядок = порядок в выпадающем списке) ----
#PERIOD_MONTH = 0       ; раз в месяц
#PERIOD_YEAR  = 1       ; раз в год
#PERIOD_WEEK  = 2       ; раз в неделю
#PERIOD_DAYS  = 3       ; каждые N дней (IntervalDays)
#PERIOD_ONCE  = 4       ; один раз

Global g_BaseCurrency.s = "RUB"     ; валюта для итогов

; ---- Маркер (точка) в ячейке календаря ----
Structure DayMarker
  Kind.i                ; #KIND_EXPENSE / #KIND_INCOME
  Color.i               ; RGB(...) или -1 = цвет по умолчанию для типа
EndStructure

; ---- Строка списка "Ближайшие" ----
Structure ListRow
  Id.i
  DueDate.i             ; дата ближайшего вхождения (PB Date)
  Name.s
  Amount.d
  Currency.s
  Kind.i
  Paid.i                ; галка "оплачено" для ближайшего вхождения
  Overdue.i             ; просрочено и не оплачено
EndStructure

; ---- Полная запись (окно добавления/редактирования) ----
Structure PaymentItem
  Id.i                  ; 0 = новая
  Kind.i
  Name.s
  Amount.d
  Currency.s
  Period.i
  IntervalDays.i
  FirstDate.i
  RemindDays.i          ; напомнить за N дней
  Color.i
  Note.s
  Paused.i
EndStructure

; ---- Итоги ----
Structure MonthTotals
  Income.d              ; приход за месяц
  Expense.d             ; расход за месяц
  SubsPerMonth.d        ; сумма всех подписок в месяц
  SubsPerYear.d         ; сумма всех подписок в год
EndStructure

; ---- Напоминание для всплывающего окошка ----
Structure ReminderInfo
  Id.i
  Text.s                ; например "Подписка, завтра, 499.00 RUB"
EndStructure



#OVERDUE_KEEP_DAYS = 7
#SNOOZE_HOURS = 2

Import "Kernel32.lib"
  ReplaceFileW(*replaced, *replacement, *backup, flags.l, *exclude, *reserved)
EndImport

Structure StoredItem
  Item.PaymentItem
  PaidOccurrence.i
  SnoozeUntil.q
  LastNotified.i
EndStructure

Structure StorageData
  BaseCurrency.s
  Language.s
  DND.i
  NextId.i
  List Items.StoredItem()
EndStructure

Global g_Data.StorageData
Global g_DataPath.s

; Отсутствующая настройка в старых файлах означает русский язык.
Procedure.s Tr(Russian.s, English.s)
  If g_Data\Language = "en" : ProcedureReturn English : EndIf
  ProcedureReturn Russian
EndProcedure

Procedure Logic_SetLanguage(Language.s)
  If Language <> "en" : Language = "ru" : EndIf
  g_Data\Language = Language
EndProcedure

; Дата приводится к полудню: сравнения выполняются по календарным дням.
Procedure.i L_Day(d.i)
  If d = 0 : ProcedureReturn 0 : EndIf
  ProcedureReturn Date(Year(d), Month(d), Day(d), 12, 0, 0)
EndProcedure

Procedure.i L_LastDay(y.i, m.i)
  Protected nextMonth.i, nextYear.i
  nextMonth = m + 1 : nextYear = y
  If nextMonth = 13 : nextMonth = 1 : nextYear + 1 : EndIf
  ProcedureReturn Day(Date(nextYear, nextMonth, 1, 12, 0, 0) - 86400)
EndProcedure

; Первое вхождение на дату X или после неё. Даты PB представлены как
; календарные секунды, поэтому разница полудней не зависит от перехода DST.
Procedure.i L_Next(*item.PaymentItem, x.i)
  Protected first.i = L_Day(*item\FirstDate), target.i = L_Day(x)
  Protected y.i, m.i, d.i, n.i, interval.i, result.i
  If first = 0 : ProcedureReturn 0 : EndIf
  If target < first : target = first : EndIf
  Select *item\Period
    Case #PERIOD_ONCE
      If first >= target : ProcedureReturn first : EndIf
    Case #PERIOD_WEEK, #PERIOD_DAYS
      If *item\Period = #PERIOD_WEEK : interval = 7 : Else : interval = *item\IntervalDays : EndIf
      If interval < 1 : interval = 1 : EndIf
      n = (target - first) / 86400
      n = (n + interval - 1) / interval
      ProcedureReturn first + n * interval * 86400
    Case #PERIOD_MONTH
      y = Year(target) : m = Month(target) : d = Day(first)
      If d > L_LastDay(y,m) : d = L_LastDay(y,m) : EndIf
      result = Date(y,m,d,12,0,0)
      If result < target
        m + 1 : If m > 12 : m = 1 : y + 1 : EndIf
        d = Day(first) : If d > L_LastDay(y,m) : d = L_LastDay(y,m) : EndIf
        result = Date(y,m,d,12,0,0)
      EndIf
      ProcedureReturn result
    Case #PERIOD_YEAR
      y = Year(target) : m = Month(first) : d = Day(first)
      If d > L_LastDay(y,m) : d = L_LastDay(y,m) : EndIf
      result = Date(y,m,d,12,0,0)
      If result < target
        y + 1 : d = Day(first)
        If d > L_LastDay(y,m) : d = L_LastDay(y,m) : EndIf
        result = Date(y,m,d,12,0,0)
      EndIf
      ProcedureReturn result
  EndSelect
  ProcedureReturn 0
EndProcedure

Procedure.i L_Find(Id.i)
  ForEach g_Data\Items()
    If g_Data\Items()\Item\Id = Id : ProcedureReturn #True : EndIf
  Next
  ProcedureReturn #False
EndProcedure

; Оплаченная будущая дата остаётся в списке до её прохождения.
Procedure.i L_Nearest(*s.StoredItem, today.i)
  Protected d.i
  If *s\Item\Kind = #KIND_EXPENSE Or *s\Item\Kind = #KIND_SAVINGS
    ; Разовый неоплаченный платёж сохраняется в списке и после семи дней.
    If *s\Item\Period = #PERIOD_ONCE And L_Day(*s\Item\FirstDate) < today
      If L_Day(*s\Item\FirstDate) <> *s\PaidOccurrence : ProcedureReturn L_Day(*s\Item\FirstDate) : EndIf
      ProcedureReturn 0
    EndIf
    d = L_Next(@*s\Item, today - #OVERDUE_KEEP_DAYS * 86400)
    While d And d < today
      If d <> *s\PaidOccurrence : ProcedureReturn d : EndIf
      d = L_Next(@*s\Item, d + 86400)
    Wend
  EndIf
  ProcedureReturn L_Next(@*s\Item, today)
EndProcedure

Procedure Logic_Save()
  Protected j.i, temp.s, backup.s
  If g_DataPath = "" : ProcedureReturn : EndIf
  g_Data\BaseCurrency = g_BaseCurrency
  temp = g_DataPath + ".tmp"
  backup = GetPathPart(g_DataPath) + "data.bak"
  j = CreateJSON(#PB_Any)
  If j = 0 : ProcedureReturn : EndIf
  InsertJSONStructure(JSONValue(j), @g_Data, StorageData)
  If SaveJSON(j, temp, #PB_JSON_PrettyPrint)
    ; PureBasic RenameFile не выполняет атомарную замену с резервной копией.
    ; ReplaceFile объединяет оба действия; MoveFileEx нужен для первого файла.
    If FileSize(g_DataPath) >= 0
      If ReplaceFileW(@g_DataPath, @temp, @backup, 0, 0, 0) = 0
        MessageRequester(Tr("Ошибка сохранения", "Save error"), Tr("Не удалось заменить файл данных. Временная копия сохранена: ", "Could not replace the data file. Temporary copy: ") + temp)
      EndIf
    ElseIf MoveFileEx_(temp, g_DataPath, $8) = 0
      MessageRequester(Tr("Ошибка сохранения", "Save error"), Tr("Не удалось сохранить файл данных: ", "Could not save the data file: ") + temp)
    EndIf
  Else
    MessageRequester(Tr("Ошибка сохранения", "Save error"), Tr("Не удалось записать файл данных: ", "Could not write the data file: ") + temp)
  EndIf
  FreeJSON(j)
EndProcedure

Procedure Logic_Load()
  Protected dir.s = GetEnvironmentVariable("APPDATA") + "\PaymentTracker\"
  Protected j.i, corrupt.s, seq.i, valid.i, member.i
  ClearStructure(@g_Data, StorageData) : InitializeStructure(@g_Data, StorageData)
  g_Data\BaseCurrency = "RUB" : g_Data\NextId = 1
  If FileSize(dir) <> -2 : CreateDirectory(dir) : EndIf
  g_DataPath = dir + "data.json"
  If FileSize(g_DataPath) >= 0
    j = LoadJSON(#PB_Any, g_DataPath)
    valid = #False
    If j And JSONType(JSONValue(j)) = #PB_JSON_Object
      member = GetJSONMember(JSONValue(j), "Items")
      If member And JSONType(member) = #PB_JSON_Array : valid = #True : EndIf
    EndIf
    If valid
      ExtractJSONStructure(JSONValue(j), @g_Data, StorageData)
      FreeJSON(j)
    Else
      If j : FreeJSON(j) : EndIf
      corrupt = dir + "data.corrupt-" + FormatDate("%yyyy%mm%dd-%hh%ii%ss", Date()) + ".json"
      While FileSize(corrupt) <> -1
        seq + 1 : corrupt = dir + "data.corrupt-" + FormatDate("%yyyy%mm%dd-%hh%ii%ss", Date()) + "-" + Str(seq) + ".json"
      Wend
      If RenameFile(g_DataPath, corrupt) = 0
        MessageRequester(Tr("Ошибка данных", "Data error"), Tr("Не удалось переименовать повреждённый файл: ", "Could not rename the damaged file: ") + g_DataPath)
        g_DataPath = ""
      EndIf
    EndIf
  EndIf
  ; Ранее установленную базовую валюту EUR заменяем на RUB; суммы записей не меняем.
  If g_Data\BaseCurrency = "" Or UCase(g_Data\BaseCurrency) = "EUR" : g_Data\BaseCurrency = "RUB" : EndIf
  g_BaseCurrency = g_Data\BaseCurrency
  If g_Data\Language <> "en" : g_Data\Language = "ru" : EndIf
  If g_Data\NextId < 1 : g_Data\NextId = 1 : EndIf
  ForEach g_Data\Items()
    If g_Data\Items()\Item\Id >= g_Data\NextId : g_Data\NextId = g_Data\Items()\Item\Id + 1 : EndIf
  Next
EndProcedure

Procedure Logic_GetDayMarkers(DayDate.i, List Markers.DayMarker())
  Protected d.i = L_Day(DayDate)
  ClearList(Markers())
  ForEach g_Data\Items()
    If g_Data\Items()\Item\Paused = 0 And L_Next(@g_Data\Items()\Item, d) = d
      AddElement(Markers()) : Markers()\Kind = g_Data\Items()\Item\Kind : Markers()\Color = -1
    EndIf
  Next
EndProcedure

Procedure Logic_GetUpcoming(List Rows.ListRow(), FilterDate.i)
  Protected d.i, today.i = L_Day(Date()), filtered.i = L_Day(FilterDate), i.i, groupStart.i, groupDate.i
  ClearList(Rows())
  ForEach g_Data\Items()
    If g_Data\Items()\Item\Paused : Continue : EndIf
    If filtered
      d = L_Next(@g_Data\Items()\Item, filtered)
      If d <> filtered : Continue : EndIf
    Else
      d = L_Nearest(@g_Data\Items(), today)
      If d = 0 : Continue : EndIf
    EndIf
    AddElement(Rows())
    Rows()\Id = g_Data\Items()\Item\Id : Rows()\DueDate = d
    Rows()\Name = g_Data\Items()\Item\Name : Rows()\Amount = g_Data\Items()\Item\Amount
    Rows()\Currency = g_Data\Items()\Item\Currency : Rows()\Kind = g_Data\Items()\Item\Kind
    Rows()\Paid = Bool(d = g_Data\Items()\PaidOccurrence)
    Rows()\Overdue = Bool((Rows()\Kind = #KIND_EXPENSE Or Rows()\Kind = #KIND_SAVINGS) And d < today And Rows()\Paid = 0)
  Next
  ; Для равных дат сортируем каждую группу отдельно по имени.
  SortStructuredList(Rows(), #PB_Sort_Ascending, OffsetOf(ListRow\DueDate), TypeOf(ListRow\DueDate))
  If ListSize(Rows()) > 1
    FirstElement(Rows()) : groupDate = Rows()\DueDate : groupStart = 0
    For i = 1 To ListSize(Rows())
      If i = ListSize(Rows())
        d = -1
      Else
        SelectElement(Rows(), i) : d = Rows()\DueDate
      EndIf
      If d <> groupDate
        If i - groupStart > 1
          SortStructuredList(Rows(), #PB_Sort_Ascending, OffsetOf(ListRow\Name), TypeOf(ListRow\Name), groupStart, i - 1)
        EndIf
        groupStart = i : groupDate = d
      EndIf
    Next
  EndIf
EndProcedure

Procedure Logic_GetMonthTotals(ForYear.i, ForMonth.i, *T.MonthTotals)
  Protected first.i, last.i, d.i, count.i, n.i
  ClearStructure(*T, MonthTotals)
  If ForMonth < 1 Or ForMonth > 12 : ProcedureReturn : EndIf
  first = Date(ForYear, ForMonth, 1, 12, 0, 0)
  last = Date(ForYear, ForMonth, L_LastDay(ForYear,ForMonth), 12, 0, 0)
  ForEach g_Data\Items()
    If g_Data\Items()\Item\Paused Or g_Data\Items()\Item\Kind = #KIND_SAVINGS Or UCase(g_Data\Items()\Item\Currency) <> UCase(g_BaseCurrency) : Continue : EndIf
    count = 0 : d = L_Next(@g_Data\Items()\Item, first)
    While d And d <= last
      count + 1 : d = L_Next(@g_Data\Items()\Item, d + 86400)
    Wend
    If g_Data\Items()\Item\Kind = #KIND_INCOME
      *T\Income + count * g_Data\Items()\Item\Amount
    Else
      *T\Expense + count * g_Data\Items()\Item\Amount
      Select g_Data\Items()\Item\Period
        Case #PERIOD_MONTH : *T\SubsPerMonth + g_Data\Items()\Item\Amount
        Case #PERIOD_YEAR : *T\SubsPerMonth + g_Data\Items()\Item\Amount / 12.0
        Case #PERIOD_WEEK : *T\SubsPerMonth + g_Data\Items()\Item\Amount * 52.0 / 12.0
        Case #PERIOD_DAYS
          n = g_Data\Items()\Item\IntervalDays : If n < 1 : n = 1 : EndIf
          *T\SubsPerMonth + g_Data\Items()\Item\Amount * 30.4375 / n
      EndSelect
    EndIf
  Next
  *T\SubsPerYear = *T\SubsPerMonth * 12
EndProcedure

Procedure.i Logic_GetItem(Id.i, *Item.PaymentItem)
  If L_Find(Id) : CopyStructure(@g_Data\Items()\Item, *Item, PaymentItem) : ProcedureReturn #True : EndIf
  ProcedureReturn #False
EndProcedure

Procedure.i Logic_SaveItem(*Item.PaymentItem)
  If Trim(*Item\Name) = "" Or *Item\Amount <= 0 Or *Item\FirstDate = 0 Or *Item\Period < #PERIOD_MONTH Or *Item\Period > #PERIOD_ONCE
    MessageRequester(Tr("Платёж", "Payment"), Tr("Укажите название, положительную сумму, дату и периодичность.", "Enter a name, a positive amount, a date and a recurrence."))
    ProcedureReturn 0
  EndIf
  If *Item\IntervalDays < 1 : *Item\IntervalDays = 1 : EndIf
  If *Item\RemindDays < 0 : *Item\RemindDays = 0 : EndIf
  If *Item\Id = 0
    AddElement(g_Data\Items()) : *Item\Id = g_Data\NextId : g_Data\NextId + 1
  ElseIf L_Find(*Item\Id) = 0
    ProcedureReturn 0
  ElseIf *Item\Kind <> g_Data\Items()\Item\Kind Or *Item\Period <> g_Data\Items()\Item\Period Or *Item\IntervalDays <> g_Data\Items()\Item\IntervalDays Or L_Day(*Item\FirstDate) <> L_Day(g_Data\Items()\Item\FirstDate)
    g_Data\Items()\PaidOccurrence = 0 : g_Data\Items()\SnoozeUntil = 0 : g_Data\Items()\LastNotified = 0
  EndIf
  CopyStructure(*Item, @g_Data\Items()\Item, PaymentItem)
  g_Data\Items()\Item\FirstDate = L_Day(*Item\FirstDate)
  Logic_Save()
  ProcedureReturn *Item\Id
EndProcedure

Procedure Logic_DeleteItem(Id.i)
  If L_Find(Id) : DeleteElement(g_Data\Items()) : Logic_Save() : EndIf
EndProcedure

Procedure Logic_SetPaid(Id.i, Paid.i)
  Protected d.i
  If L_Find(Id) And (g_Data\Items()\Item\Kind = #KIND_EXPENSE Or g_Data\Items()\Item\Kind = #KIND_SAVINGS)
    d = L_Nearest(@g_Data\Items(), L_Day(Date()))
    If Paid : g_Data\Items()\PaidOccurrence = d : Else : g_Data\Items()\PaidOccurrence = 0 : g_Data\Items()\LastNotified = 0 : EndIf
    g_Data\Items()\SnoozeUntil = 0
    Logic_Save()
  EndIf
EndProcedure

Procedure.s L_When(d.i, today.i)
  Protected n.i = (d - today) / 86400, word.s
  If g_Data\Language = "en"
    If n = -1 : ProcedureReturn "1 day overdue" : EndIf
    If n < 0 : ProcedureReturn Str(-n) + " days overdue" : EndIf
    If n = 0 : ProcedureReturn "today" : EndIf
    If n = 1 : ProcedureReturn "tomorrow" : EndIf
    ProcedureReturn "in " + Str(n) + " days"
  EndIf
  If n < 0 : ProcedureReturn "просрочен на " + Str(-n) + " дн." : EndIf
  If n = 0 : ProcedureReturn "сегодня" : EndIf
  If n = 1 : ProcedureReturn "завтра" : EndIf
  word = "дней"
  If n % 100 < 11 Or n % 100 > 14
    Select n % 10
      Case 1 : word = "день"
      Case 2,3,4 : word = "дня"
    EndSelect
  EndIf
  ProcedureReturn "через " + Str(n) + " " + word
EndProcedure

Procedure.s Logic_GetNearestText()
  Protected today.i = L_Day(Date()), d.i, best.i = 0, result.s
  ForEach g_Data\Items()
    If g_Data\Items()\Item\Paused Or (g_Data\Items()\Item\Kind <> #KIND_EXPENSE And g_Data\Items()\Item\Kind <> #KIND_SAVINGS) : Continue : EndIf
    d = L_Nearest(@g_Data\Items(), today)
    If d And d = g_Data\Items()\PaidOccurrence
      d = L_Next(@g_Data\Items()\Item, d + 86400)
    EndIf
    If d And (best = 0 Or d < best)
      best = d
      result = g_Data\Items()\Item\Name + ", " + L_When(d,today) + ", " + StrD(g_Data\Items()\Item\Amount,2) + " " + g_Data\Items()\Item\Currency
    EndIf
  Next
  If best = 0 : ProcedureReturn Tr("Нет предстоящих платежей", "No upcoming payments") : EndIf
  ProcedureReturn Left(result,120)
EndProcedure

 ; Текст уже открытого уведомления можно перевести без повторного показа.
Procedure.s Logic_ReminderText(Id.i)
  Protected d.i
  If L_Find(Id)
    d = L_Nearest(@g_Data\Items(), L_Day(Date()))
    If d
      ProcedureReturn g_Data\Items()\Item\Name + ": " + L_When(d, L_Day(Date())) + ", " + StrD(g_Data\Items()\Item\Amount, 2) + " " + g_Data\Items()\Item\Currency
    EndIf
  EndIf
  ProcedureReturn ""
EndProcedure

Procedure.i Logic_PopReminder(*R.ReminderInfo)
  Protected today.i = L_Day(Date()), now.q = DateUTC(), d.i
  If g_Data\DND : ProcedureReturn #False : EndIf
  ForEach g_Data\Items()
    If g_Data\Items()\Item\Paused Or (g_Data\Items()\Item\Kind <> #KIND_EXPENSE And g_Data\Items()\Item\Kind <> #KIND_SAVINGS) : Continue : EndIf
    d = L_Nearest(@g_Data\Items(),today)
    If d = 0 Or d = g_Data\Items()\PaidOccurrence Or d > today + g_Data\Items()\Item\RemindDays * 86400 : Continue : EndIf
    If g_Data\Items()\SnoozeUntil > now : Continue : EndIf
    If g_Data\Items()\LastNotified = today And g_Data\Items()\SnoozeUntil = 0 : Continue : EndIf
    *R\Id = g_Data\Items()\Item\Id
    *R\Text = g_Data\Items()\Item\Name + ": " + L_When(d,today) + ", " + StrD(g_Data\Items()\Item\Amount,2) + " " + g_Data\Items()\Item\Currency
    g_Data\Items()\LastNotified = today : g_Data\Items()\SnoozeUntil = 0
    Logic_Save() : ProcedureReturn #True
  Next
  ProcedureReturn #False
EndProcedure

Procedure Logic_Snooze(Id.i)
  If L_Find(Id) : g_Data\Items()\SnoozeUntil = DateUTC() + #SNOOZE_HOURS * 3600 : Logic_Save() : EndIf
EndProcedure

Procedure Logic_SetDND(State.i)
  g_Data\DND = Bool(State) : Logic_Save()
EndProcedure

Procedure.i Logic_GetDND()
  ProcedureReturn g_Data\DND
EndProcedure

; В стандартной библиотеке PB нет доступа к ключам реестра Windows.
Procedure.i Logic_GetAutostart()
  Protected key.i, size.l = 32768, typ.l, value.s = Space(16384)
  If RegOpenKeyEx_(#HKEY_CURRENT_USER, "Software\Microsoft\Windows\CurrentVersion\Run", 0, #KEY_READ, @key) = #ERROR_SUCCESS
    If RegQueryValueEx_(key, "PaymentTracker", 0, @typ, @value, @size) = #ERROR_SUCCESS And typ = #REG_SZ
      RegCloseKey_(key)
      ProcedureReturn Bool(LCase(value) = LCase(Chr(34) + ProgramFilename() + Chr(34)))
    EndIf
    RegCloseKey_(key)
  EndIf
  ProcedureReturn #False
EndProcedure

Procedure Logic_SetAutostart(State.i)
  Protected key.i, value.s = Chr(34) + ProgramFilename() + Chr(34), rc.i
  If RegOpenKeyEx_(#HKEY_CURRENT_USER, "Software\Microsoft\Windows\CurrentVersion\Run", 0, #KEY_SET_VALUE, @key) = #ERROR_SUCCESS
    If State
      rc = RegSetValueEx_(key, "PaymentTracker", 0, #REG_SZ, @value, (Len(value) + 1) * 2)
    Else
      rc = RegDeleteValue_(key, "PaymentTracker")
      If rc = #ERROR_FILE_NOT_FOUND : rc = #ERROR_SUCCESS : EndIf
    EndIf
    RegCloseKey_(key)
    If rc = #ERROR_SUCCESS : ProcedureReturn : EndIf
  EndIf
  MessageRequester(Tr("Автозапуск", "Startup"), Tr("Не удалось изменить настройку автозапуска.", "Could not change the startup setting."))
EndProcedure
