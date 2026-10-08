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
	validate_language_tag_parts(parts)!

	return LanguageTag{
		parts: parts
	}
}

pub fn (tag LanguageTag) str() string {
	mut display_parts := []string{}
	script_index, region_index := display_subtag_indexes(tag.parts)
	for i, part in tag.parts {
		display_parts << canonical_language_subtag(part, i, script_index, region_index)
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
	private_index := tag.parts.index('x')
	if private_index != -1 {
		if private_index == 0 {
			return error('language tag has no parent')
		}
		return LanguageTag{
			parts: tag.parts[..private_index].clone()
		}
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

fn display_subtag_indexes(parts []string) (int, int) {
	mut index := 1
	mut script_index := -1
	mut region_index := -1
	if index < parts.len && is_script_subtag(parts[index]) {
		script_index = index
		index++
	}
	if index < parts.len && is_region_subtag(parts[index]) {
		region_index = index
	}
	return script_index, region_index
}

fn canonical_language_subtag(part string, index int, script_index int, region_index int) string {
	if index == script_index {
		return part[0..1].to_upper() + part[1..].to_lower()
	}
	if index == region_index && part.len == 2 {
		return part.to_upper()
	}
	return part.to_lower()
}

fn validate_language_tag_parts(parts []string) ! {
	if parts.len == 0 {
		return error('language tag cannot be empty')
	}
	if !is_language_subtag_alpha(parts[0]) || parts[0].len < 2 || parts[0].len > 8 {
		return error('language tag has an invalid language subtag')
	}

	mut index := 1
	if index < parts.len && is_script_subtag(parts[index]) {
		index++
	}
	if index < parts.len && is_region_subtag(parts[index]) {
		index++
	}

	for index < parts.len {
		part := parts[index]
		if part == 'x' {
			validate_private_language_subtags(parts[index + 1..])!
			return
		}
		if is_extension_singleton(part) {
			index = validate_extension_subtags(parts, index + 1)!
			continue
		}
		if !is_variant_subtag(part) {
			return error('language tag has an invalid subtag')
		}
		index++
	}
}

fn validate_private_language_subtags(parts []string) ! {
	if parts.len == 0 {
		return error('language tag private use section cannot be empty')
	}
	for part in parts {
		if part.len < 1 || part.len > 8 || !is_language_subtag(part) {
			return error('language tag has an invalid private use subtag')
		}
	}
}

fn validate_extension_subtags(parts []string, start int) !int {
	if start >= parts.len {
		return error('language tag extension cannot be empty')
	}
	mut index := start
	mut subtag_count := 0
	for index < parts.len {
		part := parts[index]
		if part == 'x' || is_extension_singleton(part) {
			break
		}
		if part.len < 2 || part.len > 8 || !is_language_subtag(part) {
			return error('language tag has an invalid extension subtag')
		}
		subtag_count++
		index++
	}
	if subtag_count == 0 {
		return error('language tag extension cannot be empty')
	}
	return index
}

fn is_script_subtag(part string) bool {
	return part.len == 4 && is_language_subtag_alpha(part)
}

fn is_region_subtag(part string) bool {
	return (part.len == 2 && is_language_subtag_alpha(part)) || (part.len == 3
		&& is_digit_subtag(part))
}

fn is_variant_subtag(part string) bool {
	if part.len >= 5 && part.len <= 8 {
		return is_language_subtag(part)
	}
	return part.len == 4 && part[0] >= `0` && part[0] <= `9` && is_language_subtag(part)
}

fn is_extension_singleton(part string) bool {
	if part.len != 1 || part == 'x' {
		return false
	}
	return is_language_subtag(part)
}

fn is_language_subtag(part string) bool {
	for ch in part {
		if !(ch >= `a` && ch <= `z`) && !(ch >= `A` && ch <= `Z`) && !(ch >= `0` && ch <= `9`) {
			return false
		}
	}
	return true
}

fn is_language_subtag_alpha(part string) bool {
	for ch in part {
		if !(ch >= `a` && ch <= `z`) && !(ch >= `A` && ch <= `Z`) {
			return false
		}
	}
	return part.len > 0
}

fn is_digit_subtag(part string) bool {
	for ch in part {
		if ch < `0` || ch > `9` {
			return false
		}
	}
	return part.len > 0
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
