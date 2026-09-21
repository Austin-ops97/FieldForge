# FieldForge

Field OS for a solo plumber, HVAC tech, electrician, or handyman: client, job, quote, invoice. This repository is a clickable SwiftUI shell for iPhone (iOS 17+). Sample plumbing data lives in SwiftData on the device. Sync and card payments are stubbed. Quote and invoice share builds a one-page PDF and opens the system share sheet.

The visual pass is a quiet business dashboard: shared type, an 8/12/16/20/24 spacing scale, hairline cards, and one ink ledger on Today. Overdue invoices sit inside that card. Status labels stay fully readable. Forms keep a bottom Save bar. Quote and invoice PDFs use a white letterhead (business name, copper rule, line-item table, totals).

## Open and run

1. Install Xcode 16 or newer.
2. Open `FieldForge.xcodeproj`.
3. Select an iPhone simulator running iOS 17 or newer.
4. Run (⌘R).

The first launch seeds **Riverside Plumbing** (Alex Rivera, a solo plumber in Austin). After that, the shop stays in the simulator’s SwiftData store. Delete the app from the simulator to load the sample shop again.

If Xcode asks for a development team, select the FieldForge target, open **Signing & Capabilities**, and choose your team. Simulator builds can use local signing.

## Click-through

This is the path to try first:

1. Open the **Clients** tab and tap **Maria Chen**.
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

- **Jobs**: status filters, notes, photo placeholders, a voice-note stub, and **Create quote**.
- **Price Book**: eight plumbing prices. Tap a row to edit, or use **+** to add one.
- Empty lists explain what’s missing and offer a button to add a record or clear the filter.
- **Sync now** on Today only clears the on-device “waiting to sync” marks.

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

- `FieldForge/Models` — SwiftData models, totals, seed data, quote actions
- `FieldForge/Views` — Today, Clients, Jobs, Quotes, Invoices, Price Book
- `FieldForge/Theme` — ink, accent, type styles, spacing, and card chrome

Tabs are **Today**, **Clients**, **Jobs**, and **Price Book**. Quotes and invoices open from a job or from money owed.

## Out of scope

GPS, SMS, QuickBooks, Stripe, Apple Watch, Mac, AI estimates, real sign-in, CloudKit, and StoreKit. The offline mindset is in the model (`needsSync` plus a sync stub), not a server.
