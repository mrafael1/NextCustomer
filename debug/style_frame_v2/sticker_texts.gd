class_name StickerTexts
extends Resource
## The price stickers' short summaries for style frame v2 (issue #75): one digit-free template
## per card id. Every number comes from the card's data when it is formatted: `{base}` is the
## card's base value, `{name}` its display name, and every other `{key}` an exported field of
## its first rule (e.g. `{bonus}`, `{factor}`, `{tag}`). Templates use the rule texts' own words
## ("after", "beside", "next", "later", "earlier"). They stay in debug/ until the sticker is
## adopted, so nothing in the exported data/ references a debug script.

@export var templates: Dictionary[StringName, String] = {}


## The card's sticker summary, or "" when it has no template.
func summary(definition: CardDefinition) -> String:
	if not templates.has(definition.id):
		return ""
	return templates[definition.id].format(values(definition))


## Whether the card has a template.
func has_template(definition: CardDefinition) -> bool:
	return templates.has(definition.id)


## The values a template can name: base, name and the first rule's script exports.
static func values(definition: CardDefinition) -> Dictionary:
	var found: Dictionary = {}
	if not definition.rules.is_empty():
		var rule: Rule = definition.rules[0]
		for property: Dictionary in rule.get_property_list():
			if int(property["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:
				var key: String = property["name"]
				found[key] = rule.get(key)
	found["base"] = definition.base
	found["name"] = definition.display_name
	return found
