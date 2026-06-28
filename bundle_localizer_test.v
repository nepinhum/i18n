module i18n

import os
import rand

fn test_new_bundle_registers_default_language() {
	bundle := new_bundle('en') or { panic(err) }

	assert bundle.default_language().str() == 'en'
	assert bundle.language_tags().len == 1
	assert bundle.language_tags()[0].str() == 'en'
}

fn test_add_messages_stores_messages() {
	mut bundle := new_bundle('en') or { panic(err) }
	bundle.add_messages('en', [
		Message{
			id:    'hello'
			other: 'Hello'
		},
	]) or { panic(err) }

	template := bundle.template_for(parse_language_tag('en') or { panic(err) }, 'hello') or {
		panic(err)
	}
	rendered := template.render(.other, {}) or { panic(err) }

	assert rendered == 'Hello'
}

fn test_later_add_messages_replaces_same_language_and_id() {
	mut bundle := new_bundle('en') or { panic(err) }
	bundle.add_messages('en', [
		Message{
			id:    'hello'
			other: 'Hello'
		},
	]) or { panic(err) }
	bundle.add_messages('en', [
		Message{
			id:    'hello'
			other: 'Hi'
		},
	]) or { panic(err) }

	template := bundle.template_for(parse_language_tag('en') or { panic(err) }, 'hello') or {
		panic(err)
	}
	rendered := template.render(.other, {}) or { panic(err) }

	assert rendered == 'Hi'
}

fn test_message_without_id_is_rejected() {
	mut bundle := new_bundle('en') or { panic(err) }

	bundle.add_messages('en', [
		Message{
			other: 'Hello'
		},
	]) or {
		assert err.msg().contains('message id cannot be empty')
		return
	}

	assert false
}

fn test_load_message_file_reads_and_registers_toml_messages() {
	mut bundle := new_bundle('en') or { panic(err) }
	temp_dir := os.join_path(os.temp_dir(), 'v_i18n_bundle_${rand.ulid()}')
	os.mkdir(temp_dir) or { panic(err) }
	defer {
		os.rmdir_all(temp_dir) or {}
	}
	path := os.join_path(temp_dir, 'active.en.toml')
	os.write_file(path, 'hello = "Hello from file"') or { panic(err) }

	message_file := bundle.load_message_file(path) or { panic(err) }
	template := bundle.template_for(parse_language_tag('en') or { panic(err) }, 'hello') or {
		panic(err)
	}
	rendered := template.render(.other, {}) or { panic(err) }

	assert message_file.path == path
	assert message_file.tag.str() == 'en'
	assert message_file.format == 'toml'
	assert message_file.messages.len == 1
	assert rendered == 'Hello from file'
}

fn test_parse_message_file_bytes_on_bundle_registers_messages_and_returns_file() {
	mut bundle := new_bundle('en') or { panic(err) }

	message_file := bundle.parse_message_file_bytes('hello = "Hello from bytes"'.bytes(),
		'active.en.toml') or { panic(err) }
	template := bundle.template_for(parse_language_tag('en') or { panic(err) }, 'hello') or {
		panic(err)
	}
	rendered := template.render(.other, {}) or { panic(err) }

	assert message_file.path == 'active.en.toml'
	assert message_file.tag.str() == 'en'
	assert message_file.format == 'toml'
	assert message_file.messages.len == 1
	assert rendered == 'Hello from bytes'
}

fn test_localizer_localizes_direct_message() {
	mut bundle := new_bundle('en') or { panic(err) }
	bundle.add_messages('en', [
		Message{
			id:    'hello'
			other: 'Hello'
		},
	]) or { panic(err) }
	localizer := new_localizer(bundle, ['en']) or { panic(err) }

	rendered := localizer.localize(LocalizeConfig{
		message_id: 'hello'
	}) or { panic(err) }

	assert rendered == 'Hello'
}

fn test_localizer_falls_back_from_regional_language_to_parent() {
	mut bundle := new_bundle('en') or { panic(err) }
	bundle.add_messages('es', [
		Message{
			id:    'hello'
			other: 'Hola'
		},
	]) or { panic(err) }
	localizer := new_localizer(bundle, ['es-MX']) or { panic(err) }

	rendered := localizer.localize(LocalizeConfig{
		message_id: 'hello'
	}) or { panic(err) }

	assert rendered == 'Hola'
}

fn test_localizer_falls_back_from_base_language_to_registered_regional_language() {
	mut bundle := new_bundle('en') or { panic(err) }
	bundle.add_messages('es-ES', [
		Message{
			id:    'hello'
			other: 'Hola de Espana'
		},
	]) or { panic(err) }
	localizer := new_localizer(bundle, ['es']) or { panic(err) }

	rendered := localizer.localize(LocalizeConfig{
		message_id: 'hello'
	}) or { panic(err) }

	assert rendered == 'Hola de Espana'
}

fn test_localizer_falls_back_to_default_bundle_language() {
	mut bundle := new_bundle('en') or { panic(err) }
	bundle.add_messages('en', [
		Message{
			id:    'hello'
			other: 'Hello'
		},
	]) or { panic(err) }
	bundle.add_messages('es', [
		Message{
			id:    'other'
			other: 'Otro'
		},
	]) or { panic(err) }
	localizer := new_localizer(bundle, ['es']) or { panic(err) }

	rendered := localizer.localize(LocalizeConfig{
		message_id: 'hello'
	}) or { panic(err) }

	assert rendered == 'Hello'
}

fn test_localizer_checks_lower_priority_requested_language_before_default() {
	mut bundle := new_bundle('en') or { panic(err) }
	bundle.add_messages('fr', [
		Message{
			id:    'other'
			other: 'Autre'
		},
	]) or { panic(err) }
	bundle.add_messages('es', [
		Message{
			id:    'hello'
			other: 'Hola'
		},
	]) or { panic(err) }
	localizer := new_localizer(bundle, ['fr, es;q=0.9']) or { panic(err) }

	rendered := localizer.localize(LocalizeConfig{
		message_id: 'hello'
	}) or { panic(err) }

	assert rendered == 'Hola'
}

fn test_localizer_falls_back_to_default_message() {
	mut bundle := new_bundle('en') or { panic(err) }
	localizer := new_localizer(bundle, ['en']) or { panic(err) }

	rendered := localizer.localize(LocalizeConfig{
		default_message: Message{
			id:    'hello'
			other: 'Hello from default'
		}
	}) or { panic(err) }

	assert rendered == 'Hello from default'
}

fn test_localizer_default_message_plural_uses_bundle_default_language() {
	mut bundle := new_bundle('en') or { panic(err) }
	bundle.add_messages('tr', [
		Message{
			id:    'unrelated'
			other: 'Ilgisiz'
		},
	]) or { panic(err) }
	localizer := new_localizer(bundle, ['tr']) or { panic(err) }

	rendered := localizer.localize(LocalizeConfig{
		message_id:      'item'
		plural_count:    plural_count_int(1)
		default_message: Message{
			id:    'item'
			one:   'one item'
			other: '{{.PluralCount}} items'
		}
	}) or { panic(err) }

	assert rendered == 'one item'
}

fn test_localizer_rejects_message_id_mismatch_with_default_message() {
	mut bundle := new_bundle('en') or { panic(err) }
	localizer := new_localizer(bundle, ['en']) or { panic(err) }

	localizer.localize(LocalizeConfig{
		message_id:      'hello'
		default_message: Message{
			id:    'goodbye'
			other: 'Goodbye'
		}
	}) or {
		assert err.msg().contains('message id mismatch')
		return
	}

	assert false
}

fn test_localizer_uses_english_plural_one_and_other() {
	mut bundle := new_bundle('en') or { panic(err) }
	bundle.add_messages('en', [
		Message{
			id:    'item'
			one:   'one item'
			other: '{{.PluralCount}} items'
		},
	]) or { panic(err) }
	localizer := new_localizer(bundle, ['en']) or { panic(err) }

	one := localizer.localize(LocalizeConfig{
		message_id:   'item'
		plural_count: plural_count_int(1)
	}) or { panic(err) }
	other := localizer.localize(LocalizeConfig{
		message_id:   'item'
		plural_count: plural_count_int(2)
	}) or { panic(err) }

	assert one == 'one item'
	assert other == '2 items'
}

fn test_localizer_falls_back_from_missing_plural_form_to_other() {
	mut bundle := new_bundle('en') or { panic(err) }
	bundle.add_messages('en', [
		Message{
			id:    'item'
			other: '{{.PluralCount}} item(s)'
		},
	]) or { panic(err) }
	localizer := new_localizer(bundle, ['en']) or { panic(err) }

	rendered := localizer.localize(LocalizeConfig{
		message_id:   'item'
		plural_count: plural_count_int(1)
	}) or { panic(err) }

	assert rendered == '1 item(s)'
}

fn test_localizer_renders_plural_count_and_named_template_data() {
	mut bundle := new_bundle('en') or { panic(err) }
	bundle.add_messages('en', [
		Message{
			id:    'cart'
			other: '{{.Name}} has {{.PluralCount}} items'
		},
	]) or { panic(err) }
	localizer := new_localizer(bundle, ['en']) or { panic(err) }

	rendered := localizer.localize(LocalizeConfig{
		message_id:    'cart'
		plural_count:  plural_count_int(3)
		template_data: {
			'Name': 'Ada'
		}
	}) or { panic(err) }

	assert rendered == 'Ada has 3 items'
}

fn test_localizer_returns_missing_template_data_error() {
	mut bundle := new_bundle('en') or { panic(err) }
	bundle.add_messages('en', [
		Message{
			id:    'hello'
			other: 'Hello {{.Name}}'
		},
	]) or { panic(err) }
	localizer := new_localizer(bundle, ['en']) or { panic(err) }

	localizer.localize(LocalizeConfig{
		message_id: 'hello'
	}) or {
		assert err.msg().contains('missing template data key')
		assert err.msg().contains('Name')
		return
	}

	assert false
}

fn test_localizer_localizes_toml_loaded_pluralized_message_end_to_end() {
	mut bundle := new_bundle('en') or { panic(err) }
	toml_text := '[item]\n' +
		'translation = { one = "one item", other = "{{.PluralCount}} items" }\n'
	bundle.parse_message_file_bytes(toml_text.bytes(), 'active.en.toml') or { panic(err) }
	localizer := new_localizer(bundle, ['en']) or { panic(err) }

	rendered := localizer.localize(LocalizeConfig{
		message_id:   'item'
		plural_count: plural_count_int(5)
	}) or { panic(err) }

	assert rendered == '5 items'
}
