module i18n

fn test_message_with_other_creates_template() {
	template := new_message_template(Message{
		id:    'items'
		other: '{{.Count}} items'
	}) or { panic(err) }

	rendered := template.render(.other, {
		'Count': '3'
	}) or { panic(err) }

	assert rendered == '3 items'
}

fn test_message_with_no_plural_text_returns_error() {
	new_message_template(Message{
		id: 'empty'
	}) or { return }

	assert false
}

fn test_selected_one_text_is_used_when_present() {
	template := new_message_template(Message{
		id:    'items'
		one:   '{{.Count}} item'
		other: '{{.Count}} items'
	}) or { panic(err) }

	rendered := template.render(.one, {
		'Count': '1'
	}) or { panic(err) }

	assert rendered == '1 item'
}

fn test_selected_one_falls_back_to_other() {
	template := new_message_template(Message{
		id:    'items'
		other: '{{.Count}} items'
	}) or { panic(err) }

	rendered := template.render(.one, {
		'Count': '1'
	}) or { panic(err) }

	assert rendered == '1 items'
}

fn test_missing_selected_form_and_missing_other_returns_error() {
	template := new_message_template(Message{
		id:  'items'
		one: '{{.Count}} item'
	}) or { panic(err) }

	template.text_for_form(.few) or { return }

	assert false
}

fn test_reserved_message_keys_are_detected() {
	reserved_keys := [
		'id',
		'description',
		'hash',
		'zero',
		'one',
		'two',
		'few',
		'many',
		'other',
		'translation',
		'leftDelim',
		'rightDelim',
		'left_delim',
		'right_delim',
	]

	for key in reserved_keys {
		assert is_reserved_message_key(key)
	}

	assert !is_reserved_message_key('title')
}

fn test_normalize_message_key_converts_go_style_delimiters() {
	assert normalize_message_key('leftDelim') == 'left_delim'
	assert normalize_message_key('rightDelim') == 'right_delim'
	assert normalize_message_key('description') == 'description'
}
