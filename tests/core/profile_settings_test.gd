extends GdUnitTestSuite
## ProfileSettings: the options popup's settings in the profile.


## The options settings (display, volumes, text size) default when missing, round-trip
## through JSON (where numbers come back as floats) and tolerate wrong types.
func test_the_options_settings_round_trip_and_tolerate_wrong_types() -> void:
	var fresh := ProfileState.new()
	assert_str(ProfileSettings.display(fresh)).is_equal(ProfileState.DISPLAY_WINDOWED)
	assert_int(ProfileSettings.music_volume(fresh)).is_equal(ProfileState.VOLUME_DEFAULT)
	assert_int(ProfileSettings.sound_volume(fresh)).is_equal(ProfileState.VOLUME_DEFAULT)
	assert_int(ProfileSettings.text_size(fresh)).is_equal(0)
	ProfileSettings.set_display(fresh, ProfileState.DISPLAY_FULLSCREEN)
	ProfileSettings.set_music_volume(fresh, 3)
	ProfileSettings.set_sound_volume(fresh, 42)
	ProfileSettings.set_text_size(fresh, 2)
	var text: String = JSON.stringify(fresh.to_dictionary())
	var read: ProfileState = ProfileState.from_dictionary(JSON.parse_string(text))
	assert_str(ProfileSettings.display(read)).is_equal(ProfileState.DISPLAY_FULLSCREEN)
	assert_int(ProfileSettings.music_volume(read)).is_equal(3)
	assert_int(ProfileSettings.sound_volume(read)).is_equal(ProfileState.VOLUME_MAX)
	assert_int(ProfileSettings.text_size(read)).is_equal(2)
	var odd: ProfileState = ProfileState.from_dictionary(
		{
			"format_version": 5.0,
			"settings":
			{"display": 1.0, "music_volume": "loud", "sound_volume": -4.0, "text_size": "huge"}
		}
	)
	assert_str(ProfileSettings.display(odd)).is_equal(ProfileState.DISPLAY_WINDOWED)
	assert_int(ProfileSettings.music_volume(odd)).is_equal(ProfileState.VOLUME_DEFAULT)
	assert_int(ProfileSettings.sound_volume(odd)).is_equal(0)
	assert_int(ProfileSettings.text_size(odd)).is_equal(0)
