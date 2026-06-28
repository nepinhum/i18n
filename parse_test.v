module i18n

fn test_parse_simple_toml_message() {
	message_file := parse_message_file_bytes('hello = "world"'.bytes(), 'active.en.toml') or {
		panic(err)
	}

	assert message_file.path == 'active.en.toml'
	assert message_file.tag.str() == 'en'
	assert message_file.format == 'toml'
	assert message_file.messages.len == 1
	assert message_file.messages[0].id == 'hello'
	assert message_file.messages[0].other == 'world'
}

fn test_parse_message_table_with_detail_fields() {
	toml_text := '[detail]\n' + 'description = "detail description"\n' +
		'other = "detail translation"\n'
	messages := sorted_messages(parse_message_file_bytes(toml_text.bytes(), 'active.en.toml') or {
		panic(err)
	}.messages)

	assert messages.len == 1
	assert messages[0].id == 'detail'
	assert messages[0].description == 'detail description'
	assert messages[0].other == 'detail translation'
}

fn test_parse_nested_table_uses_dotted_id() {
	toml_text := '[outer.nested]\n' + 'inner = "value"\n'
	messages := sorted_messages(parse_message_file_bytes(toml_text.bytes(), 'active.en.toml') or {
		panic(err)
	}.messages)

	assert messages.len == 1
	assert messages[0].id == 'outer.nested.inner'
	assert messages[0].other == 'value'
}

fn test_parse_message_table_rejects_mixed_reserved_and_unreserved_keys() {
	toml_text := '[detail]\n' + 'description = "detail description"\n' + 'unexpected = "value"\n'

	parse_message_file_bytes(toml_text.bytes(), 'active.en.toml') or {
		assert err.msg().contains('reserved keys')
		assert err.msg().contains('description')
		assert err.msg().contains('unexpected')
		return
	}

	assert false
}

fn test_parse_message_table_rejects_non_string_plural_field() {
	toml_text := '[item]\n' + 'one = { text = "bad" }\n'

	parse_message_file_bytes(toml_text.bytes(), 'active.en.toml') or {
		assert err.msg().contains('expected value for key "one" be a string')
		return
	}

	assert false
}

fn test_parse_message_table_rejects_non_string_metadata_field() {
	toml_text := '[detail]\n' + 'description = { text = "bad" }\n'

	parse_message_file_bytes(toml_text.bytes(), 'active.en.toml') or {
		assert err.msg().contains('expected value for key "description" be a string')
		return
	}

	assert false
}

fn test_parse_translation_string_maps_to_other() {
	toml_text := '[simple]\n' + 'translation = "simple translation"\n'
	messages := sorted_messages(parse_message_file_bytes(toml_text.bytes(), 'active.en.toml') or {
		panic(err)
	}.messages)

	assert messages.len == 1
	assert messages[0].id == 'simple'
	assert messages[0].other == 'simple translation'
}

fn test_parse_translation_table_maps_plural_fields() {
	toml_text := '[item]\n' + 'translation = { one = "one item", other = "many items" }\n'
	messages := sorted_messages(parse_message_file_bytes(toml_text.bytes(), 'active.en.toml') or {
		panic(err)
	}.messages)

	assert messages.len == 1
	assert messages[0].id == 'item'
	assert messages[0].one == 'one item'
	assert messages[0].other == 'many items'
}

fn test_parse_empty_toml_returns_no_messages() {
	message_file := parse_message_file_bytes([]u8{}, 'locales/pt-BR.toml') or { panic(err) }

	assert message_file.path == 'locales/pt-BR.toml'
	assert message_file.tag.str() == 'pt-BR'
	assert message_file.format == 'toml'
	assert message_file.messages.len == 0
}

fn test_parse_unsupported_format_returns_error() {
	parse_message_file_bytes('{"hello":"world"}'.bytes(), 'active.en.json') or {
		assert err.msg().contains('unsupported message file format')
		assert err.msg().contains('json')
		return
	}

	assert false
}

fn sorted_messages(messages []Message) []Message {
	mut sorted := messages.clone()
	for i := 0; i < sorted.len; i++ {
		for j := i + 1; j < sorted.len; j++ {
			if sorted[j].id < sorted[i].id {
				current := sorted[i]
				sorted[i] = sorted[j]
				sorted[j] = current
			}
		}
	}
	return sorted
}
