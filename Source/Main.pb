; Copyright (C) CheshirCa 2026 https://t.me/cheshircanest
; Non-commercial use only. See LICENSE for complete terms.

; ============================================================
;  Main.pb  -  Интерфейс "Платежи и подписки"
;  PureBasic 6.41, Windows. Только UI, логика в Logic.pbi
; ============================================================

XIncludeFile "Logic.pbi"

; ---------------- Идентификаторы ----------------
Enumeration ; окна
  #WinMain
  #WinEdit
  #WinNotify
EndEnumeration

Enumeration ; гаджеты
  ; главное окно
  #BtnPrev
  #TxtMonth
  #BtnNext
  #BtnToday
  #TxtListTitle
  #CvCalendar
  #LstItems
  #TxtInfo
  #TxtTotals
  #TxtSubs
  #BtnAdd
  #BtnEdit
  #BtnDelete
  ; окно редактирования
  #EdOptExpense
  #EdOptIncome
  #EdOptSavings
  #EdName
  #EdAmount
  #EdCurrency
  #EdPeriod
  #EdInterval
  #EdDate
  #EdRemind
  #EdColor
  #EdColorBtn
  #EdNote
  #EdPaused
  #EdOk
  #EdCancel
  ; окно уведомления
  #NfBox
  #TxtNfTitle
  #TxtNfText
  #BtnNfPaid
  #BtnNfLater
EndEnumeration

Enumeration ; шрифты
  #FontNormal
  #FontBold
  #FontTitle
EndEnumeration

Enumeration ; меню трея
  #MenuTray
  #MnuOpen
  #MnuAdd
  #MnuDND
  #MnuAutostart
  #MnuLangRU
  #MnuLangEN
  #MnuExit
  #MenuList
  #MnuListAdd
  #MnuListEdit
  #MnuListDelete
  #MenuCalendar
  #MnuCalendarAdd
EndEnumeration

Enumeration ; прочее
  #ImgTray
  #Tray
EndEnumeration

#TimerReminders = 1
#TimerSnooze = 2

; Размеры календаря (в ячейках)
#CellW = 60
#CellH = 51
#HeadH = 24
#CalW  = 7 * #CellW
#CalH  = #HeadH + 6 * #CellH

; ---------------- Глобальное состояние UI ----------------
Global ViewYear.i = Year(Date())
Global ViewMonth.i = Month(Date())
Global CalendarPopupDate.i = 0       ; дата ячейки для контекстного меню
Global SelDate.i = 0               ; выбранный день (0 = не выбран)
Global NotifyId.i = 0              ; Id записи в показанном уведомлении
Global Dim ListPaid.i(0)           ; прошлое состояние галок списка

; Цвета
Global colBg.i = RGB(255, 255, 255)
Global colBgOther.i = RGB(246, 246, 246)
Global colSel.i = RGB(220, 235, 252)
Global colGrid.i = RGB(225, 225, 225)
Global colText.i = RGB(30, 30, 30)
Global colGray.i = RGB(170, 170, 170)
Global colRed.i = RGB(210, 50, 50)
Global colGreen.i = RGB(40, 150, 70)
Global colAccent.i = RGB(0, 120, 215)

; ============================================================
;  Вспомогательные процедуры
; ============================================================

Procedure.s MonthName(m.i)
  ProcedureReturn StringField(Tr("Январь,Февраль,Март,Апрель,Май,Июнь,Июль,Август,Сентябрь,Октябрь,Ноябрь,Декабрь", "January,February,March,April,May,June,July,August,September,October,November,December"), m, ",")
EndProcedure

Procedure.i SameDay(a.i, b.i)
  If a = 0 Or b = 0 : ProcedureReturn #False : EndIf
  ProcedureReturn Bool(Year(a) = Year(b) And Month(a) = Month(b) And Day(a) = Day(b))
EndProcedure

; Дата первой ячейки сетки (понедельник недели, где 1-е число месяца)
Procedure.i GridStartDate()
  Protected first.i = Date(ViewYear, ViewMonth, 1, 12, 0, 0)
  ProcedureReturn first - ((DayOfWeek(first) + 6) % 7) * 86400
EndProcedure

; Поставить окно в правый нижний угол рабочей области (над панелью задач)
Procedure PlaceWindowBottomRight(Win.i, Margin.i = 8)
  Protected r.RECT, w.i, h.i
  SystemParametersInfo_(#SPI_GETWORKAREA, 0, @r, 0)
  w = WindowWidth(Win, #PB_Window_FrameCoordinate)
  h = WindowHeight(Win, #PB_Window_FrameCoordinate)
  ResizeWindow(Win, DesktopScaledX(r\right) - w - Margin, DesktopScaledY(r\bottom) - h - Margin, #PB_Ignore, #PB_Ignore)
EndProcedure

Procedure UpdateTrayTip()
  If IsSysTrayIcon(#Tray)
    SysTrayIconToolTip(#Tray, Logic_GetNearestText())
  EndIf
EndProcedure

; ============================================================
;  Отрисовка календаря
; ============================================================

Procedure DrawCalendar()
  Protected NewList mk.DayMarker()
  Protected i.i, col.i, row.i, x.i, y.i, d.i, k.i, n.i, cx.i, c.i
  Protected start.i = GridStartDate()
  Protected txt.s, isOther.i, isToday.i, isSel.i
  Protected today.i = Date()

  If StartDrawing(CanvasOutput(#CvCalendar)) = 0 : ProcedureReturn : EndIf

  DrawingMode(#PB_2DDrawing_Default)
  Box(0, 0, #CalW, #CalH, colBg)

  ; --- заголовок дней недели ---
  DrawingFont(FontID(#FontBold))
  DrawingMode(#PB_2DDrawing_Transparent)
  For col = 0 To 6
    txt = StringField(Tr("Пн,Вт,Ср,Чт,Пт,Сб,Вс", "Mon,Tue,Wed,Thu,Fri,Sat,Sun"), col + 1, ",")
    If col >= 5 : c = colRed : Else : c = colText : EndIf
    DrawText(col * #CellW + (#CellW - TextWidth(txt)) / 2, 4, txt, c)
  Next

  ; --- 42 ячейки ---
  For i = 0 To 41
    col = i % 7 : row = i / 7
    x = col * #CellW : y = #HeadH + row * #CellH
    d = start + i * 86400
    isOther = Bool(Month(d) <> ViewMonth)
    isToday = SameDay(d, today)
    isSel = SameDay(d, SelDate)

    ; фон
    DrawingMode(#PB_2DDrawing_Default)
    If isSel
      c = colSel
    ElseIf isOther
      c = colBgOther
    Else
      c = colBg
    EndIf
    Box(x, y, #CellW, #CellH, c)

    ; сетка
    DrawingMode(#PB_2DDrawing_Outlined)
    Box(x, y, #CellW, #CellH, colGrid)

    ; рамка сегодняшнего дня
    If isToday
      Box(x + 1, y + 1, #CellW - 2, #CellH - 2, colAccent)
      Box(x + 2, y + 2, #CellW - 4, #CellH - 4, colAccent)
    EndIf

    ; число
    DrawingMode(#PB_2DDrawing_Transparent)
    If isToday : DrawingFont(FontID(#FontBold)) : Else : DrawingFont(FontID(#FontNormal)) : EndIf
    If isOther : c = colGray : Else : c = colText : EndIf
    DrawText(x + 6, y + 4, Str(Day(d)), c)

    ; маркеры (до 3 точек, дальше "+")
    Logic_GetDayMarkers(d, mk())
    n = ListSize(mk())
    If n > 0
      k = 0
      If n > 3 : cx = x + (#CellW - 3 * 12 - 10) / 2 + 6 : Else : cx = x + (#CellW - n * 12) / 2 + 6 : EndIf
      DrawingMode(#PB_2DDrawing_Default)
      ForEach mk()
        If k >= 3 : Break : EndIf
        c = mk()\Color
        If c = -1
          Select mk()\Kind
            Case #KIND_INCOME : c = colGreen
            Case #KIND_SAVINGS : c = colAccent
            Default : c = colRed
          EndSelect
        EndIf
        Circle(cx + k * 12, y + #CellH - 11, 4, c)
        k + 1
      Next
      If n > 3
        DrawingMode(#PB_2DDrawing_Transparent)
        DrawingFont(FontID(#FontBold))
        DrawText(cx + 3 * 12 - 4, y + #CellH - 20, "+", colGray)
      EndIf
    EndIf
  Next

  StopDrawing()
EndProcedure

; ============================================================
;  Список, итоги, обновление
; ============================================================

Procedure UpdateButtons()
  Protected noSel.i = Bool(GetGadgetState(#LstItems) < 0)
  DisableGadget(#BtnEdit, noSel)
  DisableGadget(#BtnDelete, noSel)
EndProcedure

Procedure RefreshList()
  Protected NewList rows.ListRow()
  Protected idx.i, amountTxt.s, sign.s, c.i

  ClearGadgetItems(#LstItems)
  Logic_GetUpcoming(rows(), SelDate)
  ReDim ListPaid(ListSize(rows()))

  ForEach rows()
    Select rows()\Kind
      Case #KIND_INCOME : sign = "+"
      Case #KIND_SAVINGS : sign = Tr("накопл. ", "saved ")
      Default : sign = "-"
    EndSelect
    amountTxt = sign + StrD(rows()\Amount, 2) + " " + rows()\Currency

    AddGadgetItem(#LstItems, -1, FormatDate("%dd.%mm", rows()\DueDate) + #LF$ + rows()\Name + #LF$ + amountTxt)
    idx = ListIndex(rows())
    SetGadgetItemData(#LstItems, idx, rows()\Id)
    ListPaid(idx) = rows()\Paid
    If rows()\Paid : SetGadgetItemState(#LstItems, idx, #PB_ListIcon_Checked) : EndIf

    ; раскраска: оплачено = серый, просрочено = красный, приход = зелёный
    c = -1
    If rows()\Kind = #KIND_INCOME
      c = colGreen
    ElseIf rows()\Paid
      c = colGray
    ElseIf rows()\Overdue
      c = colRed
    ElseIf rows()\Kind = #KIND_SAVINGS
      c = colAccent
    EndIf
    If c <> -1 : SetGadgetItemColor(#LstItems, idx, #PB_Gadget_FrontColor, c) : EndIf
  Next

  UpdateButtons()
EndProcedure

Procedure RefreshInfo()
  Protected tot.MonthTotals, t.s
  Logic_GetMonthTotals(ViewYear, ViewMonth, @tot)

  If SelDate
    t = Tr("Выбран день: ", "Selected: ") + FormatDate("%dd.%mm.%yyyy", SelDate) + Tr("  (повторный клик по дню снимает фильтр)", "  (click the day again to clear the filter)")
  Else
    t = Tr("Показаны ближайшие платежи", "Showing upcoming payments")
  EndIf
  SetGadgetText(#TxtInfo, t)

  SetGadgetText(#TxtTotals, Tr("За месяц:   приход +", "Month:   income +") + StrD(tot\Income, 2) + Tr("   |   расход -", "   |   expense -") + StrD(tot\Expense, 2) + Tr("   |   баланс ", "   |   balance ") + StrD(tot\Income - tot\Expense, 2) + " " + g_BaseCurrency)
  SetGadgetText(#TxtSubs, Tr("Подписки:   ", "Subscriptions:   ") + StrD(tot\SubsPerMonth, 2) + " " + g_BaseCurrency + Tr(" в месяц   |   ", " per month   |   ") + StrD(tot\SubsPerYear, 2) + " " + g_BaseCurrency + Tr(" в год", " per year"))
EndProcedure

Procedure RefreshAll()
  SetGadgetText(#TxtMonth, MonthName(ViewMonth) + " " + Str(ViewYear))
  DrawCalendar()
  RefreshList()
  RefreshInfo()
  UpdateTrayTip()
EndProcedure

Procedure.i SelectedId()
  Protected idx.i = GetGadgetState(#LstItems)
  If idx < 0 : ProcedureReturn 0 : EndIf
  ProcedureReturn GetGadgetItemData(#LstItems, idx)
EndProcedure

; Сравнивает галки списка с прошлым состоянием, сообщает логике об изменениях
Procedure SyncPaidStates()
  Protected i.i, checked.i, changed.i = #False, found.i
  Protected NewList nearest.ListRow()
  If SelDate : Logic_GetUpcoming(nearest(), 0) : EndIf
  For i = 0 To CountGadgetItems(#LstItems) - 1
    checked = Bool(GetGadgetItemState(#LstItems, i) & #PB_ListIcon_Checked)
    If i <= ArraySize(ListPaid()) And checked <> ListPaid(i)
      If SelDate
        found = #False
        ForEach nearest()
          If nearest()\Id = GetGadgetItemData(#LstItems, i) And SameDay(nearest()\DueDate, SelDate)
            found = #True : Break
          EndIf
        Next
        If found = #False
          If ListPaid(i) : SetGadgetItemState(#LstItems, i, #PB_ListIcon_Checked) : Else : SetGadgetItemState(#LstItems, i, 0) : EndIf
          MessageRequester(Tr("Платёж", "Payment"), Tr("Отметить можно только ближайшее вхождение записи.", "Only the nearest occurrence can be marked as paid."))
          Continue
        EndIf
      EndIf
      ListPaid(i) = checked
      Logic_SetPaid(GetGadgetItemData(#LstItems, i), checked)
      changed = #True
    EndIf
  Next
  If changed : RefreshAll() : EndIf
EndProcedure

Procedure ShiftMonth(delta.i)
  ViewMonth + delta
  If ViewMonth > 12 : ViewMonth = 1 : ViewYear + 1 : EndIf
  If ViewMonth < 1 : ViewMonth = 12 : ViewYear - 1 : EndIf
  SelDate = 0
  RefreshAll()
EndProcedure

 ; Дата ячейки под указателем, либо 0 для заголовка и вне календаря.
Procedure.i CalendarDateAtPointer()
  Protected mx.i = GetGadgetAttribute(#CvCalendar, #PB_Canvas_MouseX)
  Protected my.i = GetGadgetAttribute(#CvCalendar, #PB_Canvas_MouseY)
  If mx < 0 Or mx >= #CalW Or my < #HeadH Or my >= #CalH : ProcedureReturn 0 : EndIf
  ProcedureReturn GridStartDate() + (((my - #HeadH) / #CellH) * 7 + mx / #CellW) * 86400
EndProcedure

Procedure OnCalendarClick()
  Protected d.i = CalendarDateAtPointer()
  If d = 0 : ProcedureReturn : EndIf
  If SameDay(d, SelDate) : SelDate = 0 : Else : SelDate = d : EndIf
  RefreshAll()
EndProcedure

; ============================================================
;  Окно добавления / редактирования
; ============================================================

Procedure DrawColorPreview(Color.i)
  If StartDrawing(CanvasOutput(#EdColor))
    DrawingMode(#PB_2DDrawing_Default)
    Box(0, 0, 40, 24, Color)
    DrawingMode(#PB_2DDrawing_Outlined)
    Box(0, 0, 40, 24, RGB(120, 120, 120))
    StopDrawing()
  EndIf
EndProcedure

Procedure UpdateEditState()
  ; интервал в днях нужен только для "каждые N дней"
  DisableGadget(#EdInterval, Bool(GetGadgetState(#EdPeriod) <> #PERIOD_DAYS))
  ; для прихода напоминания не нужны
  DisableGadget(#EdRemind, Bool(GetGadgetState(#EdOptIncome) <> 0))
EndProcedure

; Модальный диалог. Возвращает #True если запись сохранена.
Procedure.i ShowEditDialog(Id.i, InitialDate.i = 0)
  Protected item.PaymentItem
  Protected done.i = #False, saved.i = #False, ev.i, c.i
  Protected title.s, amountTxt.s

  ; значения по умолчанию для новой записи
  item\Kind = #KIND_EXPENSE
  item\Currency = "RUB"
  item\Period = #PERIOD_MONTH
  item\IntervalDays = 30
  item\FirstDate = Date()
  If Id = 0 And InitialDate : item\FirstDate = InitialDate : EndIf
  item\RemindDays = 3
  item\Color = RGB(0, 120, 215)
  If Id
    Logic_GetItem(Id, @item)
    title = Tr("Изменить платёж", "Edit payment")
    amountTxt = StrD(item\Amount, 2)
  Else
    title = Tr("Новый платёж", "New payment")
  EndIf
  If item\IntervalDays < 1 : item\IntervalDays = 30 : EndIf
  c = item\Color

  If OpenWindow(#WinEdit, 0, 0, 400, 445, title, #PB_Window_SystemMenu | #PB_Window_ScreenCentered, WindowID(#WinMain)) = 0
    ProcedureReturn #False
  EndIf
  DisableWindow(#WinMain, #True)

  ; --- тип ---
  OptionGadget(#EdOptExpense, 15, 12, 120, 22, Tr("Расход", "Expense"))
  OptionGadget(#EdOptIncome, 145, 12, 85, 22, Tr("Приход", "Income"))
  OptionGadget(#EdOptSavings, 230, 12, 155, 22, Tr("Из накоплений", "From savings"))
  GadgetToolTip(#EdOptSavings, Tr("Платёж из уже отложенных средств не влияет на баланс и итоги подписок", "A payment from savings does not affect the balance or subscription totals"))
  Select item\Kind
    Case #KIND_INCOME : SetGadgetState(#EdOptIncome, #True)
    Case #KIND_SAVINGS : SetGadgetState(#EdOptSavings, #True)
    Default : SetGadgetState(#EdOptExpense, #True)
  EndSelect

  ; --- название ---
  TextGadget(#PB_Any, 15, 50, 140, 20, Tr("Название", "Name"))
  StringGadget(#EdName, 160, 47, 225, 24, item\Name)

  ; --- сумма и валюта ---
  TextGadget(#PB_Any, 15, 85, 140, 20, Tr("Сумма", "Amount"))
  StringGadget(#EdAmount, 160, 82, 105, 24, amountTxt)
  ComboBoxGadget(#EdCurrency, 275, 82, 110, 24, #PB_ComboBox_Editable)
  AddGadgetItem(#EdCurrency, -1, "RUB")
  AddGadgetItem(#EdCurrency, -1, "USD")
  AddGadgetItem(#EdCurrency, -1, "EUR")
  AddGadgetItem(#EdCurrency, -1, "GBP")
  SetGadgetText(#EdCurrency, item\Currency)

  ; --- периодичность (порядок = константы #PERIOD_*) ---
  TextGadget(#PB_Any, 15, 120, 140, 20, Tr("Периодичность", "Repeat"))
  ComboBoxGadget(#EdPeriod, 160, 117, 225, 24)
  AddGadgetItem(#EdPeriod, -1, Tr("Раз в месяц", "Monthly"))
  AddGadgetItem(#EdPeriod, -1, Tr("Раз в год", "Yearly"))
  AddGadgetItem(#EdPeriod, -1, Tr("Раз в неделю", "Weekly"))
  AddGadgetItem(#EdPeriod, -1, Tr("Каждые N дней", "Every N days"))
  AddGadgetItem(#EdPeriod, -1, Tr("Один раз", "Once"))
  SetGadgetState(#EdPeriod, item\Period)

  TextGadget(#PB_Any, 15, 155, 140, 20, Tr("Интервал, дней", "Interval, days"))
  SpinGadget(#EdInterval, 160, 152, 80, 24, 1, 365, #PB_Spin_Numeric)
  SetGadgetState(#EdInterval, item\IntervalDays)

  ; --- дата первого платежа ---
  TextGadget(#PB_Any, 15, 190, 140, 20, Tr("Дата первого платежа", "First payment"))
  DateGadget(#EdDate, 160, 187, 130, 24, "%dd.%mm.%yyyy", item\FirstDate)

  ; --- напоминание ---
  TextGadget(#PB_Any, 15, 225, 140, 20, Tr("Напомнить за (дней)", "Remind (days)"))
  SpinGadget(#EdRemind, 160, 222, 80, 24, 0, 60, #PB_Spin_Numeric)
  SetGadgetState(#EdRemind, item\RemindDays)

  ; --- цвет ---
  TextGadget(#PB_Any, 15, 260, 140, 20, Tr("Цвет", "Color"))
  CanvasGadget(#EdColor, 160, 257, 40, 24)
  ButtonGadget(#EdColorBtn, 210, 256, 120, 26, Tr("Выбрать цвет...", "Choose color..."))
  DrawColorPreview(c)

  ; --- заметка ---
  TextGadget(#PB_Any, 15, 295, 140, 20, Tr("Заметка", "Note"))
  EditorGadget(#EdNote, 160, 292, 225, 70)
  SetGadgetText(#EdNote, item\Note)

  ; --- приостановлена ---
  CheckBoxGadget(#EdPaused, 160, 372, 225, 22, Tr("Приостановлена", "Paused"))
  SetGadgetState(#EdPaused, item\Paused)

  ; --- кнопки ---
  ButtonGadget(#EdOk, 205, 408, 85, 28, "OK", #PB_Button_Default)
  ButtonGadget(#EdCancel, 300, 408, 85, 28, Tr("Отмена", "Cancel"))

  UpdateEditState()
  SetActiveGadget(#EdName)

  Repeat
    ev = WaitWindowEvent()
    Select ev
      Case #PB_Event_CloseWindow
        done = #True

      Case #PB_Event_Gadget
        Select EventGadget()
          Case #EdOptExpense, #EdOptIncome, #EdOptSavings, #EdPeriod
            UpdateEditState()

          Case #EdColorBtn
            Protected newColor.i = ColorRequester(c)
            If newColor <> -1 : c = newColor : DrawColorPreview(c) : EndIf

          Case #EdCancel
            done = #True

          Case #EdOk
            If Trim(GetGadgetText(#EdName)) = ""
              MessageRequester(Tr("Платёж", "Payment"), Tr("Введите название.", "Enter a name."))
              SetActiveGadget(#EdName)
            Else
              If GetGadgetState(#EdOptIncome)
                item\Kind = #KIND_INCOME
              ElseIf GetGadgetState(#EdOptSavings)
                item\Kind = #KIND_SAVINGS
              Else
                item\Kind = #KIND_EXPENSE
              EndIf
              item\Name = Trim(GetGadgetText(#EdName))
              item\Amount = ValD(ReplaceString(GetGadgetText(#EdAmount), ",", "."))
              item\Currency = UCase(Trim(GetGadgetText(#EdCurrency)))
              item\Period = GetGadgetState(#EdPeriod)
              item\IntervalDays = GetGadgetState(#EdInterval)
              item\FirstDate = GetGadgetState(#EdDate)
              item\RemindDays = GetGadgetState(#EdRemind)
              item\Color = c
              item\Note = GetGadgetText(#EdNote)
              item\Paused = GetGadgetState(#EdPaused)
              If Logic_SaveItem(@item)
                saved = #True
                done = #True
              EndIf
            EndIf
        EndSelect
    EndSelect
  Until done

  DisableWindow(#WinMain, #False)
  CloseWindow(#WinEdit)
  ProcedureReturn saved
EndProcedure

 ; Общие действия для кнопок и контекстного меню списка.
Procedure EditSelected()
  Protected id.i = SelectedId()
  If id And ShowEditDialog(id) : RefreshAll() : EndIf
EndProcedure

Procedure DeleteSelected()
  Protected id.i = SelectedId(), idx.i = GetGadgetState(#LstItems)
  If id And idx >= 0
    If MessageRequester(Tr("Удаление", "Delete"), Tr("Удалить «", "Delete “") + GetGadgetItemText(#LstItems, idx, 1) + Tr("»?", "”?"), #PB_MessageRequester_YesNo) = #PB_MessageRequester_Yes
      Logic_DeleteItem(id)
      RefreshAll()
    EndIf
  EndIf
EndProcedure

; У ListIconGadget нет встроенного определения строки по координатам.
; WinAPI проверяет позицию курсора; без строки доступны только добавление.
Procedure ShowListPopup()
  Protected hit.LVHITTESTINFO, row.i
  GetCursorPos_(@hit\pt)
  ScreenToClient_(GadgetID(#LstItems), @hit\pt)
  row = SendMessage_(GadgetID(#LstItems), #LVM_SUBITEMHITTEST, 0, @hit)
  If row >= 0 And (hit\flags & #LVHT_ONITEM)
    SetGadgetState(#LstItems, row)
    UpdateButtons()
    DisableMenuItem(#MenuList, #MnuListEdit, #False)
    DisableMenuItem(#MenuList, #MnuListDelete, #False)
  Else
    DisableMenuItem(#MenuList, #MnuListEdit, #True)
    DisableMenuItem(#MenuList, #MnuListDelete, #True)
  EndIf
  DisplayPopupMenu(#MenuList, WindowID(#WinMain))
EndProcedure

; ============================================================
;  Всплывающее уведомление (в углу экрана)
; ============================================================

Procedure BuildNotifyWindow()
  Protected ex.i
  If OpenWindow(#WinNotify, 0, 0, 320, 110, "", #PB_Window_BorderLess | #PB_Window_Invisible)
    ; не показывать в панели задач
    ex = GetWindowLongPtr_(WindowID(#WinNotify), #GWL_EXSTYLE)
    SetWindowLongPtr_(WindowID(#WinNotify), #GWL_EXSTYLE, ex | #WS_EX_TOOLWINDOW)
    StickyWindow(#WinNotify, #True)

    ContainerGadget(#NfBox, 0, 0, 320, 110, #PB_Container_Single)
      TextGadget(#TxtNfTitle, 10, 8, 300, 20, Tr("Скоро платёж", "Payment reminder"))
      SetGadgetFont(#TxtNfTitle, FontID(#FontBold))
      TextGadget(#TxtNfText, 10, 30, 300, 38, "")
      ButtonGadget(#BtnNfPaid, 10, 72, 145, 28, Tr("Оплачено", "Paid"))
      ButtonGadget(#BtnNfLater, 165, 72, 145, 28, Tr("Напомнить позже", "Remind later"))
    CloseGadgetList()
  EndIf
EndProcedure

Procedure ShowReminder(*R.ReminderInfo)
  NotifyId = *R\Id
  SetGadgetText(#TxtNfText, *R\Text)
  PlaceWindowBottomRight(#WinNotify, 8)
  HideWindow(#WinNotify, #False, #PB_Window_NoActivate)
EndProcedure

Procedure CheckReminders()
  Protected r.ReminderInfo
  If IsWindowVisible_(WindowID(#WinNotify)) : ProcedureReturn : EndIf
  If Logic_PopReminder(@r) : ShowReminder(@r) : EndIf
EndProcedure

; ============================================================
;  Построение главного окна и трея
; ============================================================

Procedure BuildMainWindow()
  OpenWindow(#WinMain, 0, 0, 800, 500, Tr("Платежи и подписки", "Payments and subscriptions"), #PB_Window_SystemMenu | #PB_Window_Invisible)

  ; --- верхняя панель ---
  ButtonGadget(#BtnPrev, 10, 8, 34, 28, "<")
  TextGadget(#TxtMonth, 50, 12, 200, 26, "", #PB_Text_Center)
  SetGadgetFont(#TxtMonth, FontID(#FontTitle))
  ButtonGadget(#BtnNext, 256, 8, 34, 28, ">")
  ButtonGadget(#BtnToday, 330, 8, 100, 28, Tr("Сегодня", "Today"))
  TextGadget(#TxtListTitle, 440, 14, 350, 22, Tr("Ближайшие (по дате)", "Upcoming (by date)"))
  SetGadgetFont(#TxtListTitle, FontID(#FontBold))

  ; --- календарь и список ---
  CanvasGadget(#CvCalendar, 10, 44, #CalW, #CalH)
  ListIconGadget(#LstItems, 440, 44, 350, #CalH, Tr("Дата", "Date"), 95, #PB_ListIcon_CheckBoxes | #PB_ListIcon_FullRowSelect | #PB_ListIcon_GridLines)
  AddGadgetColumn(#LstItems, 1, Tr("Название", "Name"), 130)
  AddGadgetColumn(#LstItems, 2, Tr("Сумма", "Amount"), 100)
  CreatePopupMenu(#MenuList)
  MenuItem(#MnuListAdd, Tr("Добавить", "Add"))
  MenuItem(#MnuListEdit, Tr("Изменить", "Edit"))
  MenuItem(#MnuListDelete, Tr("Удалить", "Delete"))
  CreatePopupMenu(#MenuCalendar)
  MenuItem(#MnuCalendarAdd, Tr("Добавить", "Add"))

  ; --- нижняя панель ---
  TextGadget(#TxtInfo, 10, 382, 780, 20, "")
  TextGadget(#TxtTotals, 10, 404, 780, 20, "")
  TextGadget(#TxtSubs, 10, 426, 780, 20, "")
  ButtonGadget(#BtnAdd, 380, 460, 130, 30, Tr("+ Добавить", "+ Add"))
  ButtonGadget(#BtnEdit, 520, 460, 130, 30, Tr("Изменить", "Edit"))
  ButtonGadget(#BtnDelete, 660, 460, 130, 30, Tr("Удалить", "Delete"))
EndProcedure

 ; Иконка встроена в exe, отдельный файл при запуске не нужен.
Procedure CreateTrayImage()
  CatchImage(#ImgTray, ?AppIcon, ?AppIconEnd - ?AppIcon)
EndProcedure

DataSection
  AppIcon:
  IncludeBinary "app.ico"
  AppIconEnd:
EndDataSection

Procedure BuildTray()
  CreateTrayImage()
  AddSysTrayIcon(#Tray, WindowID(#WinMain), ImageID(#ImgTray))
  UpdateTrayTip()

  CreatePopupMenu(#MenuTray)
  MenuItem(#MnuOpen, Tr("Открыть", "Open"))
  MenuItem(#MnuAdd, Tr("Добавить платёж...", "Add payment..."))
  MenuBar()
  MenuItem(#MnuDND, Tr("Не беспокоить", "Do not disturb"))
  MenuItem(#MnuAutostart, Tr("Запускать с Windows", "Start with Windows"))
  MenuBar()
  MenuItem(#MnuLangRU, "Русский")
  MenuItem(#MnuLangEN, "English")
  MenuBar()
  MenuItem(#MnuExit, Tr("Выход", "Exit"))
  SetMenuItemState(#MenuTray, #MnuAutostart, Logic_GetAutostart())
  SetMenuItemState(#MenuTray, #MnuDND, Logic_GetDND())
  SetMenuItemState(#MenuTray, #MnuLangRU, Bool(g_Data\Language <> "en"))
  SetMenuItemState(#MenuTray, #MnuLangEN, Bool(g_Data\Language = "en"))
EndProcedure

 ; Применяем язык к уже созданным окнам и меню без перезапуска.
Procedure ApplyLanguage()
  Protected selected.i = SelectedId(), i.i
  SetWindowTitle(#WinMain, Tr("Платежи и подписки", "Payments and subscriptions"))
  SetGadgetText(#BtnToday, Tr("Сегодня", "Today"))
  SetGadgetText(#TxtListTitle, Tr("Ближайшие (по дате)", "Upcoming (by date)"))
  SetGadgetText(#BtnAdd, Tr("+ Добавить", "+ Add"))
  SetGadgetText(#BtnEdit, Tr("Изменить", "Edit"))
  SetGadgetText(#BtnDelete, Tr("Удалить", "Delete"))
  SetGadgetText(#TxtNfTitle, Tr("Скоро платёж", "Payment reminder"))
  SetGadgetText(#BtnNfPaid, Tr("Оплачено", "Paid"))
  SetGadgetText(#BtnNfLater, Tr("Напомнить позже", "Remind later"))
  If NotifyId And IsWindowVisible_(WindowID(#WinNotify))
    SetGadgetText(#TxtNfText, Logic_ReminderText(NotifyId))
  EndIf

  SetMenuItemText(#MenuTray, #MnuOpen, Tr("Открыть", "Open"))
  SetMenuItemText(#MenuTray, #MnuAdd, Tr("Добавить платёж...", "Add payment..."))
  SetMenuItemText(#MenuTray, #MnuDND, Tr("Не беспокоить", "Do not disturb"))
  SetMenuItemText(#MenuTray, #MnuAutostart, Tr("Запускать с Windows", "Start with Windows"))
  SetMenuItemText(#MenuTray, #MnuExit, Tr("Выход", "Exit"))
  SetMenuItemState(#MenuTray, #MnuLangRU, Bool(g_Data\Language <> "en"))
  SetMenuItemState(#MenuTray, #MnuLangEN, Bool(g_Data\Language = "en"))
  SetMenuItemText(#MenuList, #MnuListAdd, Tr("Добавить", "Add"))
  SetMenuItemText(#MenuList, #MnuListEdit, Tr("Изменить", "Edit"))
  SetMenuItemText(#MenuList, #MnuListDelete, Tr("Удалить", "Delete"))
  SetMenuItemText(#MenuCalendar, #MnuCalendarAdd, Tr("Добавить", "Add"))

  ; Стандартные команды позволяют пересоздать заголовки без WinAPI.
  ClearGadgetItems(#LstItems)
  RemoveGadgetColumn(#LstItems, #PB_All)
  AddGadgetColumn(#LstItems, 0, Tr("Дата", "Date"), 95)
  AddGadgetColumn(#LstItems, 1, Tr("Название", "Name"), 130)
  AddGadgetColumn(#LstItems, 2, Tr("Сумма", "Amount"), 100)
  RefreshAll()
  If selected
    For i = 0 To CountGadgetItems(#LstItems) - 1
      If GetGadgetItemData(#LstItems, i) = selected
        SetGadgetState(#LstItems, i) : Break
      EndIf
    Next
    UpdateButtons()
  EndIf
EndProcedure

Procedure ShowMainWindow()
  ViewYear = Year(Date()) : ViewMonth = Month(Date()) : SelDate = 0
  RefreshAll()
  PlaceWindowBottomRight(#WinMain, 8)
  HideWindow(#WinMain, #False)
  SetForegroundWindow_(WindowID(#WinMain))
EndProcedure

Procedure ToggleMainWindow()
  If IsWindowVisible_(WindowID(#WinMain))
    HideWindow(#WinMain, #True)
  Else
    ShowMainWindow()
  EndIf
EndProcedure

; ============================================================
;  ЗАПУСК
; ============================================================

; Мьютекс Windows предотвращает появление второго значка в трее.
; Стандартная библиотека PB не предоставляет именованный межпроцессный мьютекс.
Define instanceMutex.i = CreateMutex_(0, #False, "Local\PaymentTracker.SingleInstance")
If instanceMutex = 0 Or GetLastError_() = #ERROR_ALREADY_EXISTS
  If instanceMutex : CloseHandle_(instanceMutex) : EndIf
  End
EndIf

Define Event.i, Quit.i = #False, st.i

LoadFont(#FontNormal, "Segoe UI", 9)
LoadFont(#FontBold, "Segoe UI", 9, #PB_Font_Bold)
LoadFont(#FontTitle, "Segoe UI", 14, #PB_Font_Bold)
SetGadgetFont(#PB_Default, FontID(#FontNormal))

Logic_Load()
BuildMainWindow()
BuildNotifyWindow()
BuildTray()
AddWindowTimer(#WinMain, #TimerReminders, 3600000)
AddWindowTimer(#WinMain, #TimerSnooze, 1000)   ; отложенные напоминания созревают с точностью до секунды
RefreshAll()
CheckReminders()

Repeat
  Event = WaitWindowEvent()

  Select Event

    ; ---- трей ----
    Case #PB_Event_SysTray
      Select EventType()
        Case #PB_EventType_LeftClick
          ToggleMainWindow()
        Case #PB_EventType_RightClick
          SetForegroundWindow_(WindowID(#WinMain))
          DisplayPopupMenu(#MenuTray, WindowID(#WinMain))
      EndSelect

    ; ---- крестик = спрятать в трей ----
    Case #PB_Event_CloseWindow
      If EventWindow() = #WinMain : HideWindow(#WinMain, #True) : EndIf

    ; ---- меню трея ----
    Case #PB_Event_Menu
      Select EventMenu()
        Case #MnuOpen
          ShowMainWindow()
        Case #MnuAdd
          ShowMainWindow()
          If ShowEditDialog(0) : RefreshAll() : EndIf
        Case #MnuDND
          st = GetMenuItemState(#MenuTray, #MnuDND) ! 1
          SetMenuItemState(#MenuTray, #MnuDND, st)
          Logic_SetDND(st)
        Case #MnuAutostart
          st = GetMenuItemState(#MenuTray, #MnuAutostart) ! 1
          SetMenuItemState(#MenuTray, #MnuAutostart, st)
          Logic_SetAutostart(st)
        Case #MnuLangRU
          Logic_SetLanguage("ru") : Logic_Save() : ApplyLanguage()
        Case #MnuLangEN
          Logic_SetLanguage("en") : Logic_Save() : ApplyLanguage()
        Case #MnuExit
          Quit = #True
        Case #MnuCalendarAdd
          If CalendarPopupDate And ShowEditDialog(0, CalendarPopupDate) : RefreshAll() : EndIf
        Case #MnuListAdd
          If ShowEditDialog(0) : RefreshAll() : EndIf
        Case #MnuListEdit
          EditSelected()
        Case #MnuListDelete
          DeleteSelected()
      EndSelect

    ; ---- таймер ----
    Case #PB_Event_Timer
      If EventTimer() = #TimerReminders
        UpdateTrayTip()
        CheckReminders()
      ElseIf EventTimer() = #TimerSnooze
        CheckReminders()
      EndIf

    ; ---- гаджеты ----
    Case #PB_Event_Gadget
      Select EventGadget()

        Case #BtnPrev  : ShiftMonth(-1)
        Case #BtnNext  : ShiftMonth(1)
        Case #BtnToday
          ViewYear = Year(Date()) : ViewMonth = Month(Date()) : SelDate = 0
          RefreshAll()

        Case #CvCalendar
          Select EventType()
            Case #PB_EventType_LeftClick
              OnCalendarClick()
            Case #PB_EventType_RightClick
              CalendarPopupDate = CalendarDateAtPointer()
              If CalendarPopupDate : DisplayPopupMenu(#MenuCalendar, WindowID(#WinMain)) : EndIf
            Case #PB_EventType_MouseWheel
              If GetGadgetAttribute(#CvCalendar, #PB_Canvas_WheelDelta) > 0 : ShiftMonth(-1) : Else : ShiftMonth(1) : EndIf
          EndSelect

        Case #LstItems
          Select EventType()
            Case #PB_EventType_LeftDoubleClick
              EditSelected()
            Case #PB_EventType_RightClick
              ShowListPopup()
            Default
              SyncPaidStates()
              UpdateButtons()
          EndSelect

        Case #BtnAdd
          If ShowEditDialog(0) : RefreshAll() : EndIf

        Case #BtnEdit
          EditSelected()

        Case #BtnDelete
          DeleteSelected()

        ; ---- уведомление ----
        Case #BtnNfPaid
          Logic_SetPaid(NotifyId, #True)
          HideWindow(#WinNotify, #True)
          RefreshAll()
          CheckReminders()

        Case #BtnNfLater
          Logic_Snooze(NotifyId)
          HideWindow(#WinNotify, #True)
          CheckReminders()

      EndSelect
  EndSelect
Until Quit

Logic_Save()
RemoveSysTrayIcon(#Tray)
CloseHandle_(instanceMutex)
End
