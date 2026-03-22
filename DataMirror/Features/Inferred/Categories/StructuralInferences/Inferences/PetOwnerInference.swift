import Foundation

/// Infers pet ownership from contact names matching common pet names.
enum PetOwnerInference: InferenceComputable {
    static let inferenceType: InferenceType = .petOwner
    static let requiredPermissions: [PermissionType] = [.contacts, .photosReadWrite]

    private static let commonPetNames: Set<String> = [
        "max", "bella", "charlie", "buddy", "daisy", "lucy", "rocky", "molly",
        "bailey", "maggie", "sadie", "chloe", "sophie", "duke", "bear",
        "tucker", "jack", "coco", "harley", "penny", "princess", "riley",
        "ginger", "murphy", "zeus", "oscar", "bentley", "milo", "buster",
        "peanut", "leo", "bandit", "lola", "shadow", "simba", "nala",
        "moose", "ollie", "rosie", "ruby", "luna", "olive", "stella",
        "scout", "henry", "winston", "sammy", "jasper", "toby", "dixie",
        "finn", "pepper", "lucky", "roxy", "teddy", "willow", "ace",
        "cookie", "missy", "abby", "rex", "sasha", "lily", "blue",
        "diesel", "gracie", "layla", "frankie", "dexter", "oreo", "piper",
        "maverick", "gus", "otis", "brutus", "koda", "oakley", "ellie",
        "loki", "thor", "jax", "copper", "athena", "nova", "apollo",
        "gunner", "beau", "tank", "ziggy", "marley", "boomer", "chewy",
        "banjo", "rusty", "sparky", "ranger", "cash", "izzy", "sugar",
        "mittens", "patches", "smokey", "tiger", "whiskers", "garfield",
        "felix", "fluffy", "kitty", "misty", "callie", "cleo", "mimi",
        "snowball", "angel", "boots", "biscuit", "butterscotch", "caramel",
        "mocha", "dusty", "fudge", "hazel", "ivy", "jasmine", "maple",
        "peaches", "socks", "tinkerbell", "trixie", "violet", "waffles",
        "bubbles", "clover", "ember", "honey", "juniper",
        "kiki", "lulu", "mango", "noodle", "pickles", "rascal", "snickers",
        "taco", "vader", "wrigley", "yoshi", "zoe", "archie",
        "basil", "birdie", "bowie", "bruce", "casper", "chance", "chester",
        "cloud", "cosmo", "dottie", "eddie", "freddie", "goose", "hank",
        "indie", "kirby", "louie", "mochi", "nugget", "odin", "prince",
        "quincy", "romeo", "sage", "storm", "titus", "walnut",
        "winnie", "xena", "yogi", "zelda",
    ]

    static func compute(from context: InferenceContext) async -> Inference {
        let now = Date()
        var evidenceItems: [Evidence] = []
        var petSignals = 0

        if let contacts = context.contacts {
            let petNameContacts = contacts.filter { contact in
                !contact.givenName.isEmpty && contact.familyName.isEmpty && contact.organizationName.isEmpty && commonPetNames.contains(contact.givenName.lowercased())
            }
            if !petNameContacts.isEmpty {
                petSignals += petNameContacts.count
                let names = petNameContacts.prefix(3).map(\.givenName).joined(separator: ", ")
                evidenceItems.append(Evidence(id: UUID(), permissionType: .contacts, description: String(localized: "\(petNameContacts.count) contact(s) with common pet names"), rawValue: names, weight: 0.5))
            }
        }

        let value: InferenceValue = petSignals > 0 ? .text(String(localized: "Possible pet owner")) : .unknown

        return Inference(
            id: UUID(), category: .social, type: .petOwner,
            label: String(localized: "Pet Owner (Estimated)"), value: value,
            confidence: .low, confidenceReason: petSignals > 0 ? String(localized: "Contact names matching common pet names found — speculative") : String(localized: "No pet ownership signals detected"),
            evidence: evidenceItems,
            methodology: String(localized: "Checks contacts for entries with only a first name matching the top 200 most common pet names."),
            databrokerNote: String(localized: "Pet owner segments are among the most valuable in CPG advertising. Pet owners spend ~$1,400/year on pets on average."),
            permissionsRequired: [.contacts, .photosReadWrite], isRealTime: false, lastUpdated: now
        )
    }
}
