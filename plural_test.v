module i18n

fn test_english_integer_one_is_one() {
	tag := parse_language_tag('en') or { panic(err) }
	count := plural_count_int(1)

	form := plural_form_for_language(tag, count) or { panic(err) }

	assert form == .one
}

fn test_english_negative_integer_one_is_one() {
	tag := parse_language_tag('en') or { panic(err) }
	count := plural_count_int(-1)

	form := plural_form_for_language(tag, count) or { panic(err) }

	assert form == .one
}

fn test_english_integer_two_is_other() {
	tag := parse_language_tag('en') or { panic(err) }
	count := plural_count_int(2)

	form := plural_form_for_language(tag, count) or { panic(err) }

	assert form == .other
}

fn test_english_decimal_one_point_zero_is_other() {
	tag := parse_language_tag('en') or { panic(err) }
	count := plural_count_string('1.0') or { panic(err) }

	form := plural_form_for_language(tag, count) or { panic(err) }

	assert form == .other
}

fn test_english_negative_string_one_is_one() {
	tag := parse_language_tag('en') or { panic(err) }
	count := plural_count_string('-1') or { panic(err) }

	form := plural_form_for_language(tag, count) or { panic(err) }

	assert form == .one
}

fn test_turkish_always_uses_other() {
	tag := parse_language_tag('tr') or { panic(err) }

	assert plural_form_for_language(tag, plural_count_int(1)) or { panic(err) } == .other
	assert plural_form_for_language(tag, plural_count_int(2)) or { panic(err) } == .other
	assert plural_form_for_language(tag, plural_count_string('1.0') or { panic(err) }) or {
		panic(err)
	} == .other
}

fn test_artificial_klingon_follows_english() {
	tag := parse_language_tag('art-x-klingon') or { panic(err) }

	assert plural_form_for_language(tag, plural_count_int(1)) or { panic(err) } == .one
	assert plural_form_for_language(tag, plural_count_int(2)) or { panic(err) } == .other
	assert plural_form_for_language(tag, plural_count_string('1.0') or { panic(err) }) or {
		panic(err)
	} == .other
}

fn test_invalid_decimal_strings_return_error() {
	plural_count_string('1.2.3') or { return }

	assert false
}

fn test_i64_boundary_values_parse_successfully() {
	max := plural_count_string('9223372036854775807') or { panic(err) }
	min := plural_count_string('-9223372036854775808') or { panic(err) }

	assert max.i == i64(9223372036854775807)
	assert min.i == i64(-9223372036854775808)
}

fn test_i64_positive_overflow_returns_error() {
	plural_count_string('9223372036854775808') or { return }

	assert false
}

fn test_i64_negative_overflow_returns_error() {
	plural_count_string('-9223372036854775809') or { return }

	assert false
}
