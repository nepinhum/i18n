module i18n

pub struct LanguageTag {
	parts []string
}

struct LanguagePreference {
	tag   LanguageTag
	q     int
	index int
}

fn parse_language_tag(input string) !LanguageTag {
	if input == '' {
		return error('language tag cannot be empty')
	}
	if input != input.trim_space() {
		return error('language tag cannot contain leading or trailing whitespace')
	}

	raw_parts := input.split('-')
	mut parts := []string{}
	for raw_part in raw_parts {
		if raw_part == '' {
			return error('language tag contains an empty subtag')
		}
		if raw_part != raw_part.trim_space() {
			return error('language tag subtag cannot contain whitespace')
		}
		part := raw_part
		if !is_language_subtag(part) {
			return error('language tag contains an invalid subtag')
		}
		parts << part.to_lower()
	}

	return LanguageTag{
		parts: parts
	}
}

pub fn (tag LanguageTag) str() string {
	mut display_parts := []string{}
	for i, part in tag.parts {
		display_parts << canonical_language_subtag(part, i)
	}
	return display_parts.join('-')
}

fn (tag LanguageTag) key() string {
	return tag.parts.join('-')
}

fn (tag LanguageTag) base_key() string {
	if tag.parts.len == 0 {
		return ''
	}
	return tag.parts[0]
}

fn (tag LanguageTag) parent() !LanguageTag {
	if tag.parts.len <= 1 {
		return error('language tag has no parent')
	}
	return LanguageTag{
		parts: tag.parts[..tag.parts.len - 1].clone()
	}
}

fn parse_language_preferences(inputs []string) ![]LanguageTag {
	mut preferences := []LanguagePreference{}
	mut index := 0
	for input in inputs {
		for raw_entry in input.split(',') {
			entry := raw_entry.trim_space()
			if entry == '' {
				continue
			}
			tag, q := parse_language_preference(entry) or { continue }
			if q == 0 {
				continue
			}
			preferences << LanguagePreference{
				tag:   tag
				q:     q
				index: index
			}
			index++
		}
	}

	for i := 0; i < preferences.len; i++ {
		for j := i + 1; j < preferences.len; j++ {
			if preferences[j].q > preferences[i].q
				|| (preferences[j].q == preferences[i].q
				&& preferences[j].index < preferences[i].index) {
				current := preferences[i]
				preferences[i] = preferences[j]
				preferences[j] = current
			}
		}
	}

	mut tags := []LanguageTag{}
	for preference in preferences {
		tags << preference.tag
	}
	return tags
}

fn parse_language_preference(entry string) !(LanguageTag, int) {
	parts := entry.split(';')
	tag := parse_language_tag(parts[0])!
	mut q := 1000
	for raw_param in parts[1..] {
		param := raw_param.trim_space()
		if param.starts_with('q=') {
			q = parse_quality(param[2..])!
		}
	}
	return tag, q
}

fn match_language(requested []LanguageTag, available []LanguageTag, default_tag LanguageTag) !LanguageTag {
	mut available_by_key := map[string]LanguageTag{}
	for tag in available {
		available_by_key[tag.key()] = tag
	}

	for tag in requested {
		if matched := available_by_key[tag.key()] {
			return matched
		}

		mut parent := tag
		for {
			parent = parent.parent() or { break }
			if matched := available_by_key[parent.key()] {
				return matched
			}
		}

		for candidate in available {
			if candidate.base_key() == tag.base_key() {
				return candidate
			}
		}
	}

	return default_tag
}

fn canonical_language_subtag(part string, index int) string {
	if index > 0 && part.len == 2 {
		return part.to_upper()
	}
	return part.to_lower()
}

fn is_language_subtag(part string) bool {
	for ch in part {
		if !((ch >= `a` && ch <= `z`) || (ch >= `A` && ch <= `Z`) || (ch >= `0` && ch <= `9`)) {
			return false
		}
	}
	return true
}

fn parse_quality(input string) !int {
	value := input.trim_space()
	if value == '1' {
		return 1000
	}
	if value == '0' {
		return 0
	}
	if value.starts_with('1.') {
		for digit in value[2..] {
			if digit != `0` {
				return error('language quality must be between 0 and 1')
			}
		}
		return 1000
	}
	if !value.starts_with('0.') {
		return error('language quality must be between 0 and 1')
	}

	mut q := 0
	mut scale := 100
	for digit in value[2..] {
		if digit < `0` || digit > `9` {
			return error('language quality contains an invalid digit')
		}
		if scale > 0 {
			q += int(digit - `0`) * scale
			scale /= 10
		}
	}
	return q
}
