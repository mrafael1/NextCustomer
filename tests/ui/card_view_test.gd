extends GdUnitTestSuite
## The plain CardView, which the deck view and the deck-full chooser keep until #56 (#75,
## decision 4A: the counter and the offers show items). Moved here from the retired
## ArtCardView's suite.

const CARDS := "res://data/cards"


## A plain CardView keeps its number badge: BADGE_Y above the card, tomato when denied.
func test_the_plain_card_keeps_its_badge() -> void:
	var view: CardView = auto_free(CardView.new(CardInstance.new(load("%s/milk.tres" % CARDS), 1)))
	add_child(view)
	assert_float(view.badge_rest_y()).is_equal(CardView.BADGE_Y)
	view.show_fizzle_badge(0)
	assert_str(view.badge.text).is_equal("0")
	assert_object(view.badge.get_theme_color("font_color")).is_equal(Palette.TOMATO)
	view.show_badge(2, true)
	assert_object(view.badge.get_theme_color("font_color")).is_equal(Palette.MUSTARD)
