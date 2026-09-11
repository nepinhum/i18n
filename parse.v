module i18n

import toml

pub struct MessageFile {
pub:
	path     string
	tag      LanguageTag
	format   string
	messages []Message
}

pub fn parse_message_file_bytes(data []u8, path string) !MessageFile {
	lang, format := parse_path(path)!
	tag := parse_language_tag(lang)!
	mut message_file := MessageFile{
		path:   path
		tag:    tag
		format: format
	}

	if format != 'toml' {
		return error('unsupported message file format "${format}"')
	}
	if data.len == 0 {
		return message_file
	}

	source := data.bytestr()
	doc := toml.parse_text(source)!
	root := doc.to_any()
	explicit_table_paths := explicit_toml_table_paths(source)
	messages := parse_toml_messages(root, true, explicit_table_paths, []string{})!
	return MessageFile{
		...message_file
		messages: messages
	}
}

fn parse_path(path string) !(string, string) {
	mut base := path
	for i := path.len - 1; i >= 0; i-- {
		if path[i] == `/` || path[i] == `\\` {
			base = path[i + 1..]
			break
		}
	}

	format_dot := base.last_index('.') or { return error('message file path has no format') }
	format := base[format_dot + 1..].clone()
	if format == '' {
		return error('message file path has empty format')
	}

	name := base[..format_dot].clone()
	lang_dot := name.last_index('.') or { -1 }
	lang := if lang_dot == -1 { name } else { name[lang_dot + 1..].clone() }
	if lang == '' {
		return error('message file path has empty language tag')
	}

	return lang, format
}

fn parse_toml_messages(raw toml.Any, is_initial_call bool, explicit_table_paths []string, path []string) ![]Message {
	is_map_message := is_toml_message(raw, explicit_table_paths, path)!
	match raw {
		string {
			if is_initial_call {
				return error('invalid translation file, expected key-values, got a single value')
			}
			return [new_message_from_toml(raw)!]
		}
		map[string]toml.Any {
			if is_map_message {
				return [new_message_from_toml(raw)!]
			}
			mut messages := []Message{}
			for id, value in raw {
				messages << parse_child_toml_messages(id, value, explicit_table_paths, path)!
			}
			return messages
		}
		toml.Null {
			if is_initial_call {
				return error('invalid translation file, expected key-values, got a single value')
			}
			return [Message{}]
		}
		else {
			return error('unsupported file format ${typeof(raw).name}')
		}
	}
}

fn parse_child_toml_messages(id string, raw toml.Any, explicit_table_paths []string, parent_path []string) ![]Message {
	mut child_path := parent_path.clone()
	child_path << id
	is_child_message := is_toml_message(raw, explicit_table_paths, child_path)!
	child_messages := parse_toml_messages(raw, false, explicit_table_paths, child_path)!
	mut messages := []Message{}
	for child in child_messages {
		mut message := child
		if is_child_message {
			if message.id == '' {
				message = message_with_id(message, id)
			}
		} else {
			message = message_with_id(message, id + '.' + message.id)
		}
		messages << message
	}
	return messages
}

fn is_toml_message(raw toml.Any, explicit_table_paths []string, path []string) !bool {
	match raw {
		string, toml.Null {
			return true
		}
		map[string]toml.Any {
			mut reserved_keys := []string{}
			mut unreserved_keys := []string{}
			for key, value in raw {
				mut child_path := path.clone()
				child_path << key
				if is_reserved_toml_message_key(key, value, explicit_table_paths, child_path) {
					reserved_keys << key
				} else {
					unreserved_keys << key
				}
			}
			if reserved_keys.len > 0 && unreserved_keys.len > 0 {
				return error('reserved keys ${sorted_strings(reserved_keys)} mixed with unreserved keys ${sorted_strings(unreserved_keys)}')
			}
			return reserved_keys.len > 0
		}
		else {
			return false
		}
	}
}

fn is_reserved_toml_message_key(key string, value toml.Any, explicit_table_paths []string, path []string) bool {
	normalized_key := normalize_message_key(key)
	if normalized_key == 'translation' {
		if value is map[string]toml.Any && path_key(path) in explicit_table_paths {
			return false
		}
		return true
	}
	if !is_reserved_message_key(normalized_key) {
		return false
	}
	return value is string
}

fn explicit_toml_table_paths(source string) []string {
	mut paths := []string{}
	for line in source.split_into_lines() {
		trimmed := line.trim_space()
		if !trimmed.starts_with('[') || trimmed.starts_with('[[') {
			continue
		}
		end := trimmed.index(']') or { continue }
		table_key := trimmed[1..end].trim_space()
		parts := toml.parse_dotted_key(table_key) or { continue }
		paths << path_key(parts)
	}
	return paths
}

fn path_key(parts []string) string {
	return parts.join('.')
}

fn new_message_from_toml(raw toml.Any) !Message {
	match raw {
		string {
			return Message{
				other: raw
			}
		}
		map[string]toml.Any {
			mut message := Message{}
			apply_toml_message_fields(mut message, raw)!
			return message
		}
		toml.Null {
			return Message{}
		}
		else {
			return error('unsupported message value ${typeof(raw).name}')
		}
	}
}

fn apply_toml_message_fields(mut message Message, fields map[string]toml.Any) ! {
	for key, value in fields {
		normalized_key := normalize_message_key(key)
		if normalized_key == 'translation' {
			match value {
				string {
					message = message_with_field(message, 'other', value)
				}
				map[string]toml.Any {
					apply_toml_message_fields(mut message, value)!
				}
				else {
					return error('expected value for key "${key}" be a string or table')
				}
			}

			continue
		}

		match value {
			string {
				message = message_with_field(message, normalized_key, value)
			}
			else {
				return error('expected value for key "${key}" be a string')
			}
		}
	}
}

fn message_with_field(message Message, key string, value string) Message {
	return match key {
		'id' {
			Message{
				...message
				id: value
			}
		}
		'description' {
			Message{
				...message
				description: value
			}
		}
		'hash' {
			Message{
				...message
				hash: value
			}
		}
		'left_delim' {
			Message{
				...message
				left_delim: value
			}
		}
		'right_delim' {
			Message{
				...message
				right_delim: value
			}
		}
		'zero' {
			Message{
				...message
				zero: value
			}
		}
		'one' {
			Message{
				...message
				one: value
			}
		}
		'two' {
			Message{
				...message
				two: value
			}
		}
		'few' {
			Message{
				...message
				few: value
			}
		}
		'many' {
			Message{
				...message
				many: value
			}
		}
		'other' {
			Message{
				...message
				other: value
			}
		}
		else {
			message
		}
	}
}

fn message_with_id(message Message, id string) Message {
	return Message{
		...message
		id: id
	}
}

fn sorted_strings(values []string) []string {
	mut sorted := values.clone()
	for i := 0; i < sorted.len; i++ {
		for j := i + 1; j < sorted.len; j++ {
			if sorted[j] < sorted[i] {
				current := sorted[i]
				sorted[i] = sorted[j]
				sorted[j] = current
			}
		}
	}
	return sorted
}
