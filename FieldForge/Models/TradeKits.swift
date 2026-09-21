import Foundation

struct StarterVisit {
    var clientName: String
    var phone: String
    var address: String
    var clientNotes: String
    var title: String
    var status: JobStatus
    var dayOffset: Int
    var hour: Int
    var notes: String
}

enum TradeKits {
    static func makeItems(for trade: TradeKit) -> [PriceBookItem] {
        definitions(for: trade).map { item in
            PriceBookItem(
                name: item.name,
                detail: item.detail,
                category: item.category.rawValue,
                unit: item.unit,
                unitPrice: item.price,
                taxable: item.taxable
            )
        }
    }

    static func starterJobs(for trade: TradeKit) -> [StarterVisit] {
        switch trade {
        case .plumbing:
            return []
        case .hvac:
            return [
                StarterVisit(
                    clientName: "Elena Brooks",
                    phone: "(512) 555-0164",
                    address: "220 Riverside Drive, Austin, TX 78741",
                    clientNotes: "Condenser is on the south side of the house.",
                    title: "No cool — condenser check",
                    status: .inProgress,
                    dayOffset: 0,
                    hour: 9,
                    notes: "Indoor temp 81. Outdoor unit hums but the fan is slow."
                ),
                StarterVisit(
                    clientName: "Elena Brooks",
                    phone: "(512) 555-0164",
                    address: "220 Riverside Drive, Austin, TX 78741",
                    clientNotes: "Condenser is on the south side of the house.",
                    title: "Filter and coil service",
                    status: .scheduled,
                    dayOffset: 1,
                    hour: 13,
                    notes: "Replace the 20x25 filter and rinse the condenser coil."
                )
            ]
        case .electrical:
            return [
                StarterVisit(
                    clientName: "Noah Patel",
                    phone: "(512) 555-0133",
                    address: "14 Lantern Street, Austin, TX 78703",
                    clientNotes: "Panel is in the garage. Dog stays in the office.",
                    title: "Kitchen outlet swap",
                    status: .scheduled,
                    dayOffset: 0,
                    hour: 10,
                    notes: "Two countertop outlets need GFCI protection."
                ),
                StarterVisit(
                    clientName: "Noah Patel",
                    phone: "(512) 555-0133",
                    address: "14 Lantern Street, Austin, TX 78703",
                    clientNotes: "Panel is in the garage. Dog stays in the office.",
                    title: "Bedroom ceiling fan",
                    status: .lead,
                    dayOffset: 2,
                    hour: 15,
                    notes: "Existing box may need a fan brace."
                )
            ]
        case .handyman:
            return [
                StarterVisit(
                    clientName: "Chris Alvarez",
                    phone: "(512) 555-0188",
                    address: "901 Barton Springs Road, Austin, TX 78704",
                    clientNotes: "Third-floor walkup. Text on arrival.",
                    title: "Living room TV mount",
                    status: .inProgress,
                    dayOffset: 0,
                    hour: 11,
                    notes: "65-inch on a stud wall. Hide the cables if the path is open."
                ),
                StarterVisit(
                    clientName: "Chris Alvarez",
                    phone: "(512) 555-0188",
                    address: "901 Barton Springs Road, Austin, TX 78704",
                    clientNotes: "Third-floor walkup. Text on arrival.",
                    title: "Hall drywall patch",
                    status: .done,
                    dayOffset: -6,
                    hour: 9,
                    notes: "Small hole from a door stop. Ready for paint."
                )
            ]
        }
    }

    private struct Definition {
        var name: String
        var detail: String
        var category: PriceCategory
        var unit: String
        var price: Decimal
        var taxable: Bool
    }

    private static func definitions(for trade: TradeKit) -> [Definition] {
        switch trade {
        case .plumbing:
            return [
                def("Service call", "Trip charge and diagnostic.", .labor, "trip", 95, true),
                def("Faucet install labor", "Remove the old faucet and set the new one.", .labor, "each", 175, true),
                def("Moen pull-down kitchen faucet", "Brushed nickel, with spray hose.", .materials, "each", 168, true),
                def("Braided supply lines", "Pair of stainless braided lines.", .materials, "set", 28, true),
                def("Water heater flush", "Drain, flush sediment, check the anode.", .labor, "each", 149, true),
                def("Main drain snake", "Cable the main cleanout.", .labor, "each", 245, true),
                def("Disposal install labor", "Swap the unit and test for leaks.", .labor, "each", 210, true),
                def("1/2 HP garbage disposal", "In-stock unit from the truck.", .materials, "each", 189, true)
            ]
        case .hvac:
            return [
                def("Service call", "Trip charge and system check.", .labor, "trip", 95, true),
                def("Diagnostic", "Electrical and airflow diagnosis.", .labor, "each", 129, true),
                def("Capacitor replacement labor", "Test and swap the run capacitor.", .labor, "each", 165, true),
                def("Filter change", "Standard 1-inch or 4-inch filter.", .labor, "each", 45, true),
                def("Condenser coil clean", "Rinse the outdoor coil and check the fan.", .labor, "each", 189, true),
                def("Thermostat install labor", "Set a new thermostat and test heat and cool.", .labor, "each", 140, true),
                def("Smart thermostat", "Common wall thermostat, customer choice of finish.", .materials, "each", 189, true),
                def("Filter, 20x25", "Pleated filter from the truck.", .materials, "each", 22, true)
            ]
        case .electrical:
            return [
                def("Service call", "Trip charge and a look at the circuit.", .labor, "trip", 95, true),
                def("Outlet install labor", "Replace a device and test the circuit.", .labor, "each", 85, true),
                def("GFCI outlet", "Tamper-resistant GFCI.", .materials, "each", 28, true),
                def("Ceiling fan install labor", "Hang the fan and set the controls.", .labor, "each", 175, true),
                def("Panel inspection", "Visual inspection and a written note.", .labor, "each", 149, true),
                def("Dimmer switch", "LED-rated dimmer.", .materials, "each", 32, true),
                def("Recessed light", "Canless LED retrofit.", .materials, "each", 45, true),
                def("Dedicated circuit labor", "New home-run for a single appliance.", .labor, "each", 320, true)
            ]
        case .handyman:
            return [
                def("Service call", "Trip charge for a short punch list.", .labor, "trip", 75, true),
                def("Hourly labor", "On-site work billed by the hour.", .labor, "hour", 85, true),
                def("Furniture assembly", "Flat-pack furniture, hardware included.", .labor, "each", 65, true),
                def("Drywall patch", "Small hole, tape, and texture.", .labor, "each", 120, true),
                def("Door adjustment", "Hinges, latch, or a dragging slab.", .labor, "each", 70, true),
                def("Caulk and seal", "Tub, window, or exterior gap.", .labor, "each", 60, true),
                def("Blind install", "Inside or outside mount, one window.", .labor, "each", 40, true),
                def("TV mount", "Stud-mounted bracket, up to 70 inches.", .labor, "each", 110, true)
            ]
        }
    }

    private static func def(
        _ name: String,
        _ detail: String,
        _ category: PriceCategory,
        _ unit: String,
        _ price: Decimal,
        _ taxable: Bool
    ) -> Definition {
        Definition(name: name, detail: detail, category: category, unit: unit, price: price, taxable: taxable)
    }
}
