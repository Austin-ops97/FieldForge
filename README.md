# FieldForge

Field OS for a solo plumber, HVAC tech, electrician, or handyman: client, job, quote, invoice. This repository is a clickable SwiftUI shell for iPhone (iOS 17+). Sample plumbing data lives in SwiftData on the device. Sync and card payments are stubbed. Quote and invoice share builds a one-page PDF and opens the system share sheet.

The visual pass is a quiet business dashboard: shared type, an 8/12/16/20/24 spacing scale, hairline cards, and one ink ledger on Today. Overdue invoices sit inside that card. Status labels stay fully readable. Forms keep a bottom Save bar. Quote and invoice PDFs use a white letterhead (business name, copper rule, line-item table, totals).

## Open and run

1. Install Xcode 16 or newer.
2. Open `FieldForge.xcodeproj`.
3. Select an iPhone simulator running iOS 17 or newer.
4. Run (⌘R).

The first launch asks you to set the business profile. Tap **Load Riverside Plumbing demo** to get the sample shop (Alex Rivera, Austin). If this iPhone already had that shop, FieldForge keeps it and skips setup. Delete the app to see onboarding again.

If Xcode asks for a development team, select the FieldForge target, open **Signing & Capabilities**, and choose your team. Simulator builds can use local signing.

## Click-through

This is the path to try first:

1. On a fresh install, tap **Load Riverside Plumbing demo**. Then open the **Clients** tab and tap **Maria Chen**.
2. Open the job **Kitchen faucet replacement**.
3. Open quote **Q-1042** (Draft). It already has labor, a faucet, and supply lines.
4. Tap **Accept quote**. FieldForge creates an invoice and opens it.
5. Tap **Mark Paid**. The invoice status switches to Paid.
6. Tap the share button on the quote or the invoice. FieldForge writes a PDF (client, line items, tax, total, status) and presents the share sheet.

**Today** starts with money owed from the seeded disposal invoice (**INV-220**), which is unpaid and past due. That invoice is listed inside the outstanding card. Accepting Q-1042 adds a second open invoice. Marking that new invoice paid leaves INV-220 on the money-owed list.

New job and new quote, without dead ends:

- **New Job** (Today, Jobs, or a client): pick a client or create one, then title, status, scheduled time, address, and notes. Save opens the job.
- **New Quote** (Today or a job): pick a job or create one, set a quantity, add price-book or custom lines, and watch the subtotal, tax, and total. **Save draft** keeps it a draft. **Accept quote** still creates the invoice.

Other stops:

- **Jobs**: status filters, notes, camera or library photos, voice notes, and **Create quote**.
- **Price Book**: starter prices for the shop’s trade. Tap a row to edit, or use **+** to add one.
- Empty lists explain what’s missing and offer a button to add a record or clear the filter.

## Foundation pack

- **Settings** (gear on Today): company, owner, trade, tax rate, default quote note, invoice terms, phone, and email. Quote and invoice PDFs use this profile on the letterhead. **Backup** writes one zip you can keep in Files. **Restore** replaces the shop on this iPhone after a confirm. Settings states that there is no account and the app works offline.
- **Onboarding** can start from your own trade’s price book, or load sample customers. **Reset demo data** in Settings replaces customers and jobs after a confirm, and leaves the profile in place.
- **Trade kits**: Plumbing, HVAC, Electrical, and Handyman. Replacing the price book asks first and does not delete jobs.
- **Search** (magnifying glass on Today, Clients, and Jobs) finds clients, jobs, quote numbers, and invoice numbers.
- **Week** (Today or Jobs) lists the current week by day. Empty days stay visible. Previous and next week are in the toolbar.
- **Reports** (Today) shows unpaid and overdue totals, paid this week and month, and jobs marked done. Export invoices or clients as CSV from Reports or from Settings → Money reports.
- Job photos and voice notes are real files on the iPhone. The camera, photo library, and microphone usage strings are in the generated Info.plist. If access is off, the job screen says so and can open Settings.

New quotes use the tax rate and default note from Settings. The Riverside sample quotes stay at 8.25%, so **INV-220** remains **$534.76**.

## Sample shop

| | |
|---|---|
| Clients | Maria Chen, James Whitaker, Priya Nair |
| Jobs | Kitchen faucet (today, in progress), water heater flush (today), main line drain (tomorrow, lead), garbage disposal (done) |
| Price book | 8 labor and material items |
| Quotes | Q-1042 draft, Q-1038 accepted |
| Invoices | INV-220, sent and overdue |

Tax on seeded quotes is 8.25%.

## Project layout

- `FieldForge/Models` — SwiftData models, business profile, trade kits, totals, demo data
- `FieldForge/Views` — Today, Clients, Jobs, Quotes, Invoices, Price Book, Settings, Search, Week, Reports
- `FieldForge/Theme` — ink, accent, type styles, spacing, and card chrome

Tabs are **Today**, **Clients**, **Jobs**, and **Price Book**. Quotes and invoices open from a job or from money owed.

## Offline

FieldForge does not sign in, sync, or call a server. Customers, jobs, quotes, invoices, photos, and voice notes stay on the iPhone. Airplane mode is a normal way to use it. Sharing a PDF, CSV, or backup is something you start, through the system share sheet.

Backup and restore, on a simulator:

1. Open **Today** and tap the gear.
2. Tap **Backup**. The share sheet opens a `FieldForge-Backup-YYYY-MM-DD.zip`. Save it to Files.
3. Change something small, such as a client note, so you can see the restore land.
4. Tap **Restore**, choose that zip, and confirm **Replace with backup**.
5. The business name, Maria Chen, Q-1042, and INV-220 are back. A damaged or unrelated file shows an error and leaves the current shop in place.

## Out of scope

GPS, SMS, QuickBooks, Stripe, Apple Watch, Mac, AI estimates, accounts, and any network service. There is no paywall in the app.
