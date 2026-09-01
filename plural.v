module i18n

pub enum PluralForm {
	invalid
	zero
	one
	two
	few
	many
	other
}

pub struct PluralCount {
	raw          string
	i            i64
	has_fraction bool
}

pub fn plural_count_int(value i64) PluralCount {
	return PluralCount{
		raw: value.str()
		i:   abs_i64(value)
	}
}

pub fn plural_count_string(value string) !PluralCount {
	if value == '' {
		return error('plural count cannot be empty')
	}

	mut dot_seen := false
	mut has_fraction := false
	mut whole_digits := []u8{}
	for index, ch in value {
		if ch == `-` {
			if index != 0 {
				return error('plural count contains an invalid sign')
			}
			whole_digits << u8(ch)
			continue
		}
		if ch == `.` {
			if dot_seen {
				return error('plural count contains multiple decimal points')
			}
			if index == 0 || (index == 1 && value[0] == `-`) {
				return error('plural count must include digits before the decimal point')
			}
			dot_seen = true
			has_fraction = true
			continue
		}
		if ch < `0` || ch > `9` {
			return error('plural count contains an invalid digit')
		}
		if !dot_seen {
			whole_digits << u8(ch)
		}
	}

	if whole_digits.len == 0 || (whole_digits.len == 1 && whole_digits[0] == `-`) {
		return error('plural count must include digits')
	}
	if dot_seen && value.ends_with('.') {
		return error('plural count must include digits after the decimal point')
	}

	return PluralCount{
		raw:          value
		i:            parse_whole_i64(whole_digits)!
		has_fraction: has_fraction
	}
}

pub fn (count PluralCount) str() string {
	return count.raw
}

pub fn plural_form_for_language(tag LanguageTag, count PluralCount) !PluralForm {
	match tag.base_key() {
		'en', 'art' {
			return english_plural_form(count)
		}
		'tr' {
			return .other
		}
		else {
			return .other
		}
	}
}

fn english_plural_form(count PluralCount) PluralForm {
	if count.i == 1 && !count.has_fraction {
		return .one
	}
	return .other
}

fn abs_i64(value i64) i64 {
	if value < 0 {
		return -value
	}
	return value
}

fn parse_whole_i64(whole_digits []u8) !i64 {
	negative := whole_digits[0] == `-`
	digit_start := if negative { 1 } else { 0 }
	mut meaningful_start := digit_start
	for meaningful_start < whole_digits.len && whole_digits[meaningful_start] == `0` {
		meaningful_start++
	}
	if meaningful_start == whole_digits.len {
		return 0
	}

	limit := if negative { '9223372036854775808' } else { '9223372036854775807' }
	meaningful_len := whole_digits.len - meaningful_start
	if meaningful_len > limit.len {
		return error('plural count whole number is outside i64 range')
	}
	if meaningful_len == limit.len {
		for i := 0; i < meaningful_len; i++ {
			digit := whole_digits[meaningful_start + i]
			limit_digit := limit[i]
			if digit > limit_digit {
				return error('plural count whole number is outside i64 range')
			}
			if digit < limit_digit {
				break
			}
		}
	}

	mut parsed := i64(0)
	for i := digit_start; i < whole_digits.len; i++ {
		digit := i64(whole_digits[i] - `0`)
		parsed = parsed * 10 + digit
	}
	return parsed
}
