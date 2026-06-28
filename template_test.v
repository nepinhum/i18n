module i18n

fn test_plain_text_renders_unchanged() {
	rendered := render_template('Hello world', '', '', map[string]string{}) or { panic(err) }

	assert rendered == 'Hello world'
}

fn test_default_delimiters_replace_named_value() {
	rendered := render_template('Hello {{.Name}}', '', '', {
		'Name': 'Ada'
	}) or { panic(err) }

	assert rendered == 'Hello Ada'
}

fn test_custom_delimiters_replace_named_value() {
	rendered := render_template('Hello <<.Name>>', '<<', '>>', {
		'Name': 'Ada'
	}) or { panic(err) }

	assert rendered == 'Hello Ada'
}

fn test_missing_closing_delimiter_returns_error() {
	render_template('Hello {{.Name', '', '', {
		'Name': 'Ada'
	}) or { return }

	assert false
}

fn test_unsupported_action_returns_error() {
	render_template('{{if .Name}}', '', '', {
		'Name': 'Ada'
	}) or { return }

	assert false
}

fn test_missing_data_key_returns_error() {
	render_template('Hello {{.Name}}', '', '', map[string]string{}) or { return }

	assert false
}
