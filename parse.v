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

	doc := toml.parse_text(data.bytestr())!
	root := doc.to_any()
	messages := parse_toml_messages(root, true)!
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

fn parse_toml_messages(raw toml.Any, is_initial_call bool) ![]Message {
	is_map_message := is_toml_message(raw)!
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
				messages << parse_child_toml_messages(id, value)!
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

fn parse_child_toml_messages(id string, raw toml.Any) ![]Message {
	is_child_message := is_toml_message(raw)!
	child_messages := parse_toml_messages(raw, false)!
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

fn is_toml_message(raw toml.Any) !bool {
	match raw {
		string, toml.Null {
			return true
		}
		map[string]toml.Any {
			mut reserved_keys := []string{}
			mut unreserved_keys := []string{}
			for key, _ in raw {
				if is_reserved_toml_message_key(key) {
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

fn is_reserved_toml_message_key(key string) bool {
	return is_reserved_message_key(key)
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
