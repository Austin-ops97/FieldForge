# FieldForge

Field OS for a solo plumber, HVAC tech, electrician, or handyman: client, job, quote, invoice. This repository is a clickable SwiftUI shell for iPhone (iOS 17+). Sample plumbing data lives in SwiftData on the device. Sync, PDF export, and card payments are stubbed.

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

**Today** starts with money owed from the seeded disposal invoice (**INV-220**), which is unpaid and past due. Accepting Q-1042 adds a second open invoice. Marking that new invoice paid leaves INV-220 on the money-owed list.

Other stops, all of which lead somewhere:

- **Today**: today’s jobs, **New Job**, **New Quote**, and **Sync now** (a stub that clears the on-device “waiting to sync” marks).
- **Jobs**: status filters, notes, photo placeholders, a voice-note stub, and **Create quote**.
- **Price Book**: eight plumbing prices. Tap a row to edit, or use **+** to add one.
- Share on a quote or invoice sends a text summary. PDF export is not in this shell.

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
- `FieldForge/Theme` — copper and navy colors

Tabs are **Today**, **Clients**, **Jobs**, and **Price Book**. Quotes and invoices open from a job or from money owed.

## Out of scope

GPS, SMS, QuickBooks, Stripe, Apple Watch, Mac, AI estimates, real sign-in, CloudKit, and StoreKit. The offline mindset is in the model (`needsSync` plus a sync stub), not a server.
