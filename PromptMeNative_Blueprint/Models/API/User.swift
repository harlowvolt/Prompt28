import Foundation

enum PlanType: String, Codable, CaseIterable {
	case starter
	case pro
	case unlimited
	case dev
}

struct User: Decodable, Identifiable, Equatable {
	let id: String
	let email: String
	let name: String
	let provider: String
	let plan: PlanType
	let prompts_used: Int
	let prompts_remaining: Int?
	let period_end: String
	
	// MARK: - Regular Init
	
	init(
		id: String,
		email: String,
		name: String,
		provider: String,
		plan: PlanType,
		prompts_used: Int,
		prompts_remaining: Int?,
		period_end: String
	) {
		self.id = id
		self.email = email
		self.name = name
		self.provider = provider
		self.plan = plan
		self.prompts_used = prompts_used
		self.prompts_remaining = prompts_remaining
		self.period_end = period_end
	}

	private enum CodingKeys: String, CodingKey {
		case id
		case email
		case name
		case provider
		case plan
		case prompts_used
		case prompts_remaining
		case period_end
		case promptsUsed
		case promptsRemaining
		case periodEnd
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)

		if let idString = try? container.decode(String.self, forKey: .id) {
			id = idString
		} else if let idInt = try? container.decode(Int.self, forKey: .id) {
			id = String(idInt)
		} else {
			id = UUID().uuidString
		}

		email = (try? container.decode(String.self, forKey: .email)) ?? ""
		name = (try? container.decode(String.self, forKey: .name)) ?? ""
		provider = (try? container.decode(String.self, forKey: .provider)) ?? "email"

		if let planValue = try? container.decode(PlanType.self, forKey: .plan) {
			plan = planValue
		} else if let rawPlan = try? container.decode(String.self, forKey: .plan),
				  let mapped = PlanType(rawValue: rawPlan.lowercased()) {
			plan = mapped
		} else {
			plan = .starter
		}

		prompts_used =
			(try? container.decode(Int.self, forKey: .prompts_used)) ??
			(try? container.decode(Int.self, forKey: .promptsUsed)) ?? 0

		prompts_remaining =
			(try? container.decodeIfPresent(Int.self, forKey: .prompts_remaining)) ??
			(try? container.decodeIfPresent(Int.self, forKey: .promptsRemaining))

		period_end =
			(try? container.decode(String.self, forKey: .period_end)) ??
			(try? container.decode(String.self, forKey: .periodEnd)) ?? ""
	}
}
