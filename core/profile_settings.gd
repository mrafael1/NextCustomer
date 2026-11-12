class_name ProfileSettings
extends RefCounted
## The options popup's settings in ProfileState.settings (mock-up options_pause.html): DISPLAY,
## MUSIC, SOUND and TEXT SIZE. Each accessor tolerates a missing or wrong-typed value (an older
## profile's, or a hand-edited one), so the profile's format version stays.


## The display setting: DISPLAY_FULLSCREEN when set so, else DISPLAY_WINDOWED.
static func display(profile: ProfileState) -> String:
	var value: Variant = profile.settings.get(ProfileState.DISPLAY_KEY)
	return (
		ProfileState.DISPLAY_FULLSCREEN
		if value is String and value == ProfileState.DISPLAY_FULLSCREEN
		else ProfileState.DISPLAY_WINDOWED
	)


static func set_display(profile: ProfileState, mode: String) -> void:
	profile.settings[ProfileState.DISPLAY_KEY] = (
		ProfileState.DISPLAY_FULLSCREEN
		if mode == ProfileState.DISPLAY_FULLSCREEN
		else ProfileState.DISPLAY_WINDOWED
	)


## The music volume, 0 to VOLUME_MAX (VOLUME_DEFAULT for a missing or wrong-typed value).
static func music_volume(profile: ProfileState) -> int:
	return _volume(profile, ProfileState.MUSIC_VOLUME_KEY)


static func set_music_volume(profile: ProfileState, volume: int) -> void:
	profile.settings[ProfileState.MUSIC_VOLUME_KEY] = clampi(volume, 0, ProfileState.VOLUME_MAX)


## The sound effects volume, 0 to VOLUME_MAX (VOLUME_DEFAULT for a missing or wrong value).
static func sound_volume(profile: ProfileState) -> int:
	return _volume(profile, ProfileState.SOUND_VOLUME_KEY)


static func set_sound_volume(profile: ProfileState, volume: int) -> void:
	profile.settings[ProfileState.SOUND_VOLUME_KEY] = clampi(volume, 0, ProfileState.VOLUME_MAX)


## The text size setting's index in TEXT_SIZES (0 for a missing or unknown value).
static func text_size(profile: ProfileState) -> int:
	var value: Variant = profile.settings.get(ProfileState.TEXT_SIZE_KEY)
	if value is String:
		return maxi(ProfileState.TEXT_SIZES.find(value as String), 0)
	return 0


static func set_text_size(profile: ProfileState, index: int) -> void:
	profile.settings[ProfileState.TEXT_SIZE_KEY] = ProfileState.TEXT_SIZES[clampi(
		index, 0, ProfileState.TEXT_SIZES.size() - 1
	)]


## A volume setting; JSON gives numbers back as floats, so whole floats count too.
static func _volume(profile: ProfileState, key: String) -> int:
	var value: Variant = profile.settings.get(key)
	if value is int or value is float:
		return clampi(roundi(float(value)), 0, ProfileState.VOLUME_MAX)
	return ProfileState.VOLUME_DEFAULT
