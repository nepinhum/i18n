module i18n

fn test_language_tag_canonicalizes_display_and_key() {
	tag := parse_language_tag('EN-us') or { panic(err) }

	assert tag.str() == 'en-US'
	assert tag.key() == 'en-us'
}

fn test_language_tag_parent_chain() {
	tag := parse_language_tag('art-x-klingon') or { panic(err) }
	parent := tag.parent() or { panic(err) }
	grandparent := parent.parent() or { panic(err) }

	assert parent.str() == 'art-x'
	assert grandparent.str() == 'art'
}

fn test_language_preferences_sort_by_quality() {
	preferences := parse_language_preferences(['fr-CA, fr;q=0.8, en;q=0.9']) or { panic(err) }

	assert preferences.len == 3
	assert preferences[0].str() == 'fr-CA'
	assert preferences[1].str() == 'en'
	assert preferences[2].str() == 'fr'
}

fn test_language_preferences_ignore_invalid_entries() {
	preferences := parse_language_preferences(['fr, @@@, en;q=0.9']) or { panic(err) }

	assert preferences.len == 2
	assert preferences[0].str() == 'fr'
	assert preferences[1].str() == 'en'
}

fn test_match_language_uses_exact_parent_registered_child_then_default() {
	default_tag := parse_language_tag('en') or { panic(err) }
	available := [
		parse_language_tag('en-US') or { panic(err) },
		parse_language_tag('fr') or { panic(err) },
		parse_language_tag('fr-CA') or { panic(err) },
	]

	exact := match_language([parse_language_tag('fr-CA') or { panic(err) }], available, default_tag) or {
		panic(err)
	}
	parent := match_language([parse_language_tag('fr-FR') or { panic(err) }], available,
		default_tag) or { panic(err) }
	child := match_language([parse_language_tag('en-GB') or { panic(err) }], available, default_tag) or {
		panic(err)
	}
	fallback := match_language([parse_language_tag('es') or { panic(err) }], available, default_tag) or {
		panic(err)
	}

	assert exact.str() == 'fr-CA'
	assert parent.str() == 'fr'
	assert child.str() == 'en-US'
	assert fallback.str() == 'en'
}

fn test_empty_language_tags_return_error() {
	parse_language_tag('') or { return }

	assert false
}

fn test_language_tags_with_direct_whitespace_return_error() {
	parse_language_tag(' en ') or {
		parse_language_tag('en - US') or { return }
		assert false
	}

	assert false
}

fn test_language_preferences_skip_zero_quality_entries() {
	preferences := parse_language_preferences(['fr;q=0, en;q=0.8']) or { panic(err) }

	assert preferences.len == 1
	assert preferences[0].str() == 'en'
}

fn test_zero_quality_language_is_not_matched_when_available() {
	requested := parse_language_preferences(['fr;q=0']) or { panic(err) }
	available := [parse_language_tag('fr') or { panic(err) }]
	default_tag := parse_language_tag('en') or { panic(err) }

	matched := match_language(requested, available, default_tag) or { panic(err) }

	assert matched.str() == 'en'
}
