class_name TipSpec
extends RefCounted
## What one hover tip shows (the hover tips revamp, design B "paper card", mock-up
## docs/art/mockups/hover_tips.html, approved 2026-11-13): its kind (the header band's colour), its
## icon, its title (chunky capitals), a small tag (what it is: FAMILY, PERK · LV 1, or the item it
## is on), one rule line, an optional muted fine-print line, an optional live line (what is true
## now, with a dot: OK teal, BAD a tomato cross, OFF grey, INFO teal), the actions its footer keys
## name (CLICK <action>, RIGHT-CLICK HANDBOOK) and at most MAX_SUBS keyword or word boxes beside it
## (TipWords). The body, fine print and live line are TipMarkup text: numbers and keywords are
## coloured and boxed by TipText. TipCard draws a spec; TipTarget.tip_spec() makes one.
##
## from_text() reads a plain tip ("Dairy · Milk is a Dairy item", or lines split by "\n"): its first
## part is the title when it is short, the rest the rule.

enum Kind { WORD, KEYWORD, FAMILY, PERK, STATUS, PIN, COUPON, PRICE, ITEM, BROKEN }
enum Live { INFO, OK, BAD, OFF }

## The most keyword or word boxes a tip shows beside it.
const MAX_SUBS := 2
## A first part longer than this is not a title: the whole text is the rule.
const TITLE_MAX := 28
const PART_SEPARATOR := " · "
const NOT_WORKING := "%s NOT WORKING"
## The tags of the kinds that have one of their own.
const KEYWORD_TAG := "KEYWORD"
const FAMILY_TAG := "FAMILY"
const WORD_TAG := "WORD"

var kind: Kind = Kind.WORD
var icon: Texture2D
var title: String = ""
var tag: String = ""
## The rule, the fine print and the live line (TipMarkup text; "" for none).
var body: String = ""
var cond: String = ""
var live: String = ""
var live_kind: Live = Live.INFO
## The click's action on the footer ("TIME CARD"; "" for none) and whether a right-click opens
## the handbook (GlyphTips sets it from its guide_for).
var click: String = ""
var guide: bool = false
## The boxes beside it: TipWords keys (keywords "BATCH", words "ROW"), at most MAX_SUBS shown.
var subs: PackedStringArray = PackedStringArray()
## A family tip's band and title colours (its FamilyStyle face and ink); clear: the kind's.
var band: Color = Color(0, 0, 0, 0)
var band_ink: Color = Color(0, 0, 0, 0)
## The plain text it was made from (TipTarget.full_tip), for checks.
var source: String = ""


## A spec of `kind` with `title` and `body`.
static func make(spec_kind: Kind, spec_title: String, spec_body: String) -> TipSpec:
	var spec: TipSpec = TipSpec.new()
	spec.kind = spec_kind
	spec.title = spec_title
	spec.body = spec_body
	spec.source = spec_title + (PART_SEPARATOR + spec_body if not spec_body.is_empty() else "")
	return spec


## A copy (its own subs), to change without touching this one.
func copy() -> TipSpec:
	var made: TipSpec = TipSpec.new()
	for field: String in [
		"kind",
		"icon",
		"title",
		"tag",
		"body",
		"cond",
		"live",
		"live_kind",
		"click",
		"guide",
		"band",
		"band_ink",
		"source"
	]:
		made.set(field, get(field))
	made.subs = subs.duplicate()
	return made


## A plain tip's spec: split at its first "\n" (else its first " · "), the first part is the title
## when it is at most TITLE_MAX long, the rest the rule (its own " · " parts as sentences); else the
## whole text is the rule. Its words are marked up (TipMarkup.auto).
static func from_text(text: String) -> TipSpec:
	var spec: TipSpec = TipSpec.new()
	spec.source = text
	var head: String = text
	var rest: String = ""
	var cut: int = text.find("\n")
	if cut < 0:
		cut = text.find(PART_SEPARATOR)
		if cut >= 0:
			rest = text.substr(cut + PART_SEPARATOR.length())
	else:
		rest = text.substr(cut + 1)
	if cut >= 0:
		head = text.substr(0, cut)
	if cut >= 0 and head.length() <= TITLE_MAX and not rest.strip_edges().is_empty():
		spec.title = head.strip_edges()
		spec.body = sentences(rest)
	elif head.length() <= TITLE_MAX and rest.is_empty() and not head.contains(" "):
		spec.title = head.strip_edges()
	else:
		spec.body = sentences(text)
	return spec


## `text`'s " · " and "\n" parts as sentences: each capitalised, ending in a full stop unless it
## ends in punctuation already.
static func sentences(text: String) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for line: String in text.replace("\n", PART_SEPARATOR).split(PART_SEPARATOR, false):
		var part: String = line.strip_edges()
		if part.is_empty():
			continue
		part = part.left(1).to_upper() + part.substr(1)
		if not ".!?:…)".contains(part.right(1)):
			part += "."
		parts.append(part)
	return " ".join(parts)


## The boxes to show: `subs`, else the keywords and words the body names (TipMarkup.subs_of),
## without the one the tip is about, at most MAX_SUBS.
func shown_subs() -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var named: PackedStringArray = (
		subs if not subs.is_empty() else TipMarkup.subs_of(body + " " + cond)
	)
	for key: String in named:
		if found.size() >= MAX_SUBS:
			break
		if found.has(key) or not TipWords.has(key):
			continue
		# A tip about a keyword is its box, unless it says it is not working.
		if kind != Kind.BROKEN and is_about(key):
			continue
		found.append(key)
	return found


## Whether the tip is about `key`: its title is the keyword or word, or (a keyword's tip, "BATCH
## NOT WORKING") starts with it. A perk named after a word (COUPON ENGINE) is not about it.
func is_about(key: String) -> bool:
	var upper: String = title.to_upper()
	var name_of: String = TipWords.title_of(key)
	if upper == name_of or upper == key:
		return true
	return kind in [Kind.KEYWORD, Kind.BROKEN] and upper.begins_with(name_of + " ")


## Its plain words (title, tag, rule, fine print, live line, footer), for checks.
func plain() -> String:
	var parts: PackedStringArray = PackedStringArray()
	for part: String in [title, tag, body, cond, live]:
		if not part.is_empty():
			parts.append(TipMarkup.plain(part))
	return "\n".join(parts)
