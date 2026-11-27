# Payments and Subscriptions — User Guide

[Руководство на русском](USER_GUIDE_RU.md)

## 1. What the app does

Payments and Subscriptions keeps a calendar of recurring payments and income, shows a monthly plan, and reminds you about payments. It runs on Windows and lives in the notification area near the clock, referred to below as the **system tray**.

The app does not connect to your bank, transfer money, or check whether a payment has actually cleared. You maintain entries and paid marks yourself. The displayed “balance” is a calculation from events entered for the selected month, not your bank account balance.

## 2. Starting the app and the tray menu

1. Run `PaymentTracker.exe`. Its icon appears in the system tray. If you cannot see it, check the hidden icons behind the arrow near the clock.
2. Left-click the icon to show or hide the main window. Closing the main window with its X only hides it in the tray.
3. Right-click the icon for the menu:
   - **Open** — show the main window.
   - **Add payment…** — create an entry.
   - **Do not disturb** — turn reminders off or on.
   - **Start with Windows** — enable or disable startup when the current Windows user signs in.
   - **Русский / English** — switch the interface language without restarting.
   - **Exit** — quit the app completely.

The language and Do not disturb setting are saved in the data file. Names and notes you entered yourself are not translated. The Windows color picker uses the Windows language. Before copying or replacing data, use **Exit** in the tray menu to close the app completely.

## 3. Main window

The left side contains the selected month's calendar; the right side lists upcoming entries. Use the arrow buttons to change months and **Today** to return to the current month. You can also use the mouse wheel over the calendar.

Calendar dots identify event types: red for an expense, green for income, and blue for a payment from savings. A “+” appears when there are more than three events. Paid events remain on the calendar. The color chosen in the editor is stored with the entry, but calendar dot colors currently follow the event type.

Left-click a day to filter the list to events on that day. Click the same day again to clear the filter and return to upcoming events. You can also select days from adjacent months shown in the grid.

Right-click a calendar day and choose **Add** to create an entry whose first date is that day. Right-click the list for **Add**, **Edit**, and **Delete**. Adding is available on empty space; select a row to edit or delete it. Double-click a row to edit it. The buttons at the bottom provide the same actions, and deletion requires confirmation.

## 4. Entry types

### Expense

An **Expense** is an amount you count as reducing your planned balance: a subscription, a utility bill, or, if that matches your workflow, a transfer to a savings account. Expenses contribute to the month's expense total. Recurring expenses also contribute to the normalized monthly and yearly figures labeled “Subscriptions.”

Example: you put 1,000 RUB into savings on the 1st and another 1,000 RUB on the 15th. Create two monthly **Expense** entries, each for 1,000 RUB with its respective first date. In a month containing both events, expenses increase by 2,000 RUB and the calculated balance decreases by that amount.

### Income

**Income** is a planned incoming amount such as salary or an advance. It increases the month's income total and calculated balance. The reminder field is unavailable for income, and income cannot be marked paid.

Example: a salary of 60,000 RUB on the 25th and an advance of 30,000 RUB on the 10th are two separate monthly **Income** entries.

### From savings

**From savings** represents a future payment using money you already counted as an expense when setting it aside. The entry appears in the calendar and list, can recur, can produce reminders, and can be marked paid. In the list it is labeled “saved”.

Its amount is **excluded** from income, expenses, balance, and “Subscriptions.” The app does not track the savings-account balance or link specific deposits to specific subscriptions.

Example: you record two transfers of 1,000 RUB per month as expenses and pay 12,000 RUB once a year for a service from savings. Create the annual payment as **From savings**, amount 12,000 RUB, repeat “Yearly.” Its date and reminder remain visible, while the calculated balance is not reduced a second time by 12,000 RUB. This fits a workflow where the money set aside was already counted as an expense.

If the same month has a 60,000 RUB salary, a 30,000 RUB advance, and two 1,000 RUB transfers, with no other entries, the totals are: income **90,000**, expense **2,000**, balance **88,000 RUB**. A 12,000 RUB “From savings” event in that month does not change those totals.

## 5. Creating and editing an entry

Click **Add**, use the list's context menu, or right-click a calendar date. Fill in:

- **Type:** Expense, Income, or From savings.
- **Name:** a required label that identifies the entry.
- **Amount:** a positive number. A decimal point or comma is accepted.
- **Currency:** `RUB` by default; choose or enter another code. The app does not perform currency conversion.
- **Repeat:** monthly, yearly, weekly, every N days, or once.
- **Interval, days:** used only for “Every N days”; for example, 10 means every ten days.
- **First payment:** the first event date and the reference point for recurrence. When adding from the calendar, this starts as the clicked date; you can change it.
- **Remind (days):** how many days before an expense or savings payment reminders can begin. `0` means remind on the event date, not disable reminders. The field is disabled for income.
- **Color:** stored with the entry; calendar dot colors currently follow entry type.
- **Note:** optional text for yourself.
- **Paused:** temporarily excludes the entry from the calendar, list, totals, and reminders without deleting it. To restore it, clear the flag when editing.

Click **OK** to save or **Cancel** to close without saving. Because paused entries are hidden from the list and the current interface has no separate paused-entry view, consider this limitation before enabling the flag.

### How recurrence works

- **Monthly:** uses the original day of the month. For example, January 31 → February 28 in a non-leap year → March 31 → April 30.
- **Yearly:** uses the original month and day. February 29 becomes February 28 in a non-leap year.
- **Weekly:** every seven days from the first date.
- **Every N days:** repeats at the specified interval; for example January 1, 11, and 21 for a ten-day interval beginning January 1.
- **Once:** one event on the specified date.

No occurrences are created before the first date. Changing an entry's type, recurrence, interval, or first date clears its current paid mark and postponed reminder.

## 6. Paid marks and overdue events

The checkbox applies to the **nearest occurrence** of an expense or savings payment, not to the entry forever. Check it after paying to suppress the reminder for that occurrence. Uncheck it if you marked it by mistake; the reminder can then appear again.

After a paid date passes, the next occurrence of a recurring entry becomes the nearest one; the paid mark is not carried over. When the list is filtered to a day, only an entry's nearest occurrence can be checked or unchecked. Paid marks do not apply to income.

An unpaid recurring expense or savings payment remains in the upcoming list as overdue until paid or for seven days after its due date. The app then moves to its next occurrence. An unpaid one-time payment stays in the list until paid; once paid and its date has passed, it leaves the upcoming list. Income moves to its next occurrence after its date without becoming overdue.

## 7. Reminders

For an expense or savings payment, set **Remind (days)**. For example, a payment due on the 20th with a value of `3` can start reminding on the 17th. A value of `0` means the due date itself; an unpaid overdue event can also produce reminders.

A notification shows the name, timing, amount, and currency. Its buttons are:

- **Paid** — mark the nearest occurrence as paid.
- **Remind later** — postpone another reminder for two hours. The app must be running to display it; if it was closed, eligible reminders are checked at the next launch.

Normally the same reminder appears at most once per day. Snoozing permits another reminder after two hours on the same day. Paid and paused entries do not generate reminders, and **Do not disturb** suppresses notifications. There is currently no per-expense “never remind” setting.

## 8. Totals, subscriptions, and currencies

The bottom of the window shows totals **for the month selected in the calendar**:

- **Income:** all occurrences of active income entries in that month.
- **Expense:** all occurrences of active expense entries in that month.
- **Balance:** income minus expense.
- **Subscriptions per month / per year:** recurring expenses normalized to monthly and yearly amounts.

Monthly totals include both paid and unpaid occurrences: this is a plan by date, not a bank statement. Filtering the list to one day does not change the monthly totals. “From savings” events are excluded from these amounts.

“Subscriptions” includes active recurring expenses in the base currency, including entries used for regular transfers to savings. It is a normalized estimate based on recurrence settings, not an actual balance or a total of paid subscriptions only. One-time expenses are excluded. A yearly expense is divided by 12; a weekly expense is multiplied by 52 / 12; an every-N-days expense is multiplied by 30.4375 / N. The yearly estimate is the monthly estimate multiplied by 12.

The default base currency is `RUB`. Entries in other currencies remain visible in the calendar and list but are excluded from the RUB totals and are not converted. Do not add amounts in different currencies together without your own conversion.

## 9. Where data is stored

Data for the current Windows user is stored in:

```text
%APPDATA%\PaymentTracker
```

Paste that path into the File Explorer address bar and press Enter. The main file is **data.json**. It contains entries, paid marks and reminder state, base currency, language, and Do not disturb. If the file is absent, the app starts with an empty database.

When saving, the previous version is kept as **data.bak**. This is one previous version, not a history of every change: later saves update it. If the app detects syntactically damaged JSON, it attempts to rename it to `data.corrupt-DATE.json` and starts with an empty database. If data suddenly appears missing, do not delete those files; first copy the entire data folder.

**Start with Windows** is stored separately in the current Windows user's startup settings and points to the executable path. After moving to another computer or moving the exe, check it and enable it again if needed.

## 10. Backing up

1. Choose **Exit** in the tray menu and make sure the app has closed. This prevents a running instance from overwriting data while you copy or restore it.
2. Open `%APPDATA%\PaymentTracker` in File Explorer.
3. Copy `data.json` to a separate folder, external drive, or other backup location. You may instead copy the entire `PaymentTracker` folder, including `data.bak` and any other files.
4. Name the backup folder with its date, for example `PaymentTracker-backup-2026-11-27`. Keep several dated copies and check that the files were actually copied.
5. Restart the app normally.

The database contains your financial names, amounts, and notes. Choose backup storage and access permissions with the people who can read those files in mind.

## 11. Restoring a backup

Restoring replaces the current data. If you might need the current data later, save a separate copy first.

1. Exit the app through **Exit** in the tray menu.
2. Open `%APPDATA%\PaymentTracker` and copy the current folder to a safe location.
3. Copy the backed-up `data.json` into that folder and confirm file replacement in File Explorer. Create the folder if it does not yet exist.
4. Run `PaymentTracker.exe` and check your entries, language, and settings.

To restore the previous version from `data.bak`, first copy the whole current folder elsewhere. With the app closed, make a **copy** of `data.bak` named `data.json` in `%APPDATA%\PaymentTracker`, replacing the main file. Do not rename the only available backup without keeping a separate copy.

## 12. Moving to another computer

1. On the old computer, quit through **Exit** and make a separate copy of `%APPDATA%\PaymentTracker` as described above.
2. Transfer `PaymentTracker.exe` and the backup folder to the new computer using a suitable secure method.
3. On the new computer, exit any running copy of the app. If that computer already has data, back it up separately first: the next step replaces the database.
4. Open `%APPDATA%` in File Explorer for the new user. Create the `PaymentTracker` folder if necessary, and put the copied `data.json` in it. You may also copy `data.bak`.
5. Run the exe and check your entries and settings. If desired, enable **Start with Windows** again in the tray menu: that setting and the exe path are not carried inside `data.json`.

A database backup does not contain the app itself. Each Windows user has a separate `%APPDATA%`, so place the data in the profile of the user who will run the app.

## 13. Troubleshooting

- **No window:** check the tray and hidden icons; left-click the app icon.
- **An entry is missing from the list:** check the selected calendar day, first date, and paused flag. Clicking the selected day again clears the filter. There is currently no separate paused-entry view.
- **No reminder:** check that the app is running, the entry is not paused, its nearest occurrence is unpaid, the reminder window has begun, and Do not disturb is off. Income does not generate reminders.
- **An amount is missing from totals:** “From savings” events are excluded; the entry's currency must match the base currency; check the month and recurrence.
- **The database appears empty:** exit through the tray and first copy the whole data folder. Check the Windows user profile and look for `data.bak` or `data.corrupt-DATE.json`. Restore only after making a separate copy of the current files.
